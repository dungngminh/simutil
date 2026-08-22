import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// Builds an overlay dialog widget with a [Completer] for the result.
typedef OverlayDialogBuilder<T> =
    Component Function(
      BuildContext context,
      Completer<T?> completer,
      OverlayEntry? entry,
    );

/// Inserts a modal overlay and returns when [builder] completes the future.
Future<T?> showOverlayDialog<T>({
  required BuildContext context,
  required OverlayDialogBuilder<T> builder,
}) {
  final completer = Completer<T?>();
  OverlayEntry? entry;

  entry = OverlayEntry(
    opaque: false,
    builder: (context) {
      return builder(context, completer, entry);
    },
  );

  Overlay.of(context).insert(entry);

  return completer.future;
}
