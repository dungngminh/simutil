// Decode benchmark for the macOS VideoToolbox path (H264Stream.swift), no
// Flutter needed. Feeds one Annex-B file (with AUDs) to N decoders from a
// single "platform" queue, like the app's binary message handler.
//
//   ffmpeg -f lavfi -i testsrc2=size=1080x2400:rate=60 -t 5 -c:v libx264 \
//     -preset veryfast -bf 0 -g 600 -b:v 8M -x264-params aud=1 \
//     -bsf:v h264_mp4toannexb -f h264 /tmp/out.h264
//   swiftc -O -o /tmp/h264bench \
//     macos/simutil_h264/Sources/simutil_h264/H264Stream.swift \
//     benchmark/decode/main.swift
//   /tmp/h264bench /tmp/out.h264 4 60
//
// paced: every stream at <fps> for twice the file's length: delivered fps,
//   submit→decoded latency, CPU and time spent inside decode() (main thread).
// flood: every stream as fast as possible: throughput, and how stale the last
//   frame is when the burst ends (backlog latency).

import Foundation
import QuartzCore

let args = CommandLine.arguments
guard args.count >= 2, let file = FileManager.default.contents(atPath: args[1]) else {
  print("usage: h264bench <file.h264> [streams=4] [fps=60]")
  exit(1)
}
let streamCount = args.count > 2 ? Int(args[2])! : 4
let fps = args.count > 3 ? Double(args[3])! : 60

/// Access units: the bytes after each AUD, like scrcpy packets.
func accessUnits(_ data: Data) -> [Data] {
  let bytes = [UInt8](data)
  var auds: [Int] = []  // offsets of `00 00 01 09`
  var i = 0
  while i + 4 < bytes.count {
    if bytes[i] == 0, bytes[i + 1] == 0, bytes[i + 2] == 1, bytes[i + 3] & 0x1f == 9 {
      auds.append(i)
      i += 4
    } else {
      i += 1
    }
  }
  return auds.indices.map { k in
    var end = bytes.count
    if k + 1 < auds.count {
      end = auds[k + 1]
      if bytes[end - 1] == 0 { end -= 1 }
    }
    return Data(bytes[(auds[k] + 5)..<end])
  }
}

let units = accessUnits(file)
print("\(units.count) access units, \(file.count / 1024) KB, \(streamCount) streams")

func cpuSeconds() -> Double {
  var usage = rusage()
  getrusage(RUSAGE_SELF, &usage)
  return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
    + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
}

final class Probe {
  let lock = NSLock()
  var submitted: [Double] = []
  /// (submit time, latency) per decoded frame.
  var samples: [(Double, Double)] = []
  var latencies: [Double] { samples.map(\.1) }
  var decoded = 0
  var last = 0.0

  func submit() {
    lock.lock()
    submitted.append(CACurrentMediaTime())
    lock.unlock()
  }

  func output() {
    let now = CACurrentMediaTime()
    lock.lock()
    decoded += 1
    last = now
    if !submitted.isEmpty {
      let at = submitted.removeFirst()
      samples.append((at, now - at))
    }
    lock.unlock()
  }
}

func percentile(_ values: [Double], _ p: Double) -> Double {
  guard !values.isEmpty else { return 0 }
  let sorted = values.sorted()
  return sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))]
}

let platform = DispatchQueue(label: "platform", qos: .userInteractive)

