// Live iOS Simulator screens as Flutter textures, plus touch/button input.
//
// Adapted from serve-sim (https://github.com/EvanBacon/serve-sim),
// Copyright Evan Bacon, Apache License 2.0: FrameCapture.swift,
// HIDInjector.swift, SimFrameworks.swift, PixelBufferUtils.swift and
// FramebufferSurfaceSelector.swift, trimmed to capture + touch + buttons.

import Cocoa
import CoreVideo
import FlutterMacOS
import IOSurface

// MARK: - Private frameworks

private enum SimFrameworks {
  static let developerDir: String = {
    let fallback = "/Applications/Xcode.app/Contents/Developer"
    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    process.arguments = ["-p"]
    process.standardOutput = pipe
    guard (try? process.run()) != nil else { return fallback }
    process.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return (out?.isEmpty ?? true) ? fallback : out!
  }()

  static let load: Void = {
    let dev = developerDir
    for path in [
      "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator",
      "\(dev)/Library/PrivateFrameworks/CoreSimulator.framework/CoreSimulator",
      "\(dev)/../SharedFrameworks/SimulatorKit.framework/SimulatorKit",  // Xcode 27+
      "\(dev)/Library/PrivateFrameworks/SimulatorKit.framework/SimulatorKit",  // Xcode 26-
    ] {
      _ = dlopen(path, RTLD_NOW)
    }
  }()

  static func device(udid: String) -> NSObject? {
    _ = load
    guard let contextClass = NSClassFromString("SimServiceContext") as? NSObject.Type,
      let context = contextClass.perform(
        NSSelectorFromString("sharedServiceContextForDeveloperDir:error:"),
        with: developerDir, with: nil)?.takeUnretainedValue() as? NSObject,
      let deviceSet = context.perform(
        NSSelectorFromString("defaultDeviceSetWithError:"), with: nil)?
        .takeUnretainedValue() as? NSObject,
      let devices = deviceSet.value(forKey: "devices") as? [NSObject]
    else { return nil }
    return devices.first { ($0.value(forKey: "UDID") as? NSUUID)?.uuidString == udid }
  }

  /// Native screen size in pixels from the private `SimDeviceType.mainScreenSize`.
  static func mainScreenSize(_ device: NSObject) -> CGSize? {
    let typeSel = NSSelectorFromString("deviceType")
    let sizeSel = NSSelectorFromString("mainScreenSize")
    guard device.responds(to: typeSel),
      let type = device.perform(typeSel)?.takeUnretainedValue() as? NSObject,
      type.responds(to: sizeSel)
    else { return nil }
    typealias GetSize = @convention(c) (AnyObject, Selector) -> CGSize
    let size = unsafeBitCast(type.method(for: sizeSel), to: GetSize.self)(type, sizeSel)
    return size.width > 0 && size.height > 0 ? size : nil
  }
}

@objc private protocol FramebufferDescriptor {
  @objc(registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:)
  func registerScreenCallbacks(
    uuid: UUID,
    callbackQueue: DispatchQueue,
    frameCallback: @convention(block) @escaping () -> Void,
    surfacesChangedCallback: @convention(block) @escaping () -> Void,
    propertiesChangedCallback: @convention(block) @escaping () -> Void
  )
}

// MARK: - Capture

/// Captures one simulator's framebuffer into a Flutter texture.
private final class SimCapture: NSObject, FlutterTexture {
  private let queue = DispatchQueue(label: "simutil.sim-capture", qos: .userInteractive)
  private let lock = NSLock()
  private var latest: CVPixelBuffer?
  private var pool: CVPixelBufferPool?
  private var poolSize = (0, 0)
  private var descriptors: [(NSObject, UUID)] = []
  private var lastSeed: UInt32?
  private var expectedSize: CGSize?
  private var io: NSObject?
  private var rewireTimer: DispatchSourceTimer?
  private var frames = 0
  /// Under `lock`: a captured frame Flutter has not pulled yet, and how many
  /// frames it pulled.
  private var fresh = false
  private var shown = 0

  var framesShown: Int {
    lock.lock()
    defer { lock.unlock() }
    return shown
  }

  var onFrame: (() -> Void)?
  var onSize: ((Int, Int) -> Void)?

