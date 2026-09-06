import '../domain/entity/multimedia_item.dart';

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
