from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match, found {count}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) Preserve AnimeWitcher's APK `details.imdb_rate` in the Flutter sync payload.
provider = 'lib/core/extensions/providers/animewitcher_native_provider.dart'
replace_once(
    provider,
    """    putSync(\n      'awMalScoringUsers',\n      details['mal_num_scoring_users'] ?? details['mal_scoring_users'],\n    );\n    // APK details score is `rating.rate`. Do not fall back to `average_rate`.\n""",
    """    putSync(\n      'awMalScoringUsers',\n      details['mal_num_scoring_users'] ?? details['mal_scoring_users'],\n    );\n    // APK animations without a MAL score use the stored IMDb rating. Keep the\n    // server value in syncData so the details UI can reproduce that fallback\n    // without scraping IMDb or issuing a second metadata request.\n    putSync(\n      'awImdbScore',\n      details['imdb_rate'] ??\n          details['imdbRate'] ??\n          details['imdb_score'] ??\n          details['imdbScore'] ??\n          source['imdb_rate'] ??\n          source['imdbRate'] ??\n          source['imdb_score'] ??\n          source['imdbScore'],\n    );\n    // APK details score is `rating.rate`. Do not fall back to `average_rate`.\n""",
)

# 2) Parse MAL as the primary external source and IMDb as the APK fallback.
ratings = 'lib/features/details/presentation/details_ratings.dart'
replace_once(
    ratings,
    """import '../../../core/domain/entity/multimedia_item.dart';\n\n/// Parsed APK details ratings fields for the details page row.\n///\n/// Witcher score is `rating.rate`. MAL uses `details.mal_mean` and\n/// `details.mal_num_scoring_users`. Vote counts are never invented.\nclass AnimeDetailsRatings {\n""",
    """import '../../../core/domain/entity/multimedia_item.dart';\n\nenum ExternalRatingSource { mal, imdb }\n\n/// Parsed APK details ratings fields for the details page row.\n///\n/// Witcher score is `rating.rate`. MAL is the primary external score; when\n/// AnimeWitcher's APK has no usable MAL score it falls back to\n/// `details.imdb_rate`. Vote counts are never invented.\nclass AnimeDetailsRatings {\n""",
)
replace_once(
    ratings,
    """    this.malMean,\n    this.malScoringUsers,\n    this.malId,\n    this.imdbId,\n""",
    """    this.malMean,\n    this.malScoringUsers,\n    this.malId,\n    this.imdbId,\n    this.imdbScore,\n""",
)
replace_once(
    ratings,
    """  final int? malScoringUsers;\n  final String? malId;\n  final String? imdbId;\n  final bool isUnaired;\n""",
    """  final int? malScoringUsers;\n  final String? malId;\n  final String? imdbId;\n  final double? imdbScore;\n  final bool isUnaired;\n""",
)
replace_once(
    ratings,
    """  /// APK hides the MAL card when neither `mal_id` nor `imdb_id` is present.\n  /// The score UI also needs `mal_mean`, so the column stays hidden without it.\n  bool get showMalColumn {\n    if (malMean == null) return false;\n    return _hasId(malId) || _hasId(imdbId);\n  }\n\n  /// Displayed MAL scoring-user count. Unaired titles are forced to 0.\n  int? get displayedMalScoringUsers {\n    if (!showMalColumn) return null;\n    if (isUnaired) return 0;\n    return malScoringUsers;\n  }\n\n  bool get canRate => !isUnaired && animeId.isNotEmpty;\n""",
    """  /// External score source, matching the APK's MAL -> IMDb fallback.\n  ///\n  /// Prefer a real MAL id + mean. If MAL is unavailable, an IMDb id +\n  /// `imdb_rate` is used. The final MAL branch preserves older AnimeWitcher\n  /// payloads that exposed `mal_mean` alongside only an IMDb id.\n  ExternalRatingSource? get externalSource {\n    if (malMean != null && _hasId(malId)) {\n      return ExternalRatingSource.mal;\n    }\n    if (imdbScore != null && _hasId(imdbId)) {\n      return ExternalRatingSource.imdb;\n    }\n    if (malMean != null && _hasId(imdbId)) {\n      return ExternalRatingSource.mal;\n    }\n    return null;\n  }\n\n  bool get showExternalColumn => externalSource != null;\n  bool get showMalColumn => externalSource == ExternalRatingSource.mal;\n  bool get showImdbColumn => externalSource == ExternalRatingSource.imdb;\n\n  double? get externalScore => switch (externalSource) {\n    ExternalRatingSource.mal => malMean,\n    ExternalRatingSource.imdb => imdbScore,\n    null => null,\n  };\n\n  /// Displayed MAL scoring-user count. IMDb has no scoring-user field in the\n  /// AnimeWitcher APK model, so no count is invented for the fallback.\n  int? get displayedMalScoringUsers {\n    if (!showMalColumn) return null;\n    if (isUnaired) return 0;\n    return malScoringUsers;\n  }\n\n  int? get displayedExternalScoringUsers =>\n      showMalColumn ? displayedMalScoringUsers : null;\n\n  bool get canRate => !isUnaired && animeId.isNotEmpty;\n""",
)
replace_once(
    ratings,
    """      malId: malId,\n      imdbId: imdbId,\n      isUnaired: _isUnaired(item, data),\n""",
    """      malId: malId,\n      imdbId: imdbId,\n      imdbScore: _positiveScore(\n        data['awImdbScore'] ?? data['imdbRate'] ?? data['imdb_rate'],\n      ),\n      isUnaired: _isUnaired(item, data),\n""",
)