  func start(device: NSObject) throws {
    expectedSize = SimFrameworks.mainScreenSize(device)
    guard let io = device.perform(NSSelectorFromString("io"))?.takeUnretainedValue() as? NSObject
    else { throw SimStreamError("Simulator IO is unavailable") }
    self.io = io
    try queue.sync { try wire() }
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + 1, repeating: 1)
    timer.setEventHandler { [weak self] in
      guard let self, self.frames == 0 else { return }
      try? self.wire()
    }
    timer.resume()
    rewireTimer = timer
  }

  private func wire() throws {
    guard let io else { return }
    io.perform(NSSelectorFromString("updateIOPorts"))
    unregister()
    guard let ports = io.value(forKey: "deviceIOPorts") as? [NSObject] else {
      throw SimStreamError("Simulator has no IO ports")
    }
    let surfSel = NSSelectorFromString("framebufferSurface")
    for port in ports {
      guard let id = port.perform(NSSelectorFromString("portIdentifier"))?.takeUnretainedValue(),
        "\(id)" == "com.apple.framebuffer.display",
        let desc = port.perform(NSSelectorFromString("descriptor"))?.takeUnretainedValue()
          as? NSObject,
        desc.responds(to: surfSel),
        desc.responds(to: #selector(FramebufferDescriptor.registerScreenCallbacks))
      else { continue }
      let uuid = UUID()
      unsafeBitCast(desc, to: FramebufferDescriptor.self).registerScreenCallbacks(
        uuid: uuid, callbackQueue: queue,
        frameCallback: { [weak self] in self?.capture() },
        surfacesChangedCallback: { [weak self] in self?.capture() },
        propertiesChangedCallback: {})
      descriptors.append((desc, uuid))
    }
    if descriptors.isEmpty {
      throw SimStreamError("No simulator display found (is the Simulator window connected?)")
    }
    capture()
  }

  private func unregister() {
    let sel = NSSelectorFromString("unregisterScreenCallbacksWithUUID:")
    for (desc, uuid) in descriptors where desc.responds(to: sel) {
      desc.perform(sel, with: uuid)
    }
    descriptors.removeAll()
  }

  /// The device's own display; Xcode 27 Device Hub may also publish a large
  /// presentation surface, so match the native size before falling back to
  /// the largest live surface.
  private func currentSurface() -> IOSurface? {
    let surfSel = NSSelectorFromString("framebufferSurface")
    let surfaces: [IOSurface] = descriptors.compactMap { desc, _ in
      guard let obj = desc.perform(surfSel)?.takeUnretainedValue() else { return nil }
      return unsafeBitCast(obj, to: IOSurface.self)
    }.filter { IOSurfaceGetWidth($0) > 0 && IOSurfaceGetHeight($0) > 0 }
    if let expected = expectedSize {
      let w = Int(expected.width.rounded()), h = Int(expected.height.rounded())
      if let match = surfaces.first(where: {
        let sw = IOSurfaceGetWidth($0), sh = IOSurfaceGetHeight($0)
        return (sw == w && sh == h) || (sw == h && sh == w)
      }) {
        return match
      }
    }
    return surfaces.max { IOSurfaceGetWidth($0) * IOSurfaceGetHeight($0) < IOSurfaceGetWidth($1) * IOSurfaceGetHeight($1) }
  }

  private func capture() {
    guard let surface = currentSurface() else { return }
    let seed = IOSurfaceGetSeed(surface)
    if seed == lastSeed { return }
    lastSeed = seed

    var wrapped: Unmanaged<CVPixelBuffer>?
    guard CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, surface, nil, &wrapped)
      == kCVReturnSuccess, let source = wrapped?.takeRetainedValue(),
      let copy = copyBuffer(source)
    else { return }

    let size = (CVPixelBufferGetWidth(copy), CVPixelBufferGetHeight(copy))
    lock.lock()
    let sizeChanged = latest.map { (CVPixelBufferGetWidth($0), CVPixelBufferGetHeight($0)) != size } ?? true
    latest = copy
    fresh = true
    lock.unlock()
    frames += 1
    if sizeChanged { onSize?(size.0, size.1) }
    onFrame?()
  }

  /// The source surface is recycled by the simulator, so deep-copy it into
  /// a pooled BGRA buffer Flutter can hold on to.
  private func copyBuffer(_ source: CVPixelBuffer) -> CVPixelBuffer? {
    let w = CVPixelBufferGetWidth(source), h = CVPixelBufferGetHeight(source)
    if pool == nil || poolSize != (w, h) {
      let attrs: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: w,
        kCVPixelBufferHeightKey as String: h,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        kCVPixelBufferMetalCompatibilityKey as String: true,
      ]
      CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool)
      poolSize = (w, h)
    }
    var out: CVPixelBuffer?
    guard let pool, CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &out)
      == kCVReturnSuccess, let dst = out
    else { return nil }
    CVPixelBufferLockBaseAddress(source, .readOnly)
    CVPixelBufferLockBaseAddress(dst, [])
    defer {
      CVPixelBufferUnlockBaseAddress(dst, [])
      CVPixelBufferUnlockBaseAddress(source, .readOnly)
    }
    guard let src = CVPixelBufferGetBaseAddress(source),
      let dstAddr = CVPixelBufferGetBaseAddress(dst)
    else { return nil }
    let srcStride = CVPixelBufferGetBytesPerRow(source)
    let dstStride = CVPixelBufferGetBytesPerRow(dst)
    if srcStride == dstStride {
      memcpy(dstAddr, src, srcStride * h)
    } else {
      let rowBytes = min(srcStride, dstStride)
      for row in 0..<h {
        memcpy(dstAddr + row * dstStride, src + row * srcStride, rowBytes)
      }
    }
    return dst
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }
    guard let latest else { return nil }
    if fresh {
      fresh = false
      shown += 1
    }
    return Unmanaged.passRetained(latest)
  }

  func stop() {
    rewireTimer?.cancel()
    rewireTimer = nil
    queue.sync {
      unregister()
      onFrame = nil
      onSize = nil
      io = nil
    }
  }
}

