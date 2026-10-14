import AVFoundation
import CoreMediaIO
import CoreImage
import FlutterMacOS

// Streams the screen of a USB-connected iPhone / iPad: the same CoreMediaIO
// screen-capture device QuickTime records from. View only; real devices take
// no input without an XCUITest runner.

/// Shows iOS devices on USB as `.muxed` capture devices. Needs to be set once
/// per process; devices appear a moment later.
private let allowScreenCaptureDevices: Void = {
  var prop = CMIOObjectPropertyAddress(
    mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
    mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
    mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
  var allow: UInt32 = 1
  CMIOObjectSetPropertyData(
    CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil,
    UInt32(MemoryLayout<UInt32>.size), &allow)
}()

private var externalDeviceType: AVCaptureDevice.DeviceType {
  if #available(macOS 14.0, *) { return .external }
  return .externalUnknown
}

/// One device's capture session, served as a Flutter texture.
private final class DeviceCapture: NSObject, FlutterTexture,
  AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate
{
  private let session = AVCaptureSession()
  /// Video and the device's audio, written straight from the capture.
  private let movie = AVCaptureMovieFileOutput()
  private var recordingDone: CheckedContinuation<Void, Never>?
  private let queue = DispatchQueue(label: "simutil.device-capture", qos: .userInteractive)
  private let lock = NSLock()
  /// Under `lock`: the newest frame, whether Flutter has pulled it, and how
  /// many frames it pulled.
  private var latest: CVPixelBuffer?
  private var fresh = false
  private var shown = 0

  var onFrame: (() -> Void)?
  var onSize: ((Int, Int) -> Void)?
  /// Called on the main thread when the device is unplugged or the capture
  /// dies.
  var onEnded: (() -> Void)?
  private var observers: [NSObjectProtocol] = []
  private var connected: NSKeyValueObservation?

  var framesShown: Int {
    lock.lock()
    defer { lock.unlock() }
    return shown
  }

  init(device: AVCaptureDevice) throws {
    super.init()
    session.addInput(try AVCaptureDeviceInput(device: device))
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(self, queue: queue)
    guard session.canAddOutput(output) else {
      throw SimStreamError("Could not capture \(device.localizedName)")
    }
    session.addOutput(output)
    if session.canAddOutput(movie) { session.addOutput(movie) }
    let center = NotificationCenter.default
    let id = device.uniqueID
    observers = [
      // The posted object may not be ours, so match by id.
      center.addObserver(
        forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main
      ) { [weak self] n in
        if (n.object as? AVCaptureDevice)?.uniqueID == id { self?.onEnded?() }
      },
      center.addObserver(
        forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main
      ) { [weak self] _ in self?.onEnded?() },
    ]
    connected = device.observe(\.isConnected) { [weak self] device, _ in
      guard !device.isConnected else { return }
      DispatchQueue.main.async { self?.onEnded?() }
    }
  }

  var isRecording: Bool { movie.isRecording }

  func startRecording(path: String) throws {
    guard session.outputs.contains(movie), !movie.isRecording else {
      throw SimStreamError("Recording is unavailable for this device")
    }
    movie.startRecording(to: URL(fileURLWithPath: path), recordingDelegate: self)
  }

  /// Stops and waits until the file is finished.
  func stopRecording() async {
    guard movie.isRecording else { return }
    await withCheckedContinuation { done in
      recordingDone = done
      movie.stopRecording()
    }
  }

  func fileOutput(
    _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
    from connections: [AVCaptureConnection], error: Error?
  ) {
    DispatchQueue.main.async {
      self.recordingDone?.resume()
      self.recordingDone = nil
    }
  }

  /// The latest frame as PNG.
  func png() -> Data? {
    lock.lock()
    let frame = latest
    lock.unlock()
    guard let frame else { return nil }
    return CIContext().pngRepresentation(
      of: CIImage(cvPixelBuffer: frame), format: .RGBA8,
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
  }

  func start() { queue.async { self.session.startRunning() } }

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    // Capture buffers are not recycled while retained, so no copy is needed.
    guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let size = (CVPixelBufferGetWidth(frame), CVPixelBufferGetHeight(frame))
    lock.lock()
    let sizeChanged =
      latest.map { (CVPixelBufferGetWidth($0), CVPixelBufferGetHeight($0)) != size } ?? true
    latest = frame
    fresh = true
    lock.unlock()
    if sizeChanged { onSize?(size.0, size.1) }
    onFrame?()
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
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    connected = nil
    onEnded = nil
    queue.sync {
      session.stopRunning()
      onFrame = nil
      onSize = nil
    }
  }
}

/// `simutil/ios_device_stream` channel: start(udid, name) → {textureId},
/// stop(udid), frames(udid) → frames shown, png(udid) → latest frame,
/// record(udid, path) / stop_recording(udid). The size arrives with the first
/// frame (and on rotation) as a `size` call; an unplugged device or a dead
/// capture sends `ended`.
final class DeviceStreamPlugin: NSObject, FlutterPlugin {
  private let textures: FlutterTextureRegistry
  private let channel: FlutterMethodChannel
  private var sessions: [String: (capture: DeviceCapture, textureId: Int64)] = [:]
  /// Bumped by every stop, so a start still waiting (camera access, device
  /// discovery) when its stream is closed gives up instead of capturing.
  private var generations: [String: Int] = [:]

  init(textures: FlutterTextureRegistry, channel: FlutterMethodChannel) {
    self.textures = textures
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "simutil/ios_device_stream", binaryMessenger: registrar.messenger)
    let plugin = DeviceStreamPlugin(textures: registrar.textures, channel: channel)
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let udid = args["udid"] as? String else {
      return result(FlutterError(code: "args", message: "udid required", details: nil))
    }
    switch call.method {
    case "start":
      let name = args["name"] as? String ?? ""
      Task { @MainActor in
        do { result(try await self.start(udid: udid, name: name)) } catch {
          result(FlutterError(code: "start", message: error.localizedDescription, details: nil))
        }
      }
    case "stop":
      stop(udid: udid)
      result(nil)
    case "frames":
      result(sessions[udid]?.capture.framesShown ?? 0)
    case "png":
      guard let capture = sessions[udid]?.capture else {
        return result(FlutterError(
          code: "png", message: "Stream the device to take a screenshot", details: nil))
      }
      guard let png = capture.png() else {
        return result(FlutterError(code: "png", message: "No frame from the device yet", details: nil))
      }
      result(FlutterStandardTypedData(bytes: png))
    case "record":
      do {
        guard let capture = sessions[udid]?.capture else {
          throw SimStreamError("\(udid) is not streaming")
        }
        try capture.startRecording(path: args["path"] as? String ?? "")
        result(nil)
      } catch {
        result(FlutterError(code: "record", message: error.localizedDescription, details: nil))
      }
    case "stop_recording":
      guard let capture = sessions[udid]?.capture else { return result(nil) }
      Task { @MainActor in
        await capture.stopRecording()
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @MainActor
  private func start(udid: String, name: String) async throws -> [String: Any] {
    stop(udid: udid)
    let generation = generations[udid, default: 0]
    guard await AVCaptureDevice.requestAccess(for: .video) else {
      throw SimStreamError(
        "SimUtil needs Camera access to show device screens: allow it in System Settings › Privacy & Security › Camera")
    }
    let device = try await findDevice(name: name)
    guard generations[udid, default: 0] == generation else {
      throw SimStreamError("The stream was closed")
    }
    let capture = try DeviceCapture(device: device)
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
    capture.onEnded = { [weak self] in
      self?.channel.invokeMethod("ended", arguments: ["udid": udid])
    }
    capture.start()
    sessions[udid] = (capture, textureId)
    return ["textureId": textureId]
  }

  /// The capture device for [name]. Its uniqueID is not the device's UDID,
  /// so it is matched by name. Never falls back to the only capture device:
  /// that one may be another iPhone, while [name] is on Wi-Fi only.
  // ponytail: two devices with the same name pick the first; map through
  // MobileDevice (AMDevice) if that shows up.
  @MainActor
  private func findDevice(name: String) async throws -> AVCaptureDevice {
    _ = allowScreenCaptureDevices
    let deadline = Date().addingTimeInterval(5)
    while true {
      let devices = AVCaptureDevice.DiscoverySession(
        deviceTypes: [externalDeviceType], mediaType: .muxed, position: .unspecified
      ).devices
      if let match = devices.first(where: { $0.localizedName == name }) { return match }
      if Date() > deadline {
        throw SimStreamError(
          "\(name) is not connected by USB cable (or is locked). Streaming over Wi-Fi is not supported yet: connect it with a cable and unlock it.")
      }
      try await Task.sleep(nanoseconds: 250_000_000)
    }
  }

  private func stop(udid: String) {
    generations[udid, default: 0] += 1
    guard let session = sessions.removeValue(forKey: udid) else { return }
    session.capture.stop()
    textures.unregisterTexture(session.textureId)
  }
}
