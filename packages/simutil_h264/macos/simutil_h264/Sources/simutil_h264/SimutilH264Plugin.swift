// Flutter glue for H264Stream: textures plus the `simutil/h264` channels.

import FlutterMacOS

extension H264Stream: FlutterTexture {}

/// `simutil/h264` methods: create → textureId, frames({id}) → frames shown,
/// dispose({id}). Access units arrive on the binary channel
/// `simutil/h264/decode` as `int64 LE id` + Annex-B bytes; the reply is
/// `[1]` when frames were dropped and the sender should send a key frame.
public final class SimutilH264Plugin: NSObject, FlutterPlugin {
  private let textures: FlutterTextureRegistry
  private var decoders: [Int64: H264Stream] = [:]

  private init(textures: FlutterTextureRegistry) {
    self.textures = textures
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = SimutilH264Plugin(textures: registrar.textures)
    let channel = FlutterMethodChannel(name: "simutil/h264", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.messenger.setMessageHandlerOnChannel("simutil/h264/decode") {
      [weak plugin] message, reply in
      reply(plugin?.decode(message) == true ? Data([1]) : nil)
    }
  }

  private func decode(_ message: Data?) -> Bool {
    guard let message, message.count > 8 else { return false }
    let id = message.withUnsafeBytes { Int64(littleEndian: $0.loadUnaligned(as: Int64.self)) }
    return decoders[id]?.decode(message.dropFirst(8)) ?? false
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
      decoders[textureId] = decoder
      result(textureId)
    case "frames":
      result(decoders[id]?.framesShown ?? 0)
    case "dispose":
      if let decoder = decoders.removeValue(forKey: id) {
        decoder.stop()
        textures.unregisterTexture(id)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
