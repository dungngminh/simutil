// Black-box benchmark of the running SimUtil desktop app, driven through its
// MCP server. Start the app (release build) and boot the devices first, then:
//
//   cd app && dart run benchmark/bench.dart <case> [options]
//
// Cases:
//   idle                         CPU / memory with nothing to do
//   stream   --devices a,b       open streams (timed), then FPS / CPU /
//            [--animate]         memory
//   record   [--quality high]    grid recording (or --device X: one device):
//            [--devices a,b]     achieved fps vs target, stop latency
//            [--animate]
//   mcp      [--tool list_devices] [--device X] [--calls 200]
//            [--concurrency 1]   tool latency p50/p95/p99
//   scenario --devices a,b       run_scenario --runs times: start/end skew,
//            [--runs 20]         makespan / nominal, overhead, success
//            [--record high] [--no-slim]
//
// Common: --seconds 30 (sampling window), --pid <app pid> (default: the
// SimUtil process), --port 8765, --out benchmark/results. --animate keeps
// swiping on the devices so screens change: a static screen shows (and
// records) almost no frames.
//
// CPU / memory come from `ps` once a second (macOS and Linux only), split
// into the app, its helpers (adb, scrcpy, ffmpeg…) and the Android
// emulators it booted. On macOS the display is kept awake while running. FPS comes from
// list_devices and is 0 for a tile that is not on screen.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main(List<String> argv) async {
  final args = _Args(argv);
  // A sleeping display stops the app drawing frames, which would read as
  // low FPS: keep it on for as long as this process runs.
  if (Platform.isMacOS) {
    // Detached: an attached child's stdio would keep this process alive
    // while caffeinate waits for it to exit.
    await Process.start('caffeinate', [
      '-d',
      '-w',
      '$pid',
    ], mode: ProcessStartMode.detached);
  }
  final mcp = _Mcp(
    Uri.parse('http://127.0.0.1:${args.get('port', '8765')}/mcp'),
  );
  final sampler = _Sampler(await _appPid(args.opt('pid')), mcp);
  final seconds = int.parse(args.get('seconds', '30'));
  final devices = args.list('devices');

  final Map<String, Object?> result;
  switch (args.command) {
    case 'idle':
      result = await sampler.over(seconds);
    case 'stream':
      result = await _stream(mcp, sampler, args, devices, seconds);
    case 'record':
      result = await _record(mcp, sampler, args, devices, seconds);
    case 'mcp':
      result = await _mcpLatency(mcp, sampler, args);
    case 'scenario':
      result = await _scenario(mcp, sampler, args, devices);
    default:
      stderr.writeln('Usage: bench.dart idle|stream|record|mcp|scenario …');
      exit(64);
  }
  mcp.close();

  final report = {
    'case': args.command,
    'args': argv,
    'commit': (await Process.run('git', [
      'rev-parse',
      '--short',
      'HEAD',
    ])).stdout.toString().trim(),
    'host': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'cpus': Platform.numberOfProcessors,
    'at': DateTime.now().toIso8601String(),
    ...result,
  };
  final json = const JsonEncoder.withIndent('  ').convert(report);
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final file =
      File(
          '${args.get('out', 'benchmark/results')}/${args.command}-$stamp.json',
        )
        ..createSync(recursive: true)
        ..writeAsStringSync(json);
  print(json);
  print('Saved ${file.path}');
}

/// B: opens [devices] at once (each timed until live), then samples.
Future<Map<String, Object?>> _stream(
  _Mcp mcp,
  _Sampler sampler,
  _Args args,
  List<String> devices,
  int seconds,
) async {
  final open = await _open(mcp, devices);
  final samples = await _animated(
    mcp,
    args.flag('animate') ? devices : const [],
    () => sampler.over(seconds),
  );
  return {'open_ms': open, ...samples};
}

/// Runs [body] while swiping back and forth on [devices] (none: just
/// [body]).
Future<T> _animated<T>(
  _Mcp mcp,
  List<String> devices,
  Future<T> Function() body,
) async {
  var animating = devices.isNotEmpty;
  final swipes = () async {
    while (animating) {
      await mcp.call('run_scenario', {
        'devices': devices,
        'slim': false,
        'steps': _swipes,
      });
    }
  }();
  try {
    return await body();
  } finally {
    animating = false;
    await swipes;
  }
}

