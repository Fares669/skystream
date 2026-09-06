import 'package:flutter/material.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import 'widgets/details_ratings_row.dart';
import 'widgets/premium_details_widgets.dart';

/// Exact APK `snippet_ecchi_warning.xml` copy. Do not rephrase.
const String kAdultContentWarningText =
    'تنبيه تم تصنيف هذا الانمي على أنه (للبالغين) ، وبالتالي قد يحتوي على (عنف شديد) أو (دم) أو (محتوى جنسي) أو (لغة فظة) قد لا تكون مناسبة للمشاهدين القصر.';

/// APK `details.age` value that shows the warning.
const String kAdultContentWarningAge = '+17';

/// APK Arabic genre token that shows the warning.
const String kAdultContentWarningGenre = 'ايتشي';

const Key kAdultContentWarningKey = Key('ecchi-warning');

/// True when the official APK would show `snippet_ecchi_warning`.
///
/// Conditions are OR, not AND:
/// 1. [tags] contains the Arabic genre `ايتشي` (joined tag strings are split)
/// 2. `details.age` equals `+17` ([MultimediaItem.contentRating] / `awAge`)
///
/// The hide-ecchi account setting is intentionally ignored: the APK only uses
/// it to omit titles from lists, never to hide this banner.
bool shouldShowAdultContentWarning(MultimediaItem item) {
  return _ageIsPlus17(item) ||
      containsArabicEcchiGenre(item.tags ?? const <String>[]);
}

bool containsArabicEcchiGenre(Iterable<String> tags) {
  for (final tag in tags) {
    for (final part in tag.split(RegExp(r'[,،|/]+'))) {
      if (_normalizeArabicGenre(part) == kAdultContentWarningGenre) {
        return true;
      }
    }
  }
  return false;
}

bool _ageIsPlus17(MultimediaItem item) {
  for (final raw in <String?>[item.syncData?['awAge'], item.contentRating]) {
    if (raw != null && raw.trim() == kAdultContentWarningAge) return true;
  }
  return false;
}

String _normalizeArabicGenre(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('إ', 'ا')
      .replaceAll('أ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[\s_-]+'), '');
}

/// Red CardView matching `snippet_ecchi_warning.xml`.
class AdultContentWarningBanner extends StatelessWidget {
  const AdultContentWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: kAdultContentWarningKey,
      color: Colors.red,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          kAdultContentWarningText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Countdown, adult warning, ratings row, then the story card.
///
/// Pass [showCountdown] false on desktop, where the countdown already lives
/// in the hero. The warning and ratings still sit immediately above
/// [storyCard].
class DetailsCountdownAndStory extends StatelessWidget {
  const DetailsCountdownAndStory({
    super.key,
    required this.item,
    required this.storyCard,
    this.showCountdown = true,
    this.showRatings = true,
    this.showRatingsSummary = true,
  });

  final MultimediaItem item;
  final Widget storyCard;
  final bool showCountdown;
  final bool showRatings;
  final bool showRatingsSummary;

  @override
  Widget build(BuildContext context) {
    final showNext = showCountdown && item.nextAiring != null;
    final showWarning = shouldShowAdultContentWarning(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showNext) ...[
          NextAiringWidget(nextAiring: item.nextAiring!),
          const SizedBox(height: 8),
        ],
        if (showWarning) ...[
          const AdultContentWarningBanner(),
          const SizedBox(height: 8),
        ],
        if (showRatings) ...[
          DetailsRatingsRow(item: item, showSummary: showRatingsSummary),
          const SizedBox(height: 8),
        ],
        storyCard,
      ],
    );
  }
}
