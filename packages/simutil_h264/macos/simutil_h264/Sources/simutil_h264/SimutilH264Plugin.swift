// Flutter glue for H264Stream: textures plus the `simutil/h264` channels.

import FlutterMacOS

extension H264Stream: FlutterTexture {}
extension SharedFrames: FlutterTexture {}

/// Shared-frame textures by id; main thread only.
private var sharedFrames: [Int64: SharedFrames] = [:]

/// Decoders by texture id. Global so `decodeFunction` reaches them from any
/// thread; every access holds `registryLock`, which also serializes
/// `H264Stream.decode` per stream as it requires.
private let registryLock = NSLock()
private var registry: [Int64: H264Stream] = [:]

private func decode(_ id: Int64, _ data: Data) -> Bool {
  registryLock.lock()
  defer { registryLock.unlock() }
  return registry[id]?.decode(data) ?? false
}

/// `int32_t (int64_t id, const uint8_t* bytes, int64_t count)`: queues one
/// access unit from any thread. The Android stream's worker isolate calls it
/// through `dart:ffi`, so frames skip the main thread; 1 = frames were
/// dropped, send a key frame. Handed out by address (`decodeFunction`), so
/// the statically linked plugin needs no exported symbol.
private let decodeFunction: @convention(c) (Int64, UnsafePointer<UInt8>?, Int64) -> Int32 = {
  id, bytes, count in
  guard let bytes, count > 0 else { return 0 }
  return decode(id, Data(bytes: bytes, count: Int(count))) ? 1 : 0
}

/// `simutil/h264` methods: create → textureId, frames({id}) → frames shown,
/// dispose({id}), decodeFunction → address of `decodeFunction`. Access units arrive on the binary channel
/// `simutil/h264/decode` as `int64 LE id` + Annex-B bytes; the reply is
/// `[1]` when frames were dropped and the sender should send a key frame.
///
/// Shared RGB888 frames: sharedCreate({capacity}) → {id, path},
/// sharedResize({id, capacity}) → path, and frames / dispose as above. A new
/// frame is announced on `simutil/h264/present` as `int64 LE id`, `int32 LE
/// width`, `int32 LE height`.
public final class SimutilH264Plugin: NSObject, FlutterPlugin {
  private let textures: FlutterTextureRegistry

  private init(textures: FlutterTextureRegistry) {
    self.textures = textures
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = SimutilH264Plugin(textures: registrar.textures)
    let channel = FlutterMethodChannel(name: "simutil/h264", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.messenger.setMessageHandlerOnChannel("simutil/h264/decode") { message, reply in
      reply(decodeMessage(message) ? Data([1]) : nil)
    }
    registrar.messenger.setMessageHandlerOnChannel("simutil/h264/present") { message, reply in
      if let message, message.count >= 16 {
        message.withUnsafeBytes {
          let id = Int64(littleEndian: $0.loadUnaligned(as: Int64.self))
          let width = Int32(littleEndian: $0.loadUnaligned(fromByteOffset: 8, as: Int32.self))
          let height = Int32(littleEndian: $0.loadUnaligned(fromByteOffset: 12, as: Int32.self))
          sharedFrames[id]?.present(width: Int(width), height: Int(height))
        }
      }
      reply(nil)
    }
  }

  private static func decodeMessage(_ message: Data?) -> Bool {
    guard let message, message.count > 8 else { return false }
    let id = message.withUnsafeBytes { Int64(littleEndian: $0.loadUnaligned(as: Int64.self)) }
    return decode(id, message.dropFirst(8))
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let id = (args["id"] as? NSNumber)?.int64Value ?? -1
    switch call.method {
    case "create":
      let decoder = H264Stream()
      let textureId = textures.register(decoder)
      decoder.onFrame = coalesced { [weak self] in self?.textures.textureFrameAvailable(textureId) }
      registryLock.lock()
      registry[textureId] = decoder
      registryLock.unlock()
      result(textureId)
    case "sharedCreate":
      let frames = SharedFrames()
      guard let path = frames.resize((args["capacity"] as? NSNumber)?.intValue ?? 0) else {
        return result(FlutterError(code: "io", message: "Cannot create a frame file", details: nil))
      }
      let textureId = textures.register(frames)
      frames.onFrame = coalesced { [weak self] in self?.textures.textureFrameAvailable(textureId) }
      sharedFrames[textureId] = frames
      result(["id": textureId, "path": path])
    case "sharedResize":
      let capacity = (args["capacity"] as? NSNumber)?.intValue ?? 0
      if let path = sharedFrames[id]?.resize(capacity) {
        result(path)
      } else {
        result(FlutterError(code: "io", message: "Cannot create a frame file", details: nil))
      }
    case "frames":
      if let frames = sharedFrames[id] { return result(frames.framesShown) }
      registryLock.lock()
      let decoder = registry[id]
      registryLock.unlock()
      result(decoder?.framesShown ?? 0)
    case "decodeFunction":
      result(Int64(Int(bitPattern: unsafeBitCast(decodeFunction, to: UnsafeRawPointer.self))))
    case "dispose":
      if let frames = sharedFrames.removeValue(forKey: id) {
        frames.stop()
        textures.unregisterTexture(id)
        return result(nil)
      }
      registryLock.lock()
      let removed = registry.removeValue(forKey: id)
      registryLock.unlock()
      if let decoder = removed {
        decoder.stop()
        textures.unregisterTexture(id)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Runs `body` on the main thread once per batch of calls from other
/// threads, not once per call (one hop per batch of frames).
private func coalesced(_ body: @escaping () -> Void) -> () -> Void {
  let pending = NSLock()
  var scheduled = false
  return {
    pending.lock()
    defer { pending.unlock() }
    if scheduled { return }
    scheduled = true
    DispatchQueue.main.async {
      pending.lock()
      scheduled = false
      pending.unlock()
      body()
    }
  }
}
