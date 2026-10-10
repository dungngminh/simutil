import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/settings/view_settings_cubit.dart';
import 'package:simutil_app/src/ui/streams/stream_layout.dart';

void main() {
  const size = Size(1000, 600);

  test('grid puts wide windows in one row and centers a short last row', () {
    final rects = streamRects(['a', 'b', 'c'], size, layout: StreamLayout.grid);
    expect(rects.values.map((r) => r.top).toSet(), {0});

    final five = streamRects(
      List.generate(5, (i) => '$i'),
      const Size(600, 1000),
      layout: StreamLayout.grid,
    );
    final lastRow = five.values.where((r) => r.top == five['4']!.top);
    final left = lastRow.map((r) => r.left).reduce((a, b) => a < b ? a : b);
    final right = lastRow.map((r) => r.right).reduce((a, b) => a > b ? a : b);
    expect(lastRow.length, lessThan(5));
    expect((left + right) / 2, closeTo(300, 0.01));
  });

  test('spotlight keeps the focused stream large, others in a strip', () {
    final rects = streamRects(
      ['a', 'b', 'c'],
      size,
      layout: StreamLayout.spotlightVertical,
      focusId: 'b',
    );
    expect(rects['b']!.height, size.height);
    expect(rects['a']!.left, greaterThan(rects['b']!.right));
    expect(rects['c']!.top, greaterThan(rects['a']!.bottom));
  });

  test('spotlight falls back to the first stream', () {
    final rects = streamRects(
      ['a', 'b'],
      size,
      layout: StreamLayout.spotlightVertical,
      focusId: 'gone',
    );
    expect(rects['a']!.height, size.height);
  });
  test('horizontal spotlight puts the others in a row at the bottom', () {
    final rects = streamRects(
      ['a', 'b', 'c'],
      size,
      layout: StreamLayout.spotlightHorizontal,
      focusId: 'b',
    );
    expect(rects['b']!.width, size.width);
    expect(rects['a']!.top, greaterThan(rects['b']!.bottom));
    expect(rects['c']!.top, rects['a']!.top);
    expect(rects['c']!.left, greaterThan(rects['a']!.right));
    expect(rects['a']!.width, closeTo(rects['a']!.height * 0.56, 0.01));
    expect(rects['c']!.bottom, closeTo(size.height, 0.01));
  });

  test('horizontal strip shrinks thumbnails to fit the width', () {
    final ids = List.generate(12, (i) => '$i');
    final rects = streamRects(
      ids,
      size,
      layout: StreamLayout.spotlightHorizontal,
    );
    expect(rects['11']!.right, lessThanOrEqualTo(size.width + 0.01));
  });

  test('spotlight keeps the current orientation', () {
    final cubit = ViewSettingsCubit()..spotlight('a');
    expect(cubit.stateValue.layout, StreamLayout.spotlightVertical);
    cubit
      ..setLayout(StreamLayout.spotlightHorizontal)
      ..spotlight('b');
    expect(cubit.stateValue.layout, StreamLayout.spotlightHorizontal);
    expect(cubit.stateValue.spotlightId, 'b');
  });
}
