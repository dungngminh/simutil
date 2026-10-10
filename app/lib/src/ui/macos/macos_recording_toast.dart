import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../di.dart';
import '../../recording/saved_recordings.dart';

/// Shows a toast in the bottom-right corner whenever a recording is saved;
/// clicking it opens the video.
class MacosRecordingToastHost extends StatefulWidget {
  const MacosRecordingToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<MacosRecordingToastHost> createState() =>
      _MacosRecordingToastHostState();
}

class _MacosRecordingToastHostState extends State<MacosRecordingToastHost> {
  late final StreamSubscription<String> _saved;
  String? _path;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _saved = getIt<SavedRecordings>().saved.listen((path) {
      _hide?.cancel();
      setState(() => _path = path);
      _hide = Timer(const Duration(seconds: 8), _dismiss);
    });
  }

  void _dismiss() {
    if (mounted) setState(() => _path = null);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _saved.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 20,
          bottom: 20,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: path == null
                ? const SizedBox.shrink()
                : _RecordingToast(
                    key: ValueKey(path),
                    path: path,
                    onClose: _dismiss,
                  ),
          ),
        ),
      ],
    );
  }
}

class _RecordingToast extends StatelessWidget {
  const _RecordingToast({super.key, required this.path, required this.onClose});

  final String path;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final recordings = getIt<SavedRecordings>();
    return GestureDetector(
      onTap: () => recordings.open(path),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: theme.canvasColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                offset: Offset(0, 8),
                color: Color(0x33000000),
              ),
            ],
          ),
          child: Row(
            children: [
              const MacosIcon(
                CupertinoIcons.film,
                color: MacosColors.systemRedColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Recording saved', style: theme.typography.headline),
                    Text(
                      path.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        PushButton(
                          controlSize: ControlSize.small,
                          onPressed: () => recordings.open(path),
                          child: const Text('Open'),
                        ),
                        const SizedBox(width: 8),
                        PushButton(
                          controlSize: ControlSize.small,
                          secondary: true,
                          onPressed: () => recordings.reveal(path),
                          child: const Text('Show in Finder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              MacosIconButton(
                icon: const MacosIcon(CupertinoIcons.xmark, size: 13),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
