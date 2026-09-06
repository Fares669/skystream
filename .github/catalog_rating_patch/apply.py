from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


# 1) Keep catalog rating source selection in the existing catalog-label utility.
path = Path('lib/core/utils/catalog_label.dart')
text = path.read_text(encoding='utf-8')
anchor = """bool hasLatestEpisodeBadge(MultimediaItem item) {
  final badge = item.episodeBadge?.trim() ?? '';
  return badge.isNotEmpty;
}

"""
addition = anchor + """enum CatalogRatingSource { mal, imdb, animeWitcher }

class CatalogRating {
  const CatalogRating({required this.source, required this.score});

  final CatalogRatingSource source;
  final double score;
}

double? _positiveCatalogScore(String? raw) {
  final value = double.tryParse(raw?.trim() ?? '');
  return value != null && value > 0 ? value : null;
}

String _firstCatalogSync(
  Map<String, String> syncData,
  List<String> keys,
) {
  for (final key in keys) {
    final value = syncData[key]?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// Rating shown on catalog cards without issuing a metadata request per card.
///
/// AnimeWitcher list payloads carry these values in [MultimediaItem.syncData].
/// Match the source app's preference: MAL first, IMDb when MAL is unavailable,
/// then AnimeWitcher's own rating.
CatalogRating? catalogRatingFor(MultimediaItem item) {
  final syncData = item.syncData ?? const <String, String>{};

  final malId = _firstCatalogSync(syncData, const <String>['malId', 'mal_id']);
  final malScore = _positiveCatalogScore(syncData['awMalScore']);
  if (malId.isNotEmpty && malScore != null) {
    return CatalogRating(source: CatalogRatingSource.mal, score: malScore);
  }

  final imdbId = (item.imdbId?.trim().isNotEmpty ?? false)
      ? item.imdbId!.trim()
      : _firstCatalogSync(
          syncData,
          const <String>['imdbId', 'imdb_id', 'awImdbId'],
        );
  final imdbScore = _positiveCatalogScore(syncData['awImdbScore']);
  if (imdbId.isNotEmpty && imdbScore != null) {
    return CatalogRating(source: CatalogRatingSource.imdb, score: imdbScore);
  }

  final animeWitcherScore = _positiveCatalogScore(syncData['awScore']);
  if (animeWitcherScore != null) {
    return CatalogRating(
      source: CatalogRatingSource.animeWitcher,
      score: animeWitcherScore,
    );
  }
  return null;
}

String formatCatalogRatingScore(double score) {
  var value = score.toStringAsFixed(2);
  while (value.contains('.') && value.endsWith('0')) {
    value = value.substring(0, value.length - 1);
  }
  if (value.endsWith('.')) value = value.substring(0, value.length - 1);
  return value;
}

"""
text = replace_once(text, anchor, addition, 'catalog rating helper')
path.write_text(text, encoding='utf-8')


# 2) Carry MAL / IMDb / AnimeWitcher values in the same AnimeWitcher list hit.
path = Path('lib/core/extensions/providers/animewitcher_native_provider.dart')
text = path.read_text(encoding='utf-8')
start = text.index('  MultimediaItem _mapHit(')
end = text.index('  static const List<String> _largePosterKeys', start)
block = text[start:end]
return_anchor = "\n    return MultimediaItem(\n"
if block.count(return_anchor) != 1:
    raise RuntimeError('mapHit return anchor not found exactly once')
