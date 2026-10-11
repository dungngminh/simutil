import 'package:simutil_core/simutil_core.dart';

/// [DeviceAutomation] for Android emulators and devices through adb:
/// `monkey` launches, `input text` types and `uiautomator dump` reads the
/// accessibility tree.
abstract interface class AndroidAutomation implements DeviceAutomation {
  /// Runs adb (resolved by [adbPath] on each call) through [exec].
  factory AndroidAutomation(
    CommandExec exec, {
    required String Function() adbPath,
  }) = _AndroidAutomation;
}

class _AndroidAutomation implements AndroidAutomation {
  _AndroidAutomation(this._exec, {required this.adbPath});

  final CommandExec _exec;
  final String Function() adbPath;

  /// Portrait screen size in pixels, by device id (`wm size`).
  final _screens = <String, (int, int)>{};

  @override
  Future<void> launch(
    Device device,
    String appId, {
    bool clearState = false,
  }) async {
    // `pm clear` stops the app too.
    final reset = await _adb(device, [
      'shell',
      if (clearState) ...['pm', 'clear'] else ...['am', 'force-stop'],
      appId,
    ]);
    if (clearState && !reset.stdout.contains('Success')) {
      throw StateError(
        'Could not clear $appId on ${device.name}: '
                '${reset.stdout}${reset.stderr}'
            .trim(),
      );
    }
    final result = await _adb(device, [
      'shell',
      'monkey',
      '-p',
      appId,
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]);
    // monkey exits 0 even when the package is missing.
    final out = '${result.stdout}${result.stderr}';
    if (!result.success || out.contains('No activities found')) {
      throw StateError('Could not launch $appId on ${device.name}: $out');
    }
  }

  @override
  Future<void> typeText(Device device, String text) async {
    // ponytail: `input text` handles ASCII only; Unicode needs an IME
    // (ADBKeyboard) or a clipboard paste.
    final result = await _adb(device, [
      'shell',
      'input',
      'text',
      _shellQuote(text.replaceAll(' ', '%s')),
    ]);
    if (!result.success) {
      throw StateError('Typing failed on ${device.name}: ${result.stderr}');
    }
  }

  @override
  Future<List<UiElement>> elements(Device device) async {
    final result = await _adb(device, [
      'exec-out',
      'uiautomator',
      'dump',
      '/dev/tty',
    ]);
    if (!result.stdout.contains('<hierarchy')) {
      throw StateError(
        'uiautomator dump failed on ${device.name}: '
                '${result.stdout}${result.stderr}'
            .trim(),
      );
    }
    return parseUiautomatorDump(
      result.stdout,
      screen: await _screenSize(device),
    );
  }

  /// The display size from `wm size` (an override wins over the physical
  /// size); null when adb does not say.
  Future<(int, int)?> _screenSize(Device device) async {
    if (_screens[device.id] case final size?) return size;
    final out = (await _adb(device, ['shell', 'wm', 'size'])).stdout;
    final sizes = [
      for (final m in RegExp(r'(\d+)x(\d+)').allMatches(out))
        (int.parse(m[1]!), int.parse(m[2]!)),
    ];
    if (sizes.isEmpty) return null;
    return _screens[device.id] = sizes.last;
  }

  Future<CommandResult> _adb(Device device, List<String> args) => _exec.run(
    adbPath(),
    arguments: ['-s', device.id, ...args],
    timeout: const Duration(seconds: 20),
  );
}

/// `adb shell` joins its arguments into one shell command line.
String _shellQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

final _node = RegExp(r'<node\b([^>]*)>');
final _attr = RegExp(r'([\w-]+)="([^"]*)"');
final _bounds = RegExp(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]');

/// Elements from `uiautomator dump` XML, normalized to the [screen] size
/// in portrait pixels (swapped when the dump is rotated). Without it the
/// root node's bounds stand in, which is only right when the top window
/// fills the screen (a dialog or permission prompt does not). Nodes without
/// label, text or id are dropped.
List<UiElement> parseUiautomatorDump(String xml, {(int, int)? screen}) {
  double? width;
  double? height;
  if (screen case (final w, final h)) {
    final rotation = RegExp(r'<hierarchy[^>]*rotation="(\d)"').firstMatch(xml);
    final landscape = rotation != null && rotation[1]!.contains(RegExp('[13]'));
    width = (landscape ? h : w).toDouble();
    height = (landscape ? w : h).toDouble();
  }
  final elements = <UiElement>[];
  for (final node in _node.allMatches(xml)) {
    final attrs = {
      for (final a in _attr.allMatches(node[1]!)) a[1]!: _unescape(a[2]!),
    };
    final b = _bounds.firstMatch(attrs['bounds'] ?? '');
    if (b == null) continue;
    final [l, t, r, bt] = [for (var i = 1; i <= 4; i++) int.parse(b[i]!)];
    width ??= r.toDouble();
    height ??= bt.toDouble();
    if (width <= 0 || height <= 0 || r <= l || bt <= t) continue;
    final desc = attrs['content-desc'] ?? '';
    final text = attrs['text'] ?? '';
    final id = attrs['resource-id'] ?? '';
    if (desc.isEmpty && text.isEmpty && id.isEmpty) continue;
    elements.add(
      UiElement(
        label: desc.isNotEmpty ? desc : text,
        value: desc.isNotEmpty ? text : '',
        id: id,
        role: attrs['class'] ?? '',
        left: l / width,
        top: t / height,
        right: r / width,
        bottom: bt / height,
      ),
    );
  }
  return elements;
}

String _unescape(String s) => s
    .replaceAll('&#10;', '\n')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
