from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'{label}: target not found')
    if text.count(old) != 1:
        raise RuntimeError(f'{label}: expected one target, found {text.count(old)}')
    return text.replace(old, new, 1)


root = Path('.')

# 1) Preserve the three rating sources already present in AnimeWitcher's
# catalog hit. This does not add a network request: details/rating are already
# part of _searchAttributes.
provider_path = root / 'lib/core/extensions/providers/animewitcher_native_provider.dart'
provider = provider_path.read_text(encoding='utf-8')
provider = replace_once(
    provider,
    """    final hitSync = <String, String>{};
    final hitMalId = _malId(source);
""",
    """    final hitSync = <String, String>{};
    final hitDetails = _map(source['details']);
    final hitRating = _map(source['rating']);
    void putHitSync(String key, dynamic raw) {
      final value = _text(raw);
      if (value.isNotEmpty) hitSync[key] = value;
    }

    // Keep the same source priority used by the details screen available on
    // catalog cards without another HTTP request: MAL -> IMDb -> AnimeWitcher.
    putHitSync(
      'awMalScore',
      hitDetails['mal_mean'] ?? hitDetails['mal_score'],
    );
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

    final hitMalId = _malId(source);
""",
    'provider catalog rating metadata',
)
provider_path.write_text(provider, encoding='utf-8')

# 2) Core source-selection helper. It is intentionally outside the details
# feature so shared poster cards do not depend on a feature presentation file.
helper_path = root / 'lib/core/utils/catalog_rating.dart'
helper_path.write_text(
    """import '../domain/entity/multimedia_item.dart';

enum CatalogRatingSource { mal, imdb, animeWitcher }

class CatalogRating {
  const CatalogRating({required this.source, required this.score});

  final CatalogRatingSource source;
  final double score;
}

/// Rating shown beside the catalog caption.
///
/// Source priority mirrors AnimeWitcher: MAL, then IMDb, then AnimeWitcher.
/// Values come from the already-loaded catalog payload. Latest-episode cards
/// keep their relative-time subtitle uncluttered and therefore omit ratings.
CatalogRating? preferredCatalogRating(MultimediaItem item) {
  final episodeBadge = item.episodeBadge?.trim() ?? '';
  if (episodeBadge.isNotEmpty) return null;

  final data = item.syncData ?? const <String, String>{};
  final mal = _positiveScore(data['awMalScore']);
  if (mal != null) {
    return CatalogRating(source: CatalogRatingSource.mal, score: mal);
  }

  final imdb = _positiveScore(
    data['awImdbScore'] ?? data['imdbRate'] ?? data['imdb_rate'],
  );
  if (imdb != null) {
    return CatalogRating(source: CatalogRatingSource.imdb, score: imdb);
  }

  final animeWitcher = _positiveScore(data['awScore']);
  if (animeWitcher != null) {
    return CatalogRating(
      source: CatalogRatingSource.animeWitcher,
      score: animeWitcher,
    );
  }

  return null;
}

String formatCatalogRatingScore(double score) {
  return score
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'[.]$'), '');
}

double? _positiveScore(String? raw) {
  final normalized = _normalizeDigits((raw ?? '').trim());
  if (normalized.isEmpty) return null;
  final match = RegExp(r'[0-9]+(?:[.][0-9]+)?').firstMatch(normalized);
  final score = match == null ? null : double.tryParse(match.group(0)!);
  if (score == null || score <= 0) return null;
  return score;
}

String _normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const eastern = '۰۱۲۳۴۵۶۷۸۹';
  return value
      .replaceAllMapped(
        RegExp(r'[٠-٩]'),
        (match) => '${arabic.indexOf(match.group(0)!)}',
      )
      .replaceAllMapped(
        RegExp(r'[۰-۹]'),
        (match) => '${eastern.indexOf(match.group(0)!)}',
      );
}
""",
    encoding='utf-8',
)

