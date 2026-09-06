import '../domain/entity/multimedia_item.dart';
import 'relative_time.dart';

/// Server catalog type as written (`مسلسل`, `فيلم`, `خاصة`, `اونا`, `اوفا`),
/// falling back to a label derived from [MultimediaItem.contentType].
String? catalogTypeLabel(MultimediaItem item) {
  final raw = item.catalogType?.trim() ?? '';
  if (raw.isNotEmpty) return raw;
  switch (item.contentType) {
    case MultimediaContentType.movie:
      return 'فيلم';
    case MultimediaContentType.series:
    case MultimediaContentType.anime:
      return 'مسلسل';
    case MultimediaContentType.livestream:
      return 'بث مباشر';
    case MultimediaContentType.other:
      return null;
  }
}

bool hasLatestEpisodeBadge(MultimediaItem item) {
  final badge = item.episodeBadge?.trim() ?? '';
  return badge.isNotEmpty;
}

enum CatalogRatingSource { mal, imdb, animeWitcher }

class CatalogRating {
  const CatalogRating({required this.source, required this.score});

  final CatalogRatingSource source;
  final double score;
}

double? _positiveCatalogScore(String? raw) {
  final value = double.tryParse(raw?.trim() ?? '');
  return value != null && value > 0 ? value : null;
}

String _firstCatalogSync(Map<String, String> syncData, List<String> keys) {
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
      : _firstCatalogSync(syncData, const <String>[
          'imdbId',
          'imdb_id',
          'awImdbId',
        ]);
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

/// Caption under a catalog poster: relative time for latest episodes,
/// otherwise the work type from the server.
String? multimediaCardSubtitle(MultimediaItem item) {
  if (hasLatestEpisodeBadge(item)) {
    final time = formatArabicRelativeTime(item.publishedAt);
    return time.isEmpty ? null : time;
  }
  return catalogTypeLabel(item);
}

/// Year overlay is hidden on latest-episode posters.
int? multimediaCardYear(MultimediaItem item) {
  if (hasLatestEpisodeBadge(item)) return null;
  final year = item.year;
  if (year == null || year <= 0) return null;
  return year;
}

String? dubbedPosterBadge(MultimediaItem item) {
  if (hasLatestEpisodeBadge(item) || !item.isDubbed) return null;
  return 'مدبلج';
}

String? relationPosterBadge(MultimediaItem item) {
  final explicit = item.relationLabel?.trim() ?? '';
  if (explicit.isNotEmpty) return explicit;

  final legacy = item.description?.trim() ?? '';
  const knownLegacyLabels = <String>{
    'previous',
    'next',
    'movie',
    'ova',
    'ona',
    'special',
    'side story',
    'spin-off',
    'alternative',
    'summary',
    'parent',
    'compilation',
    'adaptation',
    'related',
    'السابق',
    'التالي',
    'فيلم',
    'أوفا',
    'اوفا',
    'اونا',
    'خاصة',
    'قصة جانبية',
    'عمل مشتق',
    'نسخة بديلة',
    'ملخص',
    'العمل الأصلي',
    'تجميعة',
    'اقتباس مرتبط',
    'عمل مرتبط',
    'عمل مرتبط بالشخصيات',
    'موسم سابق',
    'موسم لاحق',
  };
  if (knownLegacyLabels.contains(legacy.toLowerCase())) return legacy;
  return null;
}

String? multimediaCardPosterBadge(
  MultimediaItem item, {
  bool showRelationBadge = false,
}) {
  if (showRelationBadge) {
    return relationPosterBadge(item) ?? dubbedPosterBadge(item);
  }
  return dubbedPosterBadge(item);
}
