// Grid recording on macOS: ScreenCaptureKit captures a region of the app's
// own window and AVAssetWriter encodes it with VideoToolbox, so frames never
// pass through Dart or the Flutter raster thread.
//
// Completion handlers only, no async/await: a Swift concurrency hop here made
// the system's screen-recording menu bar indicator (MenuBarClientCore) crash
// the app in its main-executor check on macOS 27.

import AVFoundation
import Cocoa
import FlutterMacOS
import ScreenCaptureKit

private struct WindowRecorderError: LocalizedError {
  let errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

@available(macOS 12.3, *)
private final class WindowRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
  private let stream: SCStream
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let queue = DispatchQueue(label: "simutil.window_recorder")
  private var started = false
  private var failure: Error?

  /// [rect] is in points from the top-left of [window], title bar included.
  private init(
    window: SCWindow, rect: CGRect, scale: CGFloat, fps: Int, bitRate: Int, path: String
  ) throws {
    // H.264 level 5.2 tops out at 4096×2304 worth of pixels.
    let maxScale = (4096.0 * 2304.0 / (rect.width * rect.height)).squareRoot()
    let s = min(scale, maxScale)
    let width = Int(rect.width * s) & ~1
    let height = Int(rect.height * s) & ~1

    let config = SCStreamConfiguration()
    config.sourceRect = rect
    config.width = width
    config.height = height
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
    config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    // Default is the display's space (Display P3 on Retina Macs); the file
    // is tagged BT.709, so P3 values played as sRGB look washed out.
    config.colorSpaceName = CGColorSpace.sRGB
    config.colorMatrix = CGDisplayStream.yCbCrMatrix_ITU_R_709_2
    config.showsCursor = false
    config.queueDepth = 6

    let url = URL(fileURLWithPath: path)
    try? FileManager.default.removeItem(at: url)
    writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: bitRate,
          AVVideoExpectedSourceFrameRateKey: fps,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
      ])
    input.expectsMediaDataInRealTime = true
    writer.add(input)
    guard writer.startWriting() else {
      throw writer.error ?? WindowRecorderError("Could not write \(path)")
    }
    stream = SCStream(
      filter: SCContentFilter(desktopIndependentWindow: window),
      configuration: config, delegate: nil)
    super.init()
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
  }

  /// Starts recording window [id]; [done] runs on the main queue.
  static func start(
    window id: CGWindowID, rect: CGRect, scale: CGFloat, fps: Int, bitRate: Int, path: String,
    done: @escaping (Result<WindowRecorder, Error>) -> Void
  ) {
    let finish = { result in DispatchQueue.main.async { done(result) } }
    SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) {
      content, error in
      guard let window = content?.windows.first(where: { $0.windowID == id }) else {
        // Denied permission lands here too; macOS shows its own prompt.
        return finish(
          .failure(
            error.map {
              WindowRecorderError(
                "\($0.localizedDescription) Allow SimUtil under System Settings › Privacy & Security › Screen Recording.")
            } ?? WindowRecorderError("SimUtil window not found on screen")))
      }
      let recorder: WindowRecorder
      do {
        recorder = try WindowRecorder(
          window: window, rect: rect, scale: scale, fps: fps, bitRate: bitRate, path: path)
      } catch {
        return finish(.failure(error))
      }
      recorder.stream.startCapture { error in
        if let error {
          recorder.writer.cancelWriting()
          finish(.failure(error))
        } else {
          finish(.success(recorder))
        }
      }
    }
  }

  func stream(
    _ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType
  ) {
    guard type == .screen, buffer.isValid,
      let info = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
        as? [[SCStreamFrameInfo: Any]],
      let status = info.first?[.status] as? Int,
      SCFrameStatus(rawValue: status) == .complete
    else { return }
    if !started {
      writer.startSession(atSourceTime: buffer.presentationTimeStamp)
      started = true
    }
    if input.isReadyForMoreMediaData { input.append(buffer) }
  }

  /// Finishes the file; [done] runs on the main queue with the error, if any.
  func stop(done: @escaping (Error?) -> Void) {
    let finish = { (error: Error?) in DispatchQueue.main.async { done(error) } }
    stream.stopCapture { [self] stopError in
      queue.async { [self] in
        guard started else {
          writer.cancelWriting()
          return finish(stopError ?? WindowRecorderError("No frames were captured"))
        }
        // ScreenCaptureKit only sends frames when the window changes; end at
        // "now" (same host clock as the frames) so a still tail keeps its length.
        input.markAsFinished()
        writer.endSession(atSourceTime: CMClockGetTime(CMClockGetHostTimeClock()))
        writer.finishWriting { [self] in
          finish(
            writer.status == .failed
              ? writer.error ?? WindowRecorderError("Could not finish the recording") : nil)
        }
      }
    }
  }
}

/// `simutil/grid_recorder` channel: start({path, x, y, width, height, scale,
/// fps, bitRate}) records that region of the window (logical pixels);
/// stop() finishes the file.
final class WindowRecorderPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private var recorder: AnyObject?
  private var starting = false

  private init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "simutil/grid_recorder", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(WindowRecorderPlugin(registrar: registrar), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(macOS 12.3, *) else {
      return result(
        FlutterError(code: "unsupported", message: "Needs macOS 12.3 or later", details: nil))
    }
    let fail = { (error: Error) in
      result(FlutterError(code: call.method, message: error.localizedDescription, details: nil))
    }
    switch call.method {
    case "start":
      do {
        try start(call.arguments as? [String: Any] ?? [:]) { error in
          if let error { fail(error) } else { result(nil) }
        }
      } catch {
        fail(error)
      }
    case "stop":
      guard let recorder = recorder as? WindowRecorder else { return result(nil) }
      self.recorder = nil
      recorder.stop { error in
        if let error { fail(error) } else { result(nil) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(macOS 12.3, *)
  private func start(_ args: [String: Any], done: @escaping (Error?) -> Void) throws {
    guard recorder == nil, !starting else { throw WindowRecorderError("Already recording") }
    guard let window = registrar.view?.window else {
      throw WindowRecorderError("No window to record")
    }
    func number(_ key: String) -> Double { (args[key] as? NSNumber)?.doubleValue ?? 0 }
    // Flutter's logical pixels are content-view points; sourceRect counts
    // from the window's top edge, title bar included.
    let topInset = window.frame.height - (window.contentView?.frame.maxY ?? window.frame.height)
    starting = true
    WindowRecorder.start(
      window: CGWindowID(window.windowNumber),
      rect: CGRect(
        x: number("x"), y: number("y") + topInset,
        width: number("width"), height: number("height")),
      scale: number("scale"),
      fps: Int(number("fps")),
      bitRate: Int(number("bitRate")),
      path: args["path"] as? String ?? ""
    ) { [self] result in
      starting = false
      switch result {
      case .success(let recorder):
        self.recorder = recorder
        done(nil)
      case .failure(let error):
        done(error)
      }
    }
  }
}