# 3) Render the chosen external source. IMDb uses its familiar yellow badge.
row = 'lib/features/details/presentation/widgets/details_ratings_row.dart'
replace_once(
    row,
    """const Key kDetailsRatingsMalKey = Key('details-ratings-mal');\nconst Key kDetailsRatingsRateButtonKey = Key('details-ratings-rate-button');\n""",
    """const Key kDetailsRatingsMalKey = Key('details-ratings-mal');\nconst Key kDetailsRatingsImdbKey = Key('details-ratings-imdb');\nconst Key kDetailsRatingsRateButtonKey = Key('details-ratings-rate-button');\n""",
)
replace_once(
    row,
    """const Key kDetailsRatingsMalStarKey = Key('details-ratings-mal-star');\n\nconst Color kMalBadgeBlue = Color(0xFF2E51A2);\n""",
    """const Key kDetailsRatingsMalStarKey = Key('details-ratings-mal-star');\nconst Key kDetailsRatingsImdbBadgeKey = Key('details-ratings-imdb-badge');\nconst Key kDetailsRatingsImdbStarKey = Key('details-ratings-imdb-star');\n\nconst Color kMalBadgeBlue = Color(0xFF2E51A2);\nconst Color kImdbBadgeYellow = Color(0xFFF5C518);\n""",
)
replace_once(
    row,
    """    final showMal = ratings.showMalColumn;\n\n    return DecoratedBox(\n""",
    """    final showExternal = ratings.showExternalColumn;\n\n    return DecoratedBox(\n""",
)
replace_once(
    row,
    """                  if (showMal) ...[\n                    Padding(\n""",
    """                  if (showExternal) ...[\n                    Padding(\n""",
)
replace_once(
    row,
    """                    Expanded(child: _malColumn(context, ratings)),\n""",
    """                    Expanded(child: _externalColumn(context, ratings)),\n""",
)
p = Path(row)
text = p.read_text(encoding='utf-8')
start = text.find('  Widget _malColumn(BuildContext context, AnimeDetailsRatings ratings) {')
end = text.find('\n}\n\nclass _RatingsActionButton', start)
if start < 0 or end < 0:
    raise RuntimeError('details_ratings_row.dart: MAL column block not found')
replacement = r'''  Widget _externalColumn(
    BuildContext context,
    AnimeDetailsRatings ratings,
  ) {
    final theme = Theme.of(context);
    final source = ratings.externalSource;
    final isImdb = source == ExternalRatingSource.imdb;
    final score = ratings.externalScore;
    final users = ratings.displayedExternalScoringUsers;
    final badgeColor = isImdb ? kImdbBadgeYellow : kMalBadgeBlue;
    final badgeTextColor = isImdb ? Colors.black : Colors.white;
    final columnKey = isImdb ? kDetailsRatingsImdbKey : kDetailsRatingsMalKey;
    final badgeKey = isImdb
        ? kDetailsRatingsImdbBadgeKey
        : kDetailsRatingsMalBadgeKey;
    final starKey = isImdb
        ? kDetailsRatingsImdbStarKey
        : kDetailsRatingsMalStarKey;

    return KeyedSubtree(
      key: columnKey,
      child: Column(
        children: [
          Container(
            key: badgeKey,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isImdb ? 'IMDb' : 'MAL',
              style: theme.textTheme.labelSmall?.copyWith(
                color: badgeTextColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            textDirection: TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                key: starKey,
                Icons.star_rounded,
                size: 26,
                color: badgeColor,
              ),
              const SizedBox(width: 6),
              Text(
                score == null ? '—' : formatRatingScore(score),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isImdb
                ? 'IMDb Score'
                : users == null
                ? 'MAL Score'
                : '($users)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
'''
text = text[:start] + replacement + text[end:]
p.write_text(text, encoding='utf-8')