// MARK: - Input

/// Touch and hardware buttons through SimulatorKit's legacy HID client.
private final class SimHID {
  private typealias MouseFunc = @convention(c) (
    UnsafePointer<CGPoint>, UnsafePointer<CGPoint>?, UInt32, Int32, CGFloat, CGFloat, UInt32
  ) -> UnsafeMutableRawPointer?
  private typealias ButtonFunc = @convention(c) (Int32, Int32, Int32) -> UnsafeMutableRawPointer?
  private typealias SendFunc = @convention(c) (
    AnyObject, Selector, UnsafeMutableRawPointer, ObjCBool, AnyObject?, AnyObject?
  ) -> Void

  private let queue = DispatchQueue(label: "simutil.sim-hid", qos: .userInteractive)
  private let client: NSObject
  private let mouse: MouseFunc
  private let button: ButtonFunc?
  private let udid: String

  init(device: NSObject, udid: String) throws {
    let any = UnsafeMutableRawPointer(bitPattern: -2)  // RTLD_DEFAULT
    guard let mousePtr = dlsym(any, "IndigoHIDMessageForMouseNSEvent") else {
      throw SimStreamError("Simulator touch input is unavailable")
    }
    mouse = unsafeBitCast(mousePtr, to: MouseFunc.self)
    button = dlsym(any, "IndigoHIDMessageForButton").map { unsafeBitCast($0, to: ButtonFunc.self) }

    guard let cls = NSClassFromString("_TtC12SimulatorKit24SimDeviceLegacyHIDClient"),
      let initIMP = class_getMethodImplementation(cls, NSSelectorFromString("initWithDevice:error:"))
    else { throw SimStreamError("Simulator HID client is unavailable") }
    typealias InitFunc = @convention(c) (
      AnyObject, Selector, AnyObject, AutoreleasingUnsafeMutablePointer<NSError?>
    ) -> AnyObject?
    var error: NSError?
    let obj = unsafeBitCast(initIMP, to: InitFunc.self)(
      cls.alloc(), NSSelectorFromString("initWithDevice:error:"), device, &error)
    if let error { throw error }
    guard let client = obj as? NSObject else { throw SimStreamError("HID client init failed") }
    self.client = client
    self.udid = udid
  }

  private func send(_ msg: UnsafeMutableRawPointer) {
    let sel = NSSelectorFromString("sendWithMessage:freeWhenDone:completionQueue:completion:")
    guard let imp = class_getMethodImplementation(object_getClass(client)!, sel) else {
      free(msg)
      return
    }
    unsafeBitCast(imp, to: SendFunc.self)(client, sel, msg, ObjCBool(true), nil, nil)
  }

  /// [x]/[y] normalized 0..1. Down and move are both event type 1; up is 2.
  func touch(phase: String, x: Double, y: Double) {
    queue.async { [self] in
      var point = CGPoint(x: x, y: y)
      let type: Int32 = phase == "up" ? 2 : 1
      if let msg = mouse(&point, nil, 0x32, type, 1, 1, 0) { send(msg) }
    }
  }

  func press(_ name: String) {
    queue.async { [self] in
      switch name {
      case "home":
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["simctl", "launch", udid, "com.apple.springboard"]
        try? p.run()
      case "lock":
        pressButton(source: 0x1)
      case "recents":
        pressButton(source: 0x0)
        Thread.sleep(forTimeInterval: 0.15)
        pressButton(source: 0x0)
      default:
        break
      }
    }
  }

