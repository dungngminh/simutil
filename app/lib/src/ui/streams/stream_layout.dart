import 'dart:math';
import 'dart:ui';

import 'package:simutil_app/src/settings/view_settings_cubit.dart';

/// Width / height of a typical phone tile with its header; picks the grid
/// shape that shows the largest screens.
const _tileAspect = 0.56;

/// The stream shown large in the spotlight: [focusId] while open, else the
/// first one.
String spotlightFocus(List<String> ids, String? focusId) =>
    ids.contains(focusId) ? focusId! : ids.first;

/// Where each stream sits in [size]: equal cells for [StreamLayout.grid]
/// (last row centered), or [focusId] large with the others in a strip on
/// the right ([StreamLayout.spotlightVertical]) or along the bottom
/// ([StreamLayout.spotlightHorizontal]).
Map<String, Rect> streamRects(
  List<String> ids,
  Size size, {
  required StreamLayout layout,
  String? focusId,
  double gap = 16,
}) {
  if (ids.isEmpty) return const {};
  if (layout == StreamLayout.grid || ids.length == 1) {
    return _grid(ids, size, gap);
  }
  final focus = spotlightFocus(ids, focusId);
  final others = [...ids]..remove(focus);
  final n = others.length;
  if (layout == StreamLayout.spotlightVertical) {
    final stripWidth = min(220.0, size.width * 0.24);
    final mainWidth = size.width - stripWidth - gap;
    final tileHeight = min(
      stripWidth / _tileAspect,
      (size.height - gap * (n - 1)) / n,
    );
    return {
      focus: Rect.fromLTWH(0, 0, mainWidth, size.height),
      for (var i = 0; i < n; i++)
        others[i]: Rect.fromLTWH(
          mainWidth + gap,
          i * (tileHeight + gap),
          stripWidth,
          tileHeight,
        ),
    };
  }
  final stripHeight = min(240.0, size.height * 0.3);
  final mainHeight = size.height - stripHeight - gap;
  final tileWidth = min(
    stripHeight * _tileAspect,
    (size.width - gap * (n - 1)) / n,
  );
  return {
    focus: Rect.fromLTWH(0, 0, size.width, mainHeight),
    for (var i = 0; i < n; i++)
      others[i]: Rect.fromLTWH(
        i * (tileWidth + gap),
        mainHeight + gap,
        tileWidth,
        stripHeight,
      ),
  };
}

Map<String, Rect> _grid(List<String> ids, Size size, double gap) {
  final n = ids.length;
  var columns = 1;
  var best = 0.0;
  for (var c = 1; c <= n; c++) {
    final rows = (n / c).ceil();
    final cellWidth = (size.width - gap * (c - 1)) / c;
    final cellHeight = (size.height - gap * (rows - 1)) / rows;
    final screenWidth = min(cellWidth, cellHeight * _tileAspect);
    if (screenWidth > best) {
      best = screenWidth;
      columns = c;
    }
  }
  final rows = (n / columns).ceil();
  final cellWidth = (size.width - gap * (columns - 1)) / columns;
  final cellHeight = (size.height - gap * (rows - 1)) / rows;
  return {
    for (var i = 0; i < n; i++)
      ids[i]: () {
        final row = i ~/ columns;
        final inRow = min(columns, n - row * columns);
        final rowWidth = inRow * cellWidth + (inRow - 1) * gap;
        final left = (size.width - rowWidth) / 2;
        return Rect.fromLTWH(
          left + (i % columns) * (cellWidth + gap),
          row * (cellHeight + gap),
          cellWidth,
          cellHeight,
        );
      }(),
  };
}
