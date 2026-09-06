import 'package:flutter_test/flutter_test.dart';
import 'package:animewitcher/core/domain/entity/multimedia_item.dart';
import 'package:animewitcher/core/utils/catalog_rating.dart';

MultimediaItem _item(
  Map<String, String> syncData, {
  String? episodeBadge,
}) {
  return MultimediaItem(
    title: 'Example',
    url: 'https://animewitcher.com/watch/example',
    posterUrl: '',
    provider: 'com.fares669.animewitcher.native',
    syncData: syncData,
    episodeBadge: episodeBadge,
  );
}

void main() {
  test('catalog rating prefers MAL over IMDb and AnimeWitcher', () {
    final rating = preferredCatalogRating(
      _item(const <String, String>{
        'awMalScore': '8.73',
        'awImdbScore': '7.8',
        'awScore': '9.47',
      }),
    );

    expect(rating?.source, CatalogRatingSource.mal);
    expect(rating?.score, 8.73);
  });

  test('catalog rating falls back to IMDb when MAL is unavailable', () {
    final rating = preferredCatalogRating(
      _item(const <String, String>{
        'awMalScore': '0',
        'awImdbScore': '7.9',
        'awScore': '9.2',
      }),
    );

    expect(rating?.source, CatalogRatingSource.imdb);
    expect(rating?.score, 7.9);
  });

  test('catalog rating falls back to AnimeWitcher', () {
    final rating = preferredCatalogRating(
      _item(const <String, String>{'awScore': '9.47'}),
    );

    expect(rating?.source, CatalogRatingSource.animeWitcher);
    expect(formatCatalogRatingScore(rating!.score), '9.47');
  });

  test('invalid scores are ignored', () {
    expect(
      preferredCatalogRating(
        _item(const <String, String>{
          'awMalScore': '0',
          'awImdbScore': '',
          'awScore': 'not-a-score',
        }),
      ),
      isNull,
    );
  });

  test('latest episode cards keep their relative-time caption only', () {
    expect(
      preferredCatalogRating(
        _item(
          const <String, String>{'awMalScore': '8.5'},
          episodeBadge: 'حلقة 5',
        ),
      ),
      isNull,
    );
  });
}