  private func pressButton(source: Int32) {
    guard let button else { return }
    for direction: Int32 in [1, 2] {
      if let msg = button(source, direction, 0x33) { send(msg) }
    }
  }
}

// MARK: - Device chrome

/// Apple's own Simulator device frame for a simulator, read from Xcode's
/// DeviceKit chrome bundles at runtime (nothing is bundled with the app).
private enum SimChrome {
  /// Renders a PDF from [dir] into an `NSImage` sized in points.
  private static func image(_ name: String, in dir: URL) -> NSImage? {
    NSImage(contentsOf: dir.appendingPathComponent("\(name).pdf"))
  }

  private static func png(size: NSSize, scale: CGFloat, draw: () -> Void) -> Data? {
    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
      pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
      hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
      bitsPerPixel: 0)
    else { return nil }
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
  }

  /// `{composite + bodyWidth/bodyHeight | nineSlice + corner, insets, mask?,
  /// screenWidth, screenHeight}` in points, or nil without chrome.
  /// Same sources as serve-sim's `devicekit-chrome.ts`.
  static func load(device: NSObject) -> [String: Any]? {
    guard let type = device.perform(NSSelectorFromString("deviceType"))?
      .takeUnretainedValue() as? NSObject,
      let bundle = type.value(forKey: "bundlePath") as? String
    else { return nil }
    let resources = URL(fileURLWithPath: bundle).appendingPathComponent("Contents/Resources")
    guard let profile = NSDictionary(contentsOf: resources.appendingPathComponent("profile.plist")),
      let chromeId = profile["chromeIdentifier"] as? String,
      let name = chromeId.split(separator: ".").last
    else { return nil }
    let dir = URL(fileURLWithPath: "/Library/Developer/DeviceKit/Chrome/\(name).devicechrome/Contents/Resources")
    guard let data = try? Data(contentsOf: dir.appendingPathComponent("chrome.json")),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let images = json["images"] as? [String: Any],
      let sizing = images["sizing"] as? [String: Any],
      let tl = image(images["topLeft"] as? String ?? "", in: dir),
      let tr = image(images["topRight"] as? String ?? "", in: dir),
      let bl = image(images["bottomLeft"] as? String ?? "", in: dir),
      let br = image(images["bottomRight"] as? String ?? "", in: dir),
      let top = image(images["top"] as? String ?? "", in: dir),
      let bottom = image(images["bottom"] as? String ?? "", in: dir),
      let left = image(images["left"] as? String ?? "", in: dir),
      let right = image(images["right"] as? String ?? "", in: dir)
    else { return nil }

    let border = (json["paths"] as? [String: Any])?["simpleOutsideBorder"] as? [String: Any]
    var result: [String: Any] = [
      "insets": [
        "top": sizing["topHeight"] as? Double ?? 0,
        "left": sizing["leftWidth"] as? Double ?? 0,
        "bottom": sizing["bottomHeight"] as? Double ?? 0,
        "right": sizing["rightWidth"] as? Double ?? 0,
      ],
      "outerRadius": border?["cornerRadiusX"] as? Double ?? 0,
    ]
    if let compositeName = images["composite"] as? String,
      let composite = image(compositeName, in: dir),
      let compositePng = png(size: composite.size, scale: 3, draw: {
        composite.draw(in: NSRect(origin: .zero, size: composite.size))
      })
    {
      result["composite"] = FlutterStandardTypedData(bytes: compositePng)
      result["bodyWidth"] = Double(composite.size.width)
      result["bodyHeight"] = Double(composite.size.height)
    } else {
      // Corners are not always square (home-button phones: 97x111).
      let cw = tl.size.width, ch = tl.size.height
      guard let nineSlice = png(size: NSSize(width: cw * 2 + 1, height: ch * 2 + 1), scale: 3, draw: {
        tl.draw(in: NSRect(x: 0, y: ch + 1, width: cw, height: ch))
        top.draw(in: NSRect(x: cw, y: ch + 1, width: 1, height: ch))
        tr.draw(in: NSRect(x: cw + 1, y: ch + 1, width: cw, height: ch))
        left.draw(in: NSRect(x: 0, y: ch, width: cw, height: 1))
        right.draw(in: NSRect(x: cw + 1, y: ch, width: cw, height: 1))
        bl.draw(in: NSRect(x: 0, y: 0, width: cw, height: ch))
        bottom.draw(in: NSRect(x: cw, y: 0, width: 1, height: ch))
        br.draw(in: NSRect(x: cw + 1, y: 0, width: cw, height: ch))
      }) else { return nil }
      result["nineSlice"] = FlutterStandardTypedData(bytes: nineSlice)
      result["cornerWidth"] = Double(cw)
      result["cornerHeight"] = Double(ch)
    }

    let scaleSel = NSSelectorFromString("mainScreenScale")
    if let pixels = SimFrameworks.mainScreenSize(device), type.responds(to: scaleSel) {
      typealias GetScale = @convention(c) (AnyObject, Selector) -> Float
      let scale = CGFloat(unsafeBitCast(type.method(for: scaleSel), to: GetScale.self)(type, scaleSel))
      if scale > 0 {
        result["screenWidth"] = Double(pixels.width / scale)
        result["screenHeight"] = Double(pixels.height / scale)
      }
    }

    if let maskName = profile["framebufferMask"] as? String,
      let mask = image(maskName, in: resources),
      let maskPng = png(size: mask.size, scale: 1, draw: {
        mask.draw(in: NSRect(origin: .zero, size: mask.size))
      })
    {
      result["mask"] = FlutterStandardTypedData(bytes: maskPng)
    }
    return result
  }
}

