import 'dart:async';

import 'package:nocterm/nocterm.dart';

typedef OverlayDialogBuilder<T> =
    Component Function(
      BuildContext context,
      Completer<T?> completer,
      OverlayEntry? entry,
    );

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
