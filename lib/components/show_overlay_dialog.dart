import 'dart:async';

import 'package:nocterm/nocterm.dart';

typedef OverlayDialogBuilder<T> =
    Component Function(
      BuildContext context,
      Completer<T?> completer,
      OverlayEntry? entry,
    );

/// Shows an overlay dialog with a dimmed modal barrier backdrop.
///
/// The [FadeModalBarrier] ensures the background content is dimmed,
/// making the dialog clearly visible even on maximized terminal windows.
Future<T?> showOverlayDialog<T>({
  required BuildContext context,
  required OverlayDialogBuilder<T> builder,
}) {
  final completer = Completer<T?>();
  OverlayEntry? entry;

  entry = OverlayEntry(
    opaque: false,
    builder: (context) {
      return Stack(
        children: [
          // Dimmed backdrop to occlude underlying content
          FadeModalBarrier(
            color: Colors.black.withOpacity(0.6),
            dismissible: false,
            duration: const Duration(milliseconds: 100),
          ),
          // Actual dialog content rendered on top
          builder(context, completer, entry),
        ],
      );
    },
  );

  Overlay.of(context).insert(entry);

  return completer.future;
}