rating_map = """
    final hitDetails = _map(source['details']);
    final hitRating = _map(source['rating']);
    void putHitSync(String key, dynamic raw) {
      final value = _text(raw);
      if (value.isNotEmpty) hitSync[key] = value;
    }

    putHitSync(
      'awMalScore',
      hitDetails['mal_mean'] ?? hitDetails['mal_score'],
    );

    var hitImdbId = _firstText(source, const <String>[
      'imdb_id',
      'imdbId',
      'imdbID',
    ]);
    if (hitImdbId.isEmpty) {
      hitImdbId = _firstText(hitDetails, const <String>[
        'imdb_id',
        'imdbId',
        'imdbID',
      ]);
    }
    if (hitImdbId.isNotEmpty) {
      hitSync['imdbId'] = hitImdbId;
      hitSync['imdb_id'] = hitImdbId;
      hitSync['awImdbId'] = hitImdbId;
    }
    putHitSync(
      'awImdbScore',
      hitDetails['imdb_rate'] ??
          hitDetails['imdbRate'] ??
          hitDetails['imdb_score'] ??
          hitDetails['imdbScore'] ??
          source['imdb_rate'] ??
          source['imdbRate'] ??
          source['imdb_score'] ??
          source['imdbScore'],
    );
    putHitSync('awScore', hitRating['rate']);
"""
block = block.replace(return_anchor, rating_map + return_anchor, 1)
text = text[:start] + block + text[end:]

# Season/upcoming browse already requests `details`; add only the small id/rating
# fields to that same request. Similar cards need details as well because they
# previously requested only artwork/type/tags.
start = text.index('  static const List<String> _comingSoonBrowseAttributes')
end = text.index('  static const List<String> _similarAttributes', start)
block = text[start:end]
block = replace_once(
    block,
    """    'details',
    'dubbed',
""",
    """    'details',
    'mal_id',
    'malId',
    'rating',
    'dubbed',
""",
    'coming soon rating attributes',
)
text = text[:start] + block + text[end:]

start = text.index('  static const List<String> _similarAttributes')
end = text.index('  static const List<String> _carouselAttributes', start)
block = text[start:end]
block = replace_once(
    block,
    """    'poster',
    'tags',
""",
    """    'poster',
    'tags',
    'details',
    'mal_id',
    'malId',
    'rating',
""",
    'similar rating attributes',
)
text = text[:start] + block + text[end:]
path.write_text(text, encoding='utf-8')


# 3) Render source-specific rating beside the existing catalog subtitle.
path = Path('lib/shared/widgets/multimedia_card.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    """  /// Smaller gray line under the title: episode time or catalog type.
  final String? subtitle;

""",
    """  /// Smaller gray line under the title: episode time or catalog type.
  final String? subtitle;

  /// Rating already carried by the catalog payload; never loaded by the card.
  final CatalogRating? catalogRating;

""",
    'card rating field',
)
text = replace_once(
    text,
    """    this.subtitle,
    this.year,
""",
    """    this.subtitle,
    this.catalogRating,
    this.year,
""",
    'card constructor rating',
)
text = replace_once(
    text,
    """       subtitle = multimediaCardSubtitle(item),
       year = multimediaCardYear(item),
""",
    """       subtitle = multimediaCardSubtitle(item),
       catalogRating = hasLatestEpisodeBadge(item) ? null : catalogRatingFor(item),
       year = multimediaCardYear(item),
""",
    'fromItem rating',
)
text = replace_once(
    text,
    """    if (caption != null) semanticParts.add(caption);
    final semanticLabel = semanticParts.join('، ');
""",
    """    if (caption != null) semanticParts.add(caption);
    if (catalogRating != null) {
      final source = switch (catalogRating!.source) {
        CatalogRatingSource.mal => 'MAL',
        CatalogRatingSource.imdb => 'IMDb',
        CatalogRatingSource.animeWitcher => 'AnimeWitcher',
      };
      semanticParts.add('$source ${formatCatalogRatingScore(catalogRating!.score)}');
    }
    final semanticLabel = semanticParts.join('، ');
""",
    'rating semantics',
)
text = replace_once(
    text,
    """                caption: caption,
              ),
""",
    """                caption: caption,
                rating: catalogRating,
              ),
