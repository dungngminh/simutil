// Packed RGB888 frames that another process writes into a file we map (the
// Android emulator's gRPC MMAP transport), converted to BGRA for a texture.

import Accelerate
import CoreVideo
import Foundation

/// A shared frame file plus the latest converted frame.
final class SharedFrames: NSObject {
  private let queue = DispatchQueue(label: "simutil.frames", qos: .userInteractive)
  /// Guards `latest`, `fresh`, `shown` and `queued`; held only for swaps.
  private let lock = NSLock()
  private var latest: CVPixelBuffer?
  private var fresh = false
  private var shown = 0
  private var queued: (Int, Int)?
  // Queue only.
  private var file: (path: String, map: UnsafeMutableRawPointer, capacity: Int)?
  private var pool: CVPixelBufferPool?
  private var poolSize = (0, 0)

  /// Called on the frame queue after each converted frame.
  var onFrame: (() -> Void)?

  /// Frames handed to the texture so far.
  var framesShown: Int {
    lock.lock()
    defer { lock.unlock() }
    return shown
  }

  @objc func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }
    if fresh {
      fresh = false
      shown += 1
    }
    return latest.map { Unmanaged.passRetained($0) }
  }

  /// Replaces the shared file with a new owner-only one of `capacity` bytes;
  /// returns its path, or nil when it cannot be created. The writer must move
  /// to the new path: the old file is unmapped and deleted.
  func resize(_ capacity: Int) -> String? {
    queue.sync {
      unmap()
      let path = NSTemporaryDirectory() + "simutil-frames-\(UUID().uuidString)"
      let fd = open(path, O_RDWR | O_CREAT | O_EXCL, 0o600)
      guard fd >= 0 else { return nil }
      defer { close(fd) }
      guard ftruncate(fd, off_t(capacity)) == 0,
        let map = mmap(nil, capacity, PROT_READ, MAP_SHARED, fd, 0), map != MAP_FAILED
      else {
        unlink(path)
        return nil
      }
      file = (path, map, capacity)
      return path
    }
  }

  /// A new `width`x`height` frame is in the file. Frames arriving while one
  /// is converted collapse into one: the file only holds the newest anyway.
  func present(width: Int, height: Int) {
    guard width > 0, height > 0 else { return }
    lock.lock()
    let busy = queued != nil
    queued = (width, height)
    lock.unlock()
    if busy { return }
    queue.async { [self] in
      lock.lock()
      let size = queued
      queued = nil
      lock.unlock()
      if let (width, height) = size, let buffer = convert(width, height) {
        lock.lock()
        latest = buffer
        fresh = true
        lock.unlock()
        onFrame?()
      }
    }
  }

  func stop() {
    queue.sync {
      unmap()
      onFrame = nil
    }
  }

  private func unmap() {
    guard let file else { return }
    munmap(file.map, file.capacity)
    unlink(file.path)
    self.file = nil
  }

  private func convert(_ width: Int, _ height: Int) -> CVPixelBuffer? {
    guard let file, width * height * 3 <= file.capacity else { return nil }
    if pool == nil || poolSize != (width, height) {
      pool = nil
      poolSize = (width, height)
      let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        kCVPixelBufferMetalCompatibilityKey as String: true,
      ]
      CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
    }
    guard let pool else { return nil }
    var out: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
    guard let out else { return nil }
    CVPixelBufferLockBaseAddress(out, [])
    defer { CVPixelBufferUnlockBaseAddress(out, []) }
    var src = vImage_Buffer(
      data: file.map, height: vImagePixelCount(height), width: vImagePixelCount(width),
      rowBytes: width * 3)
    var dst = vImage_Buffer(
      data: CVPixelBufferGetBaseAddress(out), height: vImagePixelCount(height),
      width: vImagePixelCount(width), rowBytes: CVPixelBufferGetBytesPerRow(out))
    // ponytail: the writer may already be filling the next frame, so a fast
    // scroll can tear; double-buffering needs one file per frame upstream.
    let error = vImageConvert_RGB888toBGRA8888(
      &src, nil, 255, &dst, false, vImage_Flags(kvImageNoFlags))
    return error == kvImageNoError ? out : nil
  }
}