/// C: one grid (or `--device`) recording over the window.
Future<Map<String, Object?>> _record(
  _Mcp mcp,
  _Sampler sampler,
  _Args args,
  List<String> devices,
  int seconds,
) async {
  final open = await _open(mcp, devices);
  final device = args.opt('device');
  final quality = args.get('quality', 'high');
  Future<Object?> toggle() => device == null
      ? mcp.call('record_grid', {'quality': quality})
      : mcp.call('record_device', {'device': device});
  await toggle();
  final samples = await _animated(mcp, [
    if (args.flag('animate')) ...{...devices, ?device},
  ], () => sampler.over(seconds));
  final watch = Stopwatch()..start();
  final saved = '${await toggle()}';
  final stopMs = watch.elapsedMilliseconds;
  final path = saved.replaceFirst('Saved ', '');
  return {
    'open_ms': open,
    'target_fps': device == null ? _targetFps[quality] : null,
    'stop_ms': stopMs,
    'file': path,
    'file_mb': File(path).existsSync()
        ? _round(File(path).lengthSync() / 1e6)
        : null,
    ...await _probe(path, seconds),
    ...samples,
  };
}

/// D: [--calls] calls of one tool, [--concurrency] at a time.
Future<Map<String, Object?>> _mcpLatency(
  _Mcp mcp,
  _Sampler sampler,
  _Args args,
) async {
  final tool = args.get('tool', 'list_devices');
  final device = args.opt('device');
  final calls = int.parse(args.get('calls', '200'));
  final concurrency = int.parse(args.get('concurrency', '1'));
  final latencies = <double>[];
  var errors = 0;
  var next = 0;
  sampler.start();
  final watch = Stopwatch()..start();
  await Future.wait([
    for (var w = 0; w < concurrency; w++)
      () async {
        while (next < calls) {
          next++;
          final t = Stopwatch()..start();
          try {
            await mcp.call(tool, {'device': ?device});
            latencies.add(t.elapsedMicroseconds / 1000);
          } catch (_) {
            errors++;
          }
        }
      }(),
  ]);
  final total = watch.elapsedMilliseconds;
  return {
    'tool': tool,
    'calls': calls,
    'concurrency': concurrency,
    'errors': errors,
    'calls_per_s': _round(calls / total * 1000),
    'latency_ms': _stats(latencies),
    ...await sampler.stop(),
  };
}

/// E: the fixed script on [devices], `--runs` times.
Future<Map<String, Object?>> _scenario(
  _Mcp mcp,
  _Sampler sampler,
  _Args args,
  List<String> devices,
) async {
  final runs = int.parse(args.get('runs', '20'));
  final record = args.opt('record');
  final nominal = _nominalMs(_script);
  if (record != null) await mcp.call('record_grid', {'quality': record});
  sampler.start();
  final prep = <int>[];
  final startSkew = <double>[];
  final endSkew = <double>[];
  final ratio = <double>[];
  final overhead = <double>[];
  var ok = 0;
  var total = 0;
  final errors = <String>{};
  for (var i = 0; i < runs; i++) {
    final r =
        await mcp.call('run_scenario', {
              'devices': ?(devices.isEmpty ? null : devices),
              'slim': !args.flag('no-slim'),
              'steps': _script,
            })
            as Map<String, Object?>;
    prep.add(r['prep_ms']! as int);
    final rows = (r['devices']! as List).cast<Map<String, Object?>>();
    total += rows.length;
    final done = rows.where((d) => d['ok'] == true).toList();
    for (final d in rows) {
      if (d['error'] case final String e) errors.add('${d['device']}: $e');
    }
    ok += done.length;
    if (done.isEmpty) continue;
    final starts = [for (final d in done) d['start_ms']! as int];
    final ends = [for (final d in done) d['end_ms']! as int];
    startSkew.add((starts.reduce(max) - starts.reduce(min)).toDouble());
    endSkew.add((ends.reduce(max) - ends.reduce(min)).toDouble());
    ratio.add(ends.reduce(max) / nominal);
    for (final d in done) {
      overhead.add(
        ((d['end_ms']! as int) - (d['start_ms']! as int) - nominal).toDouble(),
      );
    }
  }
  final samples = await sampler.stop();
  final saved = record == null ? null : await mcp.call('record_grid');
  return {
    'runs': runs,
    'steps': _script.length,
    'nominal_ms': nominal,
    'success': '$ok/$total',
    'errors': errors.toList(),
    'first_prep_ms': prep.firstOrNull,
    'prep_ms': _stats([for (final p in prep.skip(1)) p.toDouble()]),
    'start_skew_ms': _stats(startSkew),
    'end_skew_ms': _stats(endSkew),
    'makespan_ratio': _stats(ratio),
    'overhead_ms': _stats(overhead),
    'recording': ?saved,
    ...samples,
  };
}

