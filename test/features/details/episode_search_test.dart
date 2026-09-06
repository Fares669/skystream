import 'package:animewitcher/features/details/presentation/widgets/episode_search.dart';
import 'package:flutter_test/flutter_test.dart';

bool _matches(int number, String query, {String name = ''}) =>
    episodeMatchesQuery(number: number, name: name, query: query);

void main() {
  group('finding an episode by number', () {
    test('an empty query keeps every episode', () {
      expect(_matches(1, ''), isTrue);
      expect(_matches(1177, '   '), isTrue);
    });

    test('reaches a four-figure episode exactly', () {
      expect(_matches(1177, '1177'), isTrue);
      expect(_matches(1178, '1177'), isFalse);
    });

    test('narrows as the number is typed', () {
      // Someone on their way to 847 sees 8, then 84, then 847 — the point of
      // matching from the start rather than requiring the whole number.
      expect(_matches(847, '8'), isTrue);
      expect(_matches(847, '84'), isTrue);
      expect(_matches(847, '847'), isTrue);
      expect(_matches(748, '84'), isFalse, reason: 'not a substring match');
    });

    test('reads Arabic-Indic digits as the numbers they are', () {
      expect(_matches(12, '١٢'), isTrue);
      expect(_matches(21, '١٢'), isFalse);
    });

    test('falls back to the title for anything that is not a number', () {
      expect(_matches(3, 'الأبراج', name: 'سحرة الأبراج'), isTrue);
      expect(_matches(3, 'Zodiac', name: 'zodiac magic'), isTrue);
      expect(_matches(3, 'dragons', name: 'سحرة الأبراج'), isFalse);
    });
  });
}
