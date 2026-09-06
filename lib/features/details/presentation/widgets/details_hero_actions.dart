/// The actions that sit over the banner on a desktop details page.
///
/// One filled pill carries the thing a viewer came to do — start the episode
/// they are up to — and everything else is a glass capsule beside it, so the
/// row reads as one action and a set of options rather than a wall of equal
/// buttons.
library;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../shared/widgets/apple_liquid_glass.dart';
import '../details_controller.dart';
import '../details_ratings.dart';
import 'details_layout_widgets.dart';

/// Height shared by every control in the row, so they sit on one line.
const double kDetailsHeroActionHeight = 46;

/// What the glass falls back to where the system has none of its own.
///
/// The pill and the round buttons beside it were reaching for different
/// colours — a pale surface tint against a dark one — so the row read as two
/// kinds of control rather than one. Dark and translucent, so the artwork
/// behind carries the colour.
const Color kDetailsHeroGlassFallback = Color(0x73000000);

/// The filled pill that starts playback.
class DetailsHeroPlayPill extends ConsumerWidget {
  const DetailsHeroPlayPill({
    super.key,
    required this.item,
    required this.details,
    required this.itemUrl,
  });

  final MultimediaItem item;
  final MultimediaItem? details;
  final String itemUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLaunching = ref.watch(
      detailsControllerProvider(itemUrl).select((s) => s.isLaunching),
    );
    final ready =
        details != null &&
        (details!.episodes?.isNotEmpty ?? false) &&
        !isLaunching;

    final label = detailsPlayActionLabel(
      context,
      ref,
      item: item,
      itemUrl: itemUrl,
    );

    // White on the artwork, the way the one unmissable control on a poster
    // frame is: everything else in this row is glass, and this is not.
    const background = Color(0xFFF2F3F5);
    const foreground = Color(0xFF101114);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: ready ? background : background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(kDetailsHeroActionHeight / 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: ready
              ? () => ref
                    .read(detailsControllerProvider(itemUrl).notifier)
                    .handlePlayPress(context, details!)
              : null,
          child: SizedBox(
            height: kDetailsHeroActionHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLaunching)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                      color: foreground,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass capsule carrying a label, for the options beside the play pill.
///
/// [trailing] is for a control that opens something — a chevron on a menu —
/// so the capsule says whether it acts or offers a choice.
class DetailsHeroPill extends StatelessWidget {
  const DetailsHeroPill({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.selected = false,
    this.trailing,
    this.tooltip,
    this.fallbackColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Fills the glyph and tints it, the way a chosen row in a menu is marked.
  final bool selected;

  final Widget? trailing;
  final String? tooltip;

  /// The glass fill to use where the system draws none of its own.
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurface;

    final pill = AppleLiquidGlassSurface(
      borderRadius: BorderRadius.circular(kDetailsHeroActionHeight / 2),
      interactive: onPressed != null,
      // Five of these sit side by side on the hero and each blur is its own
      // per-frame layer. The fill is 45% black over a hero that is already
      // scrimmed, so it carries the look without one.
      fallbackBlur: false,
      fallbackColor: fallbackColor ?? kDetailsHeroGlassFallback,
      fallbackBorder: BorderSide(
        color: colors.onSurfaceVariant.withValues(alpha: 0.12),
      ),
      child: SizedBox(
        height: kDetailsHeroActionHeight,
        child: Padding(
          padding: EdgeInsets.only(left: 18, right: trailing == null ? 18 : 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
        ),
      ),
    );

    final tapped = onPressed == null
        ? pill
        : Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(kDetailsHeroActionHeight / 2),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onPressed, child: pill),
          );

    if (tooltip == null) return tapped;
    return Tooltip(message: tooltip!, child: tapped);
  }
}

/// A round glass button for the hero row, for actions with no label.
///
/// Each stands on its own rather than sharing a capsule: they do unrelated
/// things, and a viewer reaching for one of them is not choosing from a set.
class DetailsHeroIconButton extends StatelessWidget {
  const DetailsHeroIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.foregroundColor,
    this.fallbackColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? foregroundColor;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: AppleLiquidGlassSurface(
        borderRadius: BorderRadius.circular(kDetailsHeroActionHeight / 2),
        interactive: true,
        fallbackBlur: false,
        fallbackColor: fallbackColor ?? kDetailsHeroGlassFallback,
        fallbackBorder: BorderSide(
          color: colors.onSurfaceVariant.withValues(alpha: 0.12),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: kDetailsHeroActionHeight,
              child: Icon(
                icon,
                size: 21,
                color: foregroundColor ?? colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The two scores, small, on the line above the buttons.
///
/// The page carries a full ratings panel further down with the stars and the
/// way in to rate and to read reviews. This is the glance version: what the
/// anime scores, where a viewer is already looking.
class DetailsHeroRatings extends StatelessWidget {
  const DetailsHeroRatings({super.key, required this.item});

  final MultimediaItem item;

  @override
  Widget build(BuildContext context) {
    final ratings = AnimeDetailsRatings.fromItem(item);
    final colors = Theme.of(context).colorScheme;

    final chips = <Widget>[
      if (ratings.witcherScore != null)
        _ScoreChip(
          score: ratings.witcherScore!,
          icon: Icons.star_rounded,
          iconColor: colors.primary,
        ),
      if (ratings.showMalColumn && ratings.malMean != null)
        _ScoreChip(score: ratings.malMean!, label: 'MAL'),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 10, runSpacing: 8, children: chips);
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.score,
    this.label,
    this.icon,
    this.iconColor,
  });

  final double score;
  final String? label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        // Left to right: a score reads the same in every language, and the
        // mark belongs in front of the number that it qualifies.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: iconColor ?? colors.onSurface),
                const SizedBox(width: 5),
              ],
              if (label != null) ...[
                Text(
                  label!,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                score.toStringAsFixed(score >= 10 ? 0 : 2),
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