/// Streams [devices] in parallel; ms until each is live.
Future<Map<String, int>> _open(_Mcp mcp, List<String> devices) async {
  final times = <String, int>{};
  await Future.wait([
    for (final d in devices)
      () async {
        final watch = Stopwatch()..start();
        await mcp.call('stream_device', {'device': d});
        times[d] = watch.elapsedMilliseconds;
      }(),
  ]);
  return times;
}

/// Frames, duration and fps of a recording, via ffprobe when installed.
Future<Map<String, Object?>> _probe(String path, int wallSeconds) async {
  try {
    final r = await Process.run('ffprobe', [
      '-v', 'error', '-count_frames', '-select_streams', 'v:0', //
      '-show_entries', 'stream=nb_read_frames:format=duration',
      '-of', 'json', path,
    ]);
    final json = jsonDecode(r.stdout as String) as Map<String, Object?>;
    final frames = int.parse(
      ((json['streams']! as List).first as Map)['nb_read_frames'] as String,
    );
    final duration = double.parse(
      (json['format']! as Map)['duration'] as String,
    );
    return {
      'frames': frames,
      'video_s': _round(duration),
      'wall_s': wallSeconds,
      'achieved_fps': _round(frames / duration),
    };
  } catch (e) {
    return {'probe_error': '$e'};
  }
}

/// 20 steps: 5 × (swipe up, wait, tap, wait).
final _script = [
  for (var i = 0; i < 5; i++) ...[
    {
      'action': 'swipe',
      'x1': 0.5,
      'y1': 0.7,
      'x2': 0.5,
      'y2': 0.3,
      'duration_ms': 300,
    },
    {'action': 'wait', 'ms': 200},
    {'action': 'tap', 'x': 0.5, 'y': 0.5},
    {'action': 'wait', 'ms': 200},
  ],
];

/// Back-and-forth swipes that keep the screen changing.
const _swipes = [
  {
    'action': 'swipe',
    'x1': 0.8,
    'y1': 0.5,
    'x2': 0.2,
    'y2': 0.5,
    'duration_ms': 400,
  },
  {
    'action': 'swipe',
    'x1': 0.2,
    'y1': 0.5,
    'x2': 0.8,
    'y2': 0.5,
    'duration_ms': 400,
  },
];

const _targetFps = {'low': 15, 'standard': 24, 'high': 30, 'smooth': 60};

/// Shortest possible run of [steps]: taps hold 60 ms, presses are instant.
int _nominalMs(List<Map<String, Object>> steps) => steps.fold(
  0,
  (sum, s) =>
      sum +
      switch (s['action']) {
        'tap' => 60,
        'swipe' => s['duration_ms'] as int? ?? 300,
        'wait' => s['ms']! as int,
        _ => 0,
      },
);

/// The SimUtil app's pid from --pid or by process name.
Future<int?> _appPid(String? given) async {
  if (given != null) return int.parse(given);
  for (final name in ['SimUtil', 'simutil_app']) {
    try {
      final r = await Process.run('pgrep', ['-x', name]);
      final pid = int.tryParse('${r.stdout}'.trim().split('\n').first);
      if (pid != null) return pid;
    } catch (_) {
      break; // no pgrep (Windows)
    }
  }
  stderr.writeln('SimUtil process not found: CPU / memory not sampled');
  return null;
}

/// Samples CPU / memory of the app tree and per-device FPS once a second.
/// The tree is split into the app itself, its helpers (adb, scrcpy,
/// ffmpeg…) and the Android emulators it booted, which are its children too
/// but are not the app's cost. iOS simulators belong to launchd: not counted.
class _Sampler {
  _Sampler(this.pid, this.mcp);

  final int? pid;
  final _Mcp mcp;
  final _cpu = <String, List<double>>{};
  final _rssMb = <String, List<double>>{};
  final _fps = <String, List<double>>{};
  var _samples = 0;
  Timer? _timer;

  static final _emulator = RegExp('qemu-system|netsimd|/emulator/');