# 3) Render the selected source inline with the existing caption. No bullet is
# inserted. MAL/IMDb replace the star; the star remains only for AnimeWitcher.
card_path = root / 'lib/shared/widgets/multimedia_card.dart'
card = card_path.read_text(encoding='utf-8')
card = replace_once(
    card,
    """import '../../core/domain/entity/multimedia_item.dart';
import '../../core/utils/artwork_quality.dart';
""",
    """import '../../core/domain/entity/multimedia_item.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/artwork_quality.dart';
import '../../core/utils/catalog_rating.dart';
""",
    'card imports',
)
card = replace_once(
    card,
    """  /// Smaller gray line under the title: episode time or catalog type.
  final String? subtitle;

  /// Release year drawn on the bottom-right of the poster.
""",
    """  /// Smaller gray line under the title: episode time or catalog type.
  final String? subtitle;

  /// Preferred catalog rating, using MAL -> IMDb -> AnimeWitcher priority.
  final CatalogRating? catalogRating;

  /// Release year drawn on the bottom-right of the poster.
""",
    'card rating field',
)
card = replace_once(
    card,
    """    this.subtitle,
    this.year,
""",
    """    this.subtitle,
    this.catalogRating,
    this.year,
""",
    'card constructor rating',
)
card = replace_once(
    card,
    """       episodeBadge = item.episodeBadge,
       subtitle = multimediaCardSubtitle(item),
       year = multimediaCardYear(item),
""",
    """       episodeBadge = item.episodeBadge,
       subtitle = multimediaCardSubtitle(item),
       catalogRating = preferredCatalogRating(item),
       year = multimediaCardYear(item),
""",
    'card fromItem rating',
)
card = replace_once(
    card,
    """    if (yearText != null) semanticParts.add(yearText);
    if (caption != null) semanticParts.add(caption);
    final semanticLabel = semanticParts.join('، ');
""",
    """    if (yearText != null) semanticParts.add(yearText);
    if (caption != null) semanticParts.add(caption);
    if (catalogRating case final rating?) {
      final source = switch (rating.source) {
        CatalogRatingSource.mal => 'MAL',
        CatalogRatingSource.imdb => 'IMDb',
        CatalogRatingSource.animeWitcher => 'تقييم انمي ويتشر',
      };
      semanticParts.add('$source ${formatCatalogRatingScore(rating.score)}');
    }
    final semanticLabel = semanticParts.join('، ');
""",
    'card semantics rating',
)
old_caption = """  Widget _buildCaption({
    required TextStyle titleTextStyle,
    required TextStyle subtitleTextStyle,
    required String? caption,
  }) {
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
            if (caption != null)
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: subtitleTextStyle,
              )
            else
              SizedBox(
                height:
                    (subtitleTextStyle.fontSize ?? 11) *
                    (subtitleTextStyle.height ?? 1.2),
              ),
          ],
        ),
      ),
    );
  }
"""
new_caption = """  Widget _buildCatalogRating(TextStyle subtitleTextStyle) {
    final rating = catalogRating!;
    final score = Text(
      formatCatalogRatingScore(rating.score),
      maxLines: 1,
      style: subtitleTextStyle,
    );
    final sourceSize = ((subtitleTextStyle.fontSize ?? 11) - 1).clamp(8.0, 12.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: switch (rating.source) {
        CatalogRatingSource.mal => <Widget>[
          Text(
            'MAL',
            key: const Key('catalog-rating-mal-source'),
            style: subtitleTextStyle.copyWith(
              color: const Color(0xFF2E51A2),
              fontSize: sourceSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          score,
        ],
        CatalogRatingSource.imdb => <Widget>[
          Text(
            'IMDb',
            key: const Key('catalog-rating-imdb-source'),
            style: subtitleTextStyle.copyWith(
              color: const Color(0xFFF5C518),
              fontSize: sourceSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          score,
        ],
        CatalogRatingSource.animeWitcher => <Widget>[
          Icon(
            Icons.star_rounded,
            key: const Key('catalog-rating-witcher-source'),
            size: (subtitleTextStyle.fontSize ?? 11) + 3,
            color: AppTheme.animeWitcherAccent,
          ),
          const SizedBox(width: 3),
          score,
        ],
      },
    );
  }

  Widget _buildCaption({
    required TextStyle titleTextStyle,
    required TextStyle subtitleTextStyle,
    required String? caption,
  }) {
    final hasRating = catalogRating != null;
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
            if (caption != null || hasRating)
              SizedBox(
                height: subtitleHeight,
                child: Row(
                  children: [
                    if (caption != null)
                      Flexible(
                        child: Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: subtitleTextStyle,
                        ),
                      ),
                    // Intentionally no bullet/dot between the catalog caption
                    // and the rating source.
                    if (caption != null && hasRating) const SizedBox(width: 8),
                    if (hasRating) _buildCatalogRating(subtitleTextStyle),
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
"""
card = replace_once(card, old_caption, new_caption, 'card caption renderer')
card_path.write_text(card, encoding='utf-8')

# 4) Temporary regression test. The workflow removes it before committing so
# the connector can add it afterwards and trigger the real PR Flutter checks.
test_path = root / 'test/core/utils/catalog_rating_test.dart'
test_path.write_text(
    """import 'package:flutter_test/flutter_test.dart';
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

  test('catalog rating falls back to AnimeWitcher and keeps its star source', () {
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
          'awScore': '-1',
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
""",
    encoding='utf-8',
)

print('catalog rating patch applied')