""",
    'pass rating to card',
)

caption_start = text.index('  Widget _buildCaption({')
caption_end = text.index('  Widget _buildCard(', caption_start)
new_caption = r'''  Widget _buildCatalogRating(
    BuildContext context,
    CatalogRating rating,
    TextStyle subtitleTextStyle,
  ) {
    final score = Text(
      formatCatalogRatingScore(rating.score),
      maxLines: 1,
      style: subtitleTextStyle,
    );
    final markerSize = (subtitleTextStyle.fontSize ?? 11) - 0.5;

    final Widget marker = switch (rating.source) {
      CatalogRatingSource.mal => Text(
        'MAL',
        key: const ValueKey('catalog-rating-mal'),
        style: TextStyle(
          color: const Color(0xFF2E51A2),
          fontSize: markerSize,
          height: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      CatalogRatingSource.imdb => Text(
        'IMDb',
        key: const ValueKey('catalog-rating-imdb'),
        style: TextStyle(
          color: const Color(0xFFF5C518),
          fontSize: markerSize,
          height: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      CatalogRatingSource.animeWitcher => Icon(
        Icons.star_rounded,
        key: const ValueKey('catalog-rating-animewitcher'),
        color: Theme.of(context).colorScheme.primary,
        size: (subtitleTextStyle.fontSize ?? 11) + 4,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [marker, const SizedBox(width: 4), score],
    );
  }

  Widget _buildCaption({
    required BuildContext context,
    required TextStyle titleTextStyle,
    required TextStyle subtitleTextStyle,
    required String? caption,
    required CatalogRating? rating,
  }) {
    final subtitleHeight =
        (subtitleTextStyle.fontSize ?? 11) * (subtitleTextStyle.height ?? 1.2);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, start: 2, end: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: titleTextStyle,
            ),
            const SizedBox(height: 2),
            if (caption != null || rating != null)
              SizedBox(
                height: subtitleHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (caption != null)
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: subtitleTextStyle,
                        ),
                      ),
                    if (caption != null && rating != null)
                      const SizedBox(width: 7),
                    if (rating != null)
                      _buildCatalogRating(context, rating, subtitleTextStyle),
                  ],
                ),
              )
            else
              SizedBox(height: subtitleHeight),
          ],
        ),
      ),
    );
  }

'''
text = text[:caption_start] + new_caption + text[caption_end:]

# Thread the context/rating through the final private card builder.
card_start = text.index('  Widget _buildCard(')
card_block = text[card_start:]
card_block = replace_once(
    card_block,
    """    required String? caption,
  }) {
""",
    """    required String? caption,
    required CatalogRating? rating,
  }) {
""",
    'buildCard rating arg',
)
card_block = replace_once(
    card_block,
    """    final captionBlock = _buildCaption(
      titleTextStyle: titleTextStyle,
      subtitleTextStyle: subtitleTextStyle,
      caption: caption,
    );
""",
    """    final captionBlock = _buildCaption(
      context: context,
      titleTextStyle: titleTextStyle,
      subtitleTextStyle: subtitleTextStyle,
      caption: caption,
      rating: rating,
    );
""",
    'buildCaption call',
)
text = text[:card_start] + card_block
path.write_text(text, encoding='utf-8')


# 4) Regression coverage for source priority and the actual card markers.
test_path = Path('test/shared/widgets/catalog_rating_badge_test.dart')
test_path.write_text(r'''import 'package:animewitcher/core/domain/entity/multimedia_item.dart';
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
    expect(find.byKey(const ValueKey('catalog-rating-animewitcher')), findsNothing);
    final mal = tester.widget<Text>(find.text('MAL'));
    expect(mal.style?.color, const Color(0xFF2E51A2));
    expect(
      tester.widgetList<Text>(find.byType(Text)).any((text) =>
          (text.data ?? '').contains('•')),
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
    expect(find.byKey(const ValueKey('catalog-rating-animewitcher')), findsNothing);
  });

  testWidgets('AnimeWitcher fallback uses the star marker', (tester) async {
    await pumpCard(
      tester,
      const <String, String>{'awScore': '9.47'},
    );

    expect(
      find.byKey(const ValueKey('catalog-rating-animewitcher')),
      findsOneWidget,
    );
    expect(find.text('9.47'), findsOneWidget);
    expect(find.text('MAL'), findsNothing);
    expect(find.text('IMDb'), findsNothing);
  });
}
''', encoding='utf-8')

print('catalog rating badge patch applied')
