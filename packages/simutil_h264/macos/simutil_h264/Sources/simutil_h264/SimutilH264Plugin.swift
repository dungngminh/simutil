// Flutter glue for H264Stream: textures plus the `simutil/h264` channels.

import FlutterMacOS

extension H264Stream: FlutterTexture {}

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
      // One main-thread hop per batch of decoded frames, not per frame.
      let pending = NSLock()
      var scheduled = false
      decoder.onFrame = { [weak self] in
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
      registryLock.lock()
      registry[textureId] = decoder
      registryLock.unlock()
      result(textureId)
    case "frames":
      registryLock.lock()
      let decoder = registry[id]
      registryLock.unlock()
      result(decoder?.framesShown ?? 0)
    case "decodeFunction":
      result(Int64(Int(bitPattern: unsafeBitCast(decodeFunction, to: UnsafeRawPointer.self))))
    case "dispose":
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
