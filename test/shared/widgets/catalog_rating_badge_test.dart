import 'package:animewitcher/core/domain/entity/multimedia_item.dart';
import 'package:animewitcher/core/utils/catalog_label.dart';
import 'package:animewitcher/shared/widgets/multimedia_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MultimediaItem _item(Map<String, String> syncData) => MultimediaItem(
  title: 'Catalog title',
  url: 'https://animewitcher.com/watch/catalog-title',
  posterUrl: '',
  contentType: MultimediaContentType.anime,
  catalogType: 'مسلسل',
  syncData: syncData,
);

void main() {
  test('catalog rating priority is MAL then IMDb then AnimeWitcher', () {
    final all = catalogRatingFor(
      _item(const <String, String>{
        'malId': '20',
        'awMalScore': '8.37',
        'imdbId': 'tt123',
        'awImdbScore': '9.1',
        'awScore': '9.8',
      }),
    );
    expect(all?.source, CatalogRatingSource.mal);
    expect(all?.score, 8.37);

    final imdb = catalogRatingFor(
      _item(const <String, String>{
        'imdbId': 'tt123',
        'awImdbScore': '7.9',
        'awScore': '9.8',
      }),
    );
    expect(imdb?.source, CatalogRatingSource.imdb);
    expect(imdb?.score, 7.9);

    final witcher = catalogRatingFor(
      _item(const <String, String>{'awScore': '9.47'}),
    );
    expect(witcher?.source, CatalogRatingSource.animeWitcher);
    expect(witcher?.score, 9.47);
  });

  test('catalog rating ignores scores without their external id', () {
    final rating = catalogRatingFor(
      _item(const <String, String>{
        'awMalScore': '9.9',
        'awImdbScore': '9.8',
        'awScore': '8.2',
      }),
    );
    expect(rating?.source, CatalogRatingSource.animeWitcher);
    expect(formatCatalogRatingScore(8.20), '8.2');
    expect(formatCatalogRatingScore(8.00), '8');
  });

  Future<void> pumpCard(
    WidgetTester tester,
    Map<String, String> syncData,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFFFD21C)),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 130,
              height: 250,
              child: MultimediaCard.fromItem(
                item: _item(syncData),
                heroTag: 'rating-card-${syncData.hashCode}',
                onTap: () {},
                showImageLoadingShimmer: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('MAL uses a small blue label instead of a star', (tester) async {
    await pumpCard(tester, const <String, String>{
      'malId': '20',
      'awMalScore': '8.37',
      'imdbId': 'tt123',
      'awImdbScore': '9.2',
      'awScore': '9.8',
    });

    expect(find.text('مسلسل'), findsOneWidget);
    expect(find.text('MAL'), findsOneWidget);
    expect(find.text('8.37'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-rating-imdb')), findsNothing);
    expect(
      find.byKey(const ValueKey('catalog-rating-animewitcher')),
      findsNothing,
    );
    final mal = tester.widget<Text>(find.text('MAL'));
    expect(mal.style?.color, const Color(0xFF2E51A2));
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .any((text) => (text.data ?? '').contains('•')),
      isFalse,
    );
  });

  testWidgets('IMDb replaces MAL when MAL is unavailable', (tester) async {
    await pumpCard(tester, const <String, String>{
      'imdbId': 'tt123',
      'awImdbScore': '7.9',
      'awScore': '9.8',
    });

    expect(find.text('IMDb'), findsOneWidget);
    expect(find.text('7.9'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-rating-mal')), findsNothing);
    expect(
      find.byKey(const ValueKey('catalog-rating-animewitcher')),
      findsNothing,
    );
  });

  testWidgets('AnimeWitcher fallback uses the star marker', (tester) async {
    await pumpCard(tester, const <String, String>{'awScore': '9.47'});

    expect(
      find.byKey(const ValueKey('catalog-rating-animewitcher')),
      findsOneWidget,
    );
    expect(find.text('9.47'), findsOneWidget);
    expect(find.text('MAL'), findsNothing);
    expect(find.text('IMDb'), findsNothing);
  });
}
