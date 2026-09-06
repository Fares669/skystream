import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/account/account_providers.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/theme/app_theme.dart';
import '../details_ratings.dart';
import 'details_rating_actions.dart';
// The two toast strings moved with the actions that show them. They are
// still part of this file's surface: the panel is what a caller looks at.
export 'details_rating_actions.dart'
    show kRateLoginRequiredToast, kReviewsClosedToast;
import 'scale_rating_bar.dart';

const Key kDetailsRatingsRowKey = Key('details-ratings-row');
const Key kDetailsRatingsWitcherKey = Key('details-ratings-witcher');
const Key kDetailsRatingsMalKey = Key('details-ratings-mal');
const Key kDetailsRatingsImdbKey = Key('details-ratings-imdb');
const Key kDetailsRatingsRateButtonKey = Key('details-ratings-rate-button');
const Key kDetailsRatingsReviewsButtonKey = Key(
  'details-ratings-reviews-button',
);
const Key kDetailsRatingsUserStarsKey = Key('details-ratings-user-stars');
const Key kDetailsRatingsMalBadgeKey = Key('details-ratings-mal-badge');
const Key kDetailsRatingsMalStarKey = Key('details-ratings-mal-star');
const Key kDetailsRatingsImdbBadgeKey = Key('details-ratings-imdb-badge');
const Key kDetailsRatingsImdbStarKey = Key('details-ratings-imdb-star');

const Color kMalBadgeBlue = Color(0xFF2E51A2);
const Color kImdbBadgeYellow = Color(0xFFF5C518);

class DetailsRatingsRow extends ConsumerStatefulWidget {
  const DetailsRatingsRow({super.key, required this.item});

  final MultimediaItem item;

  @override
  ConsumerState<DetailsRatingsRow> createState() => _DetailsRatingsRowState();
}

class _DetailsRatingsRowState extends ConsumerState<DetailsRatingsRow> {
  int? _userRating;
  bool _loadingRating = false;
  bool _loadedRating = false;
  String? _loadedAnimeId;

  AnimeDetailsRatings get _ratings => AnimeDetailsRatings.fromItem(widget.item);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadUserRating();
    });
  }

  @override
  void didUpdateWidget(covariant DetailsRatingsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.url != widget.item.url) {
      _loadUserRating();
    }
  }

  Future<void> _loadUserRating() async {
    final service = ref.read(animeWitcherAccountServiceProvider);
    final animeId = _ratings.animeId;
    if (!service.isSignedIn || animeId.isEmpty) {
      if (mounted) {
        setState(() {
          _userRating = null;
          _loadingRating = false;
          _loadedRating = true;
          _loadedAnimeId = animeId;
        });
      }
      return;
    }
    setState(() {
      _loadingRating = true;
      _loadedAnimeId = animeId;
    });
    try {
      final rating = await service.loadAnimeUserRating(animeId);
      if (!mounted) return;
      setState(() {
        _userRating = rating;
        _loadingRating = false;
        _loadedRating = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRating = false;
        _loadedRating = true;
      });
    }
  }

  Future<void> _onRatePressed() async {
    final outcome = await openAnimeRatingDialog(
      context,
      ref,
      ratings: _ratings,
      initialRating: _userRating ?? 0,
    );
    if (!mounted || !outcome.changed) return;
    setState(() => _userRating = outcome.rating);
  }

  Future<void> _onReviewsPressed() async {
    await openAnimeReviews(context, ref, item: widget.item, ratings: _ratings);
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(animeWitcherAccountControllerProvider);
    final signedIn =
        account.asData?.value.isSignedIn ??
        ref.read(animeWitcherAccountServiceProvider).isSignedIn;
    final animeId = _ratings.animeId;
    if (signedIn &&
        !_loadingRating &&
        (!_loadedRating || _loadedAnimeId != animeId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadUserRating();
      });
    }

    final ratings = _ratings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showExternal = ratings.showExternalColumn;

    return DecoratedBox(
      key: kDetailsRatingsRowKey,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _witcherColumn(context, ratings)),
                  if (showExternal) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        height: 72,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: colors.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    Expanded(child: _externalColumn(context, ratings)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  if (ratings.canRate) ...[
                    Expanded(
                      child: _RatingsActionButton(
                        key: kDetailsRatingsRateButtonKey,
                        icon: (_userRating ?? 0) > 0
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        iconColor: (_userRating ?? 0) > 0
                            ? AppTheme.animeWitcherAccent
                            : null,
                        label: 'قيّم',
                        onPressed: _onRatePressed,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _RatingsActionButton(
                      key: kDetailsRatingsReviewsButtonKey,
                      icon: Icons.rate_review_outlined,
                      label: 'المراجعات',
                      onPressed: _onReviewsPressed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _witcherColumn(BuildContext context, AnimeDetailsRatings ratings) {
    final theme = Theme.of(context);
    final score = ratings.witcherScore;
    return KeyedSubtree(
      key: kDetailsRatingsWitcherKey,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Text(
              'تقييم انمي ويتشر',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.animeWitcherAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 26,
                  color: AppTheme.animeWitcherAccent,
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
            if (ratings.witcherVoteCount != null) ...[
              const SizedBox(height: 4),
              Text(
                '${ratings.witcherVoteCount} تصويت',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ScaleRatingBar(
                key: kDetailsRatingsUserStarsKey,
                rating: _userRating ?? 0,
                enabled: ratings.canRate,
                starSize: 18,
                padding: const EdgeInsets.symmetric(horizontal: 1),
                onChanged: ratings.canRate ? (_) => _onRatePressed() : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _externalColumn(BuildContext context, AnimeDetailsRatings ratings) {
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
}

class _RatingsActionButton extends StatelessWidget {
  const _RatingsActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.onSurface;
    return Material(
      color: colors.surfaceContainerHigh.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor ?? foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
