import 'package:animewitcher/shared/widgets/app_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a back press at the shell', () {
    test('never pops the last route on desktop', () {
      // There is nothing under it: the pop left an empty black window.
      expect(
        shellBackLeavesApp(isAtDefaultHome: true, isDesktopPlatform: true),
        isFalse,
      );
    });

    test('still backs out of the app on a handset', () {
      expect(
        shellBackLeavesApp(isAtDefaultHome: true, isDesktopPlatform: false),
        isTrue,
      );
    });

    test('is handled by the shell when away from the default tab', () {
      for (final desktop in <bool>[true, false]) {
        expect(
          shellBackLeavesApp(
            isAtDefaultHome: false,
            isDesktopPlatform: desktop,
          ),
          isFalse,
          reason: 'the shell switches branches instead',
        );
      }
    });
  });
}