func paced() {
  let streams = (0..<streamCount).map { _ in H264Stream() }
  let probes = streams.map { _ in Probe() }
  for (s, p) in zip(streams, probes) { s.onFrame = { p.output() } }
  var inDecode = 0.0
  var next = Array(repeating: 0, count: streamCount)
  var resetting = Array(repeating: 0, count: streamCount)
  var resetAt = Array(repeating: -1, count: streamCount)
  var lastReset = Array(repeating: -1_000_000, count: streamCount)
  var requests = 0
  let ticks = units.count * 2
  let done = DispatchSemaphore(value: 0)
  let timer = DispatchSource.makeTimerSource(flags: .strict, queue: platform)
  var tick = 0
  let cpu0 = cpuSeconds()
  let t0 = CACurrentMediaTime()
  timer.schedule(deadline: .now(), repeating: 1 / fps, leeway: .microseconds(100))
  timer.setEventHandler {
    if tick == ticks {
      timer.cancel()
      done.signal()
      return
    }
    tick += 1
    for k in 0..<streamCount {
      // A key frame request (at most one a second, like ScrcpySession)
      // restarts the encoder: ~100 ms without frames, then the stream
      // resumes from its key frame.
      if tick == resetAt[k] {
        resetAt[k] = -1
        lastReset[k] = tick
        resetting[k] = Int(fps / 10)
        next[k] = 0
      }
      if resetting[k] > 0 {
        resetting[k] -= 1
        continue
      }
      let start = CACurrentMediaTime()
      let before = streams[k].accepted
      let needKey = streams[k].decode(units[next[k]])
      inDecode += CACurrentMediaTime() - start
      if streams[k].accepted != before { probes[k].submit() }
      next[k] = (next[k] + 1) % units.count
      if needKey {
        requests += 1
        resetAt[k] = max(tick + 1, lastReset[k] + Int(fps))
      }
    }
  }
  timer.resume()
  done.wait()
  Thread.sleep(forTimeInterval: 0.5)
  let wall = CACurrentMediaTime() - t0 - 0.5
  let cpu = cpuSeconds() - cpu0
  let lat = probes.flatMap(\.latencies)
  let tail = probes.flatMap(\.samples).filter { $0.0 > t0 + wall - 2 }.map(\.1)
  let decoded = probes.map(\.decoded).reduce(0, +)
  print(String(
    format: "paced %d×%.0ffps: %.1f fps/stream decoded, latency avg %.1f ms p95 %.1f ms max %.1f ms (last 2 s avg %.1f ms), CPU %.0f%%, decode() %.1f µs/call, %d key frame requests",
    streamCount, fps, Double(decoded) / Double(streamCount) / wall,
    lat.reduce(0, +) / Double(max(lat.count, 1)) * 1e3, percentile(lat, 0.95) * 1e3,
    (lat.max() ?? 0) * 1e3, tail.reduce(0, +) / Double(max(tail.count, 1)) * 1e3,
    cpu / wall * 100, inDecode / Double(ticks * streamCount) * 1e6, requests))
  streams.forEach { $0.stop() }
}

func flood() {
  let streams = (0..<streamCount).map { _ in H264Stream() }
  let probes = streams.map { _ in Probe() }
  for (s, p) in zip(streams, probes) { s.onFrame = { p.output() } }
  let rounds = 2
  let t0 = CACurrentMediaTime()
  var lastSubmit = 0.0
  platform.sync {
    var next = Array(repeating: 0, count: streamCount)
    for _ in 0..<(units.count * rounds) {
      for k in 0..<streamCount {
        let before = streams[k].accepted
        if streams[k].decode(units[next[k]]) { next[k] = 0 } else { next[k] += 1 }
        if streams[k].accepted != before { probes[k].submit() }
        next[k] %= units.count
      }
    }
    lastSubmit = CACurrentMediaTime()
  }
  // Wait until every decoder went quiet.
  var previous = -1
  while true {
    Thread.sleep(forTimeInterval: 0.3)
    let decoded = probes.map(\.decoded).reduce(0, +)
    if decoded == previous { break }
    previous = decoded
  }
  let end = probes.map(\.last).max() ?? lastSubmit
  print(String(
    format: "flood %d streams: %d/%d frames decoded, %.0f fps total, latency p50 %.0f ms max %.0f ms, last frame %.0f ms after the burst",
    streamCount, previous, units.count * rounds * streamCount, Double(previous) / (end - t0),
    percentile(probes.flatMap(\.latencies), 0.5) * 1e3,
    (probes.flatMap(\.latencies).max() ?? 0) * 1e3, (end - lastSubmit) * 1e3))
  streams.forEach { $0.stop() }
}

paced()
flood()