// MARK: - Plugin

private struct SimStreamError: LocalizedError {
  let errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

/// `simutil/ios_stream` channel: start(udid) → {textureId, width, height},
/// stop(udid), touch(udid, phase, x, y), press(udid, button),
/// frames(udid) → frames shown.
/// Size changes (rotation) are pushed back as `size` calls.
final class SimStreamPlugin: NSObject, FlutterPlugin {
  private let textures: FlutterTextureRegistry
  private let channel: FlutterMethodChannel
  private var sessions: [String: (capture: SimCapture, hid: SimHID?, textureId: Int64)] = [:]

  init(textures: FlutterTextureRegistry, channel: FlutterMethodChannel) {
    self.textures = textures
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "simutil/ios_stream", binaryMessenger: registrar.messenger)
    let plugin = SimStreamPlugin(textures: registrar.textures, channel: channel)
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let udid = args["udid"] as? String else {
      return result(FlutterError(code: "args", message: "udid required", details: nil))
    }
    switch call.method {
    case "start":
      do { result(try start(udid: udid)) } catch {
        result(FlutterError(code: "start", message: error.localizedDescription, details: nil))
      }
    case "stop":
      stop(udid: udid)
      result(nil)
    case "touch":
      sessions[udid]?.hid?.touch(
        phase: args["phase"] as? String ?? "up",
        x: args["x"] as? Double ?? 0, y: args["y"] as? Double ?? 0)
      result(nil)
    case "chrome":
      result(SimFrameworks.device(udid: udid).flatMap(SimChrome.load))
    case "press":
      sessions[udid]?.hid?.press(args["button"] as? String ?? "")
      result(nil)
    case "frames":
      result(sessions[udid]?.capture.framesShown ?? 0)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(udid: String) throws -> [String: Any] {
    stop(udid: udid)
    guard let device = SimFrameworks.device(udid: udid) else {
      throw SimStreamError("Simulator \(udid) not found")
    }
    guard (device.value(forKey: "stateString") as? String) == "Booted" else {
      throw SimStreamError("Simulator is not booted")
    }
    let capture = SimCapture()
    let textureId = textures.register(capture)
    // One main-thread hop per batch of frames, not per frame.
    let pending = NSLock()
    var scheduled = false
    capture.onFrame = { [weak self] in
      pending.lock()
      defer { pending.unlock() }
      if scheduled { return }
      scheduled = true
      DispatchQueue.main.async {
        pending.lock()
        scheduled = false
        pending.unlock()
        self?.textures.textureFrameAvailable(textureId)
      }
    }
    capture.onSize = { [weak self] w, h in
      DispatchQueue.main.async {
        self?.channel.invokeMethod("size", arguments: ["udid": udid, "width": w, "height": h])
      }
    }
    do {
      try capture.start(device: device)
    } catch {
      textures.unregisterTexture(textureId)
      throw error
    }
    sessions[udid] = (capture, try? SimHID(device: device, udid: udid), textureId)
    let size = SimFrameworks.mainScreenSize(device) ?? .zero
    return ["textureId": textureId, "width": Int(size.width), "height": Int(size.height)]
  }

  private func stop(udid: String) {
    guard let session = sessions.removeValue(forKey: udid) else { return }
    session.capture.stop()
    textures.unregisterTexture(session.textureId)
  }
}