  Future<Map<String, Object?>> over(int seconds) async {
    start();
    await Future<void>.delayed(Duration(seconds: seconds));
    return stop();
  }

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
  }

  Future<Map<String, Object?>> stop() async {
    _timer?.cancel();
    return {
      'samples': _samples,
      'cpu_pct': {for (final e in _cpu.entries) e.key: _stats(e.value)},
      'rss_mb': {for (final e in _rssMb.entries) e.key: _stats(e.value)},
      'fps': {for (final e in _fps.entries) e.key: _stats(e.value)},
    };
  }

  Future<void> _sample() async {
    _samples++;
    final pid = this.pid;
    if (pid != null) {
      try {
        final r = await Process.run('ps', [
          '-A',
          '-o',
          'pid=,ppid=,%cpu=,rss=,comm=',
        ]);
        final rows = {
          for (final line in '${r.stdout}'.split('\n'))
            if (RegExp(
                  r'^\s*(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(.*)$',
                ).firstMatch(line)
                case final m?)
              int.parse(m[1]!): (
                ppid: int.parse(m[2]!),
                cpu: double.parse(m[3]!),
                kb: int.parse(m[4]!),
                command: m[5]!,
              ),
        };
        final tree = {pid};
        for (var grew = true; grew;) {
          grew = false;
          for (final MapEntry(:key, :value) in rows.entries) {
            if (tree.contains(value.ppid) && tree.add(key)) grew = true;
          }
        }
        final cpu = {'app': 0.0, 'helpers': 0.0, 'emulators': 0.0};
        final kb = {'app': 0, 'helpers': 0, 'emulators': 0};
        for (final p in tree) {
          final row = rows[p];
          if (row == null) continue;
          final group = p == pid
              ? 'app'
              : _emulator.hasMatch(row.command)
              ? 'emulators'
              : 'helpers';
          cpu[group] = cpu[group]! + row.cpu;
          kb[group] = kb[group]! + row.kb;
        }
        for (final group in cpu.keys) {
          (_cpu[group] ??= []).add(cpu[group]!);
          (_rssMb[group] ??= []).add(kb[group]! / 1024);
        }
      } catch (_) {}
    }
    try {
      final list = await mcp.call('list_devices') as List;
      for (final d in list.cast<Map<String, Object?>>()) {
        if (d['fps'] case final num fps) {
          (_fps[d['name']! as String] ??= []).add(fps.toDouble());
        }
      }
    } catch (_) {}
  }
}

/// Minimal JSON-RPC client for the app's MCP endpoint.
class _Mcp {
  _Mcp(this.url);

  final Uri url;
  final _http = HttpClient();
  var _id = 0;

  /// The tool's text result, decoded as JSON when it is JSON.
  Future<Object?> call(
    String tool, [
    Map<String, Object?> args = const {},
  ]) async {
    final request = await _http.postUrl(url);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': ++_id,
        'method': 'tools/call',
        'params': {'name': tool, 'arguments': args},
      }),
    );
    final body =
        jsonDecode(await utf8.decodeStream(await request.close())) as Map;
    if (body['error'] case final error?) throw StateError('$tool: $error');
    final result = body['result'] as Map;
    final text = ((result['content'] as List).first as Map)['text'];
    if (result['isError'] == true) throw StateError('$tool: $text');
    if (text is! String) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  void close() => _http.close(force: true);
}

/// `case --key value --flag` arguments.
class _Args {
  _Args(List<String> argv) {
    for (var i = 0; i < argv.length; i++) {
      final a = argv[i];
      if (!a.startsWith('--')) {
        command ??= a;
      } else if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
        _values[a.substring(2)] = argv[++i];
      } else {
        _values[a.substring(2)] = '';
      }
    }
  }

  String? command;
  final _values = <String, String>{};

  String? opt(String key) => _values[key];
  String get(String key, String fallback) => _values[key] ?? fallback;
  bool flag(String key) => _values.containsKey(key);
  List<String> list(String key) =>
      _values[key]?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
}

/// p50 / p95 / p99 / max / mean of [values]; null when empty.
Map<String, double>? _stats(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  double at(double q) => sorted[((sorted.length - 1) * q).round()];
  return {
    'p50': _round(at(.5)),
    'p95': _round(at(.95)),
    'p99': _round(at(.99)),
    'max': _round(sorted.last),
    'mean': _round(sorted.reduce((a, b) => a + b) / sorted.length),
  };
}

double _round(num v) => (v * 10).round() / 10;
