import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/mcp/tools/tool_context.dart';
import 'package:simutil_app/src/ui/design/design.dart';
import 'package:simutil_app/src/ui/recording_toast.dart';
import 'package:simutil_core/simutil_core.dart';

/// Installs app packages dropped from the desktop onto [child]: `.apk` on
/// Android, `.app` / `.ipa` on iOS. Only a booted [device] accepts drops.
class InstallDropTarget extends StatefulWidget {
  const InstallDropTarget({
    super.key,
    required this.device,
    required this.child,
  });

  final Device device;
  final Widget child;

  @override
  State<InstallDropTarget> createState() => _InstallDropTargetState();
}

class _InstallDropTargetState extends State<InstallDropTarget> {
  var _over = false;

  List<String> get _extensions => widget.device.os == DeviceOs.android
      ? const ['.apk']
      : const ['.app', '.ipa'];

  @override
  Widget build(BuildContext context) {
    final t = SimuTokens.of(context);
    return DropTarget(
      enable: widget.device.state == DeviceState.booted,
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) {
        setState(() => _over = false);
        _install([for (final f in details.files) f.path]);
      },
      child: Stack(
        children: [
          widget.child,
          if (_over)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.12),
                    border: Border.all(color: t.accent, width: 2),
                    borderRadius: BorderRadius.circular(SimuTokens.radius),
                  ),
                  child: Text(
                    'Drop to install',
                    style: t.label.copyWith(color: t.accent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _install(List<String> paths) async {
    final device = widget.device;
    final automation = getIt<ToolContext>().automation;
    for (final raw in paths) {
      // A dropped `.app` bundle is a directory; macOS may add a slash.
      final path = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
      final name = path.split(RegExp(r'[/\\]')).last;
      if (!_extensions.any(name.toLowerCase().endsWith)) {
        _notice(
          'Cannot install $name',
          '${device.name} takes ${_extensions.join(' / ')}',
          NoticeTone.error,
        );
        continue;
      }
      final loading = mounted
          ? showNotice(
              context,
              'Installing $name…',
              subtitle: device.name,
              busy: true,
            )
          : null;
      try {
        await automation.install(device, path);
        _notice('Installed $name', device.name, NoticeTone.success);
      } on Object catch (e) {
        _notice('Install failed', _message(e), NoticeTone.error);
      } finally {
        loading?.call();
      }
    }
  }

  void _notice(String title, String subtitle, NoticeTone tone) {
    if (mounted) showNotice(context, title, subtitle: subtitle, tone: tone);
  }

  static String _message(Object e) => switch (e) {
    StateError(:final message) => message,
    _ => '$e',
  };
}
