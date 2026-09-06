/// Rating an anime and reading its reviews, as two actions any part of the
/// details page can offer.
///
/// The panel further down the page has carried both since it was the only
/// place that offered them. The hero row offers them too now, and a second
/// copy of "check the account, ask, save, and say what went wrong" is exactly
/// the kind of thing that drifts apart, so both call these.
library;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/account/account_providers.dart';
import '../../../../core/account/animewitcher_account_models.dart';
import '../../../../core/account/animewitcher_comment_models.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/services/notification_service.dart';
import '../../../comments/presentation/animewitcher_comments_screen.dart';
import '../details_ratings.dart';
import 'scale_rating_bar.dart';

const String kRateLoginRequiredToast = 'يجب تسجيل الدخول';
const String kReviewsClosedToast = 'تم ايقاف المراجعات علي هذا الأنمي';

/// What came back from the rating dialog.
///
/// [changed] separates "left it as it was" from "cleared it", which a bare
/// nullable rating cannot say.
typedef AnimeRatingOutcome = ({bool changed, int? rating});

const AnimeRatingOutcome _unchanged = (changed: false, rating: null);

void _toast(WidgetRef ref, String message, {bool info = true}) {
  final notifications = ref.read(notificationServiceProvider);
  if (info) {
    notifications.showInfo(message);
  } else {
    notifications.showError(message);
  }
}

/// Asks for a rating and records it.
///
/// Returns what is on record afterwards, so a caller showing the score can
/// keep its own copy in step.
Future<AnimeRatingOutcome> openAnimeRatingDialog(
  BuildContext context,
  WidgetRef ref, {
  required AnimeDetailsRatings ratings,
  int initialRating = 0,
}) async {
  final service = ref.read(animeWitcherAccountServiceProvider);
  if (!service.isSignedIn) {
    _toast(ref, kRateLoginRequiredToast);
    return _unchanged;
  }
  if (!ratings.canRate) return _unchanged;

  final selected = await showAnimeRatingDialog(
    context,
    initialRating: initialRating,
  );
  if (selected == null) return _unchanged;

  try {
    if (selected == 0) {
      await service.clearAnimeUserRating(ratings.animeId);
      return (changed: true, rating: null);
    }
    final saved = await service.saveAnimeUserRating(ratings.animeId, selected);
    return (changed: true, rating: saved);
  } catch (error) {
    if (error is AnimeWitcherAccountException &&
        error.code == 'not-signed-in') {
      _toast(ref, kRateLoginRequiredToast);
    } else {
      _toast(ref, 'تعذر حفظ التقييم', info: false);
    }
    return _unchanged;
  }
}

/// Opens the reviews for [item], unless they are closed.
///
/// The details payload says whether they are, and the account service is
/// asked again in case that has changed since the page loaded; if it cannot
/// be reached, the flag that came with the page stands.
Future<void> openAnimeReviews(
  BuildContext context,
  WidgetRef ref, {
  required MultimediaItem item,
  required AnimeDetailsRatings ratings,
}) async {
  if (ratings.reviewsClosed) {
    _toast(ref, kReviewsClosedToast);
    return;
  }

  final service = ref.read(animeWitcherAccountServiceProvider);
  if (service.isSignedIn && ratings.animeId.isNotEmpty) {
    try {
      final closed = await service.isAnimeReviewsClosed(ratings.animeId);
      if (!context.mounted) return;
      if (closed) {
        _toast(ref, kReviewsClosedToast);
        return;
      }
    } catch (_) {
      // Keep the local details flag as the fallback.
    }
  }

  final target = animeWitcherAnimeReviewTarget(item);
  if (target == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnimeWitcherCommentsScreen(target: target),
    ),
  );
}

/// The dialog itself: ten stars, and clearing by choosing none.
Future<int?> showAnimeRatingDialog(
  BuildContext context, {
  required int initialRating,
}) {
  var rating = initialRating.clamp(0, 10);
  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('قيّم'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$rating /10',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ScaleRatingBar(
                      rating: rating,
                      starSize: 30,
                      onChanged: (value) {
                        setDialogState(() => rating = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (initialRating > 0)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 0),
                  child: const Text('مسح التقييم'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: rating <= 0
                    ? null
                    : () => Navigator.pop(dialogContext, rating),
                child: const Text('تأكيد'),
              ),
            ],
          );
        },
      );
    },
  );
}
