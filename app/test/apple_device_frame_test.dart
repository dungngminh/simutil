import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/stream/ios/apple_chrome.dart';
import 'package:simutil_app/src/ui/shared/apple_device_frame.dart';

// iPhone 17e: DeviceKit `phone13`, 22pt bezel, 68pt outline radius.
const _phone13 = AppleChrome(
  body: Size(434, 888),
  screen: Size(390, 844),
  outerRadius: 68,
);

/// A viewport big enough that only the tile width limits the frame.
void _largeView(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(2000, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('screenRadius', () {
    test('outline radius minus the bezel', () {
      expect(_phone13.screenRadius, 46);
    });

    test('square screen when the bezel is deeper than the outline radius', () {
      // `phone` chrome (home-button iPhones): 28pt sides, 111pt top/bottom.
      const homeButton = AppleChrome(
        body: Size(375 + 56, 667 + 222),
        screen: Size(375, 667),
        outerRadius: 61,
      );
      expect(homeButton.screenRadius, 0);
    });
  });

  // Small grid tiles, about 1:1 and large tiles: the screen must sit exactly
  // on the bezel opening at every scale.
  for (final width in [180.0, 445.0, 900.0]) {
    testWidgets('screen fills the opening at width $width', (tester) async {
      _largeView(tester);
      const screenKey = Key('screen');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: width,
              child: const AppleDeviceFrame(
                chrome: _phone13,
                maxHeight: 2000,
                child: SizedBox.expand(key: screenKey),
              ),
            ),
          ),
        ),
      );

      final frame = tester.getRect(find.byType(FittedBox));
      final screen = tester.getRect(find.byKey(screenKey));
      final scale = width / 434;
      expect(frame.width, moreOrLessEquals(434 * scale));
      expect(screen.width, moreOrLessEquals(390 * scale));
      expect(screen.height, moreOrLessEquals(844 * scale));
      expect(screen.left - frame.left, moreOrLessEquals(22 * scale));
      expect(screen.top - frame.top, moreOrLessEquals(22 * scale));
    });
  }

  testWidgets('the bezel scales with the screen', (tester) async {
    _largeView(tester);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            child: AppleDeviceFrame(
              chrome: _phone13,
              maxHeight: 2000,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    // Laid out at the body's size in points, then scaled by the FittedBox.
    final inner = find.descendant(
      of: find.byType(FittedBox),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 434 && w.height == 888,
      ),
    );
    expect(inner, findsOneWidget);
    expect(tester.getRect(inner).width, moreOrLessEquals(200));
  });
}