# 4) Provider integration test proves imdb_rate survives Firestore details mapping.
provider_test = 'test/core/extensions/providers/animewitcher_ratings_fields_test.dart'
replace_once(
    provider_test,
    """          'mal_mean': _doubleField(8.73),\n          'mal_num_scoring_users': _intField(668508),\n          'state': _stringField('مستمر'),\n""",
    """          'mal_mean': _doubleField(8.73),\n          'mal_num_scoring_users': _intField(668508),\n          'imdb_rate': _doubleField(7.8),\n          'state': _stringField('مستمر'),\n""",
)
replace_once(
    provider_test,
    """    expect(item.syncData?['awMalScoringUsers'], '668508');\n    expect(item.syncData?['awImdbId'], 'tt0409591');\n""",
    """    expect(item.syncData?['awMalScoringUsers'], '668508');\n    expect(item.syncData?['awImdbId'], 'tt0409591');\n    expect(item.syncData?['awImdbScore'], '7.8');\n""",
)
replace_once(
    provider_test,
    """  test('maps reviews_closed from the anime document', () async {\n""",
    """  test('maps IMDb score for animation details without MAL', () async {\n    final provider = AnimeWitcherNativeProvider(\n      _stubDio(<String, dynamic>{\n        'name': _stringField('The Legend of Tarzan'),\n        'imdb_id': _stringField('tt0283754'),\n        'rating': _mapField(<String, dynamic>{'rate': _doubleField(8.37)}),\n        'details': _mapField(<String, dynamic>{\n          'imdb_rate': _doubleField(7.4),\n          'state': _stringField('مكتمل'),\n        }),\n      }),\n      SettingsRepository(_TestStorageService()),\n    );\n\n    final item = await provider.getDetails(url);\n    expect(item.syncData?['awMalScore'], isNull);\n    expect(item.syncData?['awImdbId'], 'tt0283754');\n    expect(item.syncData?['awImdbScore'], '7.4');\n  });\n\n  test('maps reviews_closed from the anime document', () async {\n""",
)

# 5) Ratings model tests: IMDb fallback + MAL precedence.
model_test = 'test/features/details/presentation/details_ratings_test.dart'
replace_once(
    model_test,
    """  test('unaired titles disable rating and zero MAL scoring users', () {\n""",
    """  test('uses IMDb when MAL is unavailable', () {\n    final ratings = AnimeDetailsRatings.fromItem(\n      _item(\n        imdbId: 'tt0283754',\n        syncData: const <String, String>{\n          'awScore': '8.37',\n          'awImdbScore': '7.4',\n        },\n      ),\n    );\n    expect(ratings.externalSource, ExternalRatingSource.imdb);\n    expect(ratings.showExternalColumn, isTrue);\n    expect(ratings.showImdbColumn, isTrue);\n    expect(ratings.showMalColumn, isFalse);\n    expect(ratings.externalScore, 7.4);\n    expect(ratings.displayedExternalScoringUsers, isNull);\n  });\n\n  test('MAL takes priority when MAL and IMDb ratings both exist', () {\n    final ratings = AnimeDetailsRatings.fromItem(\n      _item(\n        imdbId: 'tt0409591',\n        syncData: const <String, String>{\n          'malId': '20',\n          'awMalScore': '8.73',\n          'awMalScoringUsers': '668508',\n          'awImdbScore': '7.8',\n        },\n      ),\n    );\n    expect(ratings.externalSource, ExternalRatingSource.mal);\n    expect(ratings.showMalColumn, isTrue);\n    expect(ratings.showImdbColumn, isFalse);\n    expect(ratings.externalScore, 8.73);\n    expect(ratings.displayedExternalScoringUsers, 668508);\n  });\n\n  test('unaired titles disable rating and zero MAL scoring users', () {\n""",
)

# 6) Widget regression: IMDb badge/score appears and MAL does not.
widget_test = 'test/features/details/presentation/details_ratings_row_test.dart'
replace_once(
    widget_test,
    """  testWidgets('hides the MAL column without mal_id or imdb_id', (tester) async {\n""",
    """  testWidgets('shows IMDb fallback when MAL is unavailable', (tester) async {\n    await _pumpStack(\n      tester,\n      item: _item(\n        imdbId: 'tt0283754',\n        syncData: const <String, String>{\n          'awScore': '8.37',\n          'awImdbId': 'tt0283754',\n          'awImdbScore': '7.4',\n        },\n      ),\n      showCountdown: false,\n    );\n\n    expect(find.byKey(kDetailsRatingsMalKey), findsNothing);\n    expect(find.byKey(kDetailsRatingsImdbKey), findsOneWidget);\n    expect(find.text('IMDb'), findsOneWidget);\n    expect(find.text('7.4'), findsOneWidget);\n    expect(find.text('IMDb Score'), findsOneWidget);\n    final badge = tester.widget<Container>(\n      find.byKey(kDetailsRatingsImdbBadgeKey),\n    );\n    expect((badge.decoration as BoxDecoration).color, kImdbBadgeYellow);\n    final label = tester.widget<Text>(\n      find.descendant(\n        of: find.byKey(kDetailsRatingsImdbBadgeKey),\n        matching: find.text('IMDb'),\n      ),\n    );\n    expect(label.style?.color, Colors.black);\n    final star = tester.widget<Icon>(find.byKey(kDetailsRatingsImdbStarKey));\n    expect(star.color, kImdbBadgeYellow);\n  });\n\n  testWidgets('hides the MAL column without mal_id or imdb_id', (tester) async {\n""",
)

print('IMDb fallback patch applied successfully')
