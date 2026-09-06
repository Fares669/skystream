/// How the episode list is laid out, and the control that switches it.
///
/// The same episodes read three ways: a column to scan titles and summaries,
/// one row to flick along, or a wall of cards to see the artwork. Which one
/// suits depends on whether a viewer is picking up where they left off or
/// looking for a particular episode, so it is theirs to choose.
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/localized_text.dart';
import '../../../../shared/widgets/apple_liquid_glass.dart';
import 'details_hero_actions.dart';

enum EpisodeViewMode { list, rail, grid }

/// The chosen layout, remembered for as long as the app is open.
///
/// Held here rather than in a provider because it belongs to nothing but the
/// list on screen, and a viewer who picks the grid on one anime means it for
/// the next one too.
///
/// The list is the one to open on: it names every episode and says what each
/// one is about, which is what a viewer is reading the page to find out.
final ValueNotifier<EpisodeViewMode> episodeViewMode =
    ValueNotifier<EpisodeViewMode>(EpisodeViewMode.list);

/// Three glyphs in a capsule, the chosen one filled.
class EpisodeViewModeToggle extends StatelessWidget {
  const EpisodeViewModeToggle({super.key, this.height = 38});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ValueListenableBuilder<EpisodeViewMode>(
      valueListenable: episodeViewMode,
      builder: (context, mode, _) {
        return AppleLiquidGlassSurface(
          borderRadius: BorderRadius.circular(height / 2),
          // The same dark glass the page's other controls wear.
          fallbackColor: kDetailsHeroGlassFallback,
          fallbackBorder: BorderSide(
            color: colors.onSurfaceVariant.withValues(alpha: 0.12),
          ),
          child: SizedBox(
            height: height,
            // The three follow the app's language, so in Arabic the list —
            // the one to reach for first — is the one nearest the edge the
            // eye starts from.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeButton(
                  mode: EpisodeViewMode.list,
                  current: mode,
                  icon: Icons.view_list_rounded,
                  size: height,
                  tooltip: appText(context, english: 'List', arabic: 'قائمة'),
                ),
                _ModeButton(
                  mode: EpisodeViewMode.rail,
                  current: mode,
                  icon: Icons.view_carousel_rounded,
                  size: height,
                  tooltip: appText(context, english: 'Row', arabic: 'صف'),
                ),
                _ModeButton(
                  mode: EpisodeViewMode.grid,
                  current: mode,
                  icon: Icons.grid_view_rounded,
                  size: height,
                  tooltip: appText(context, english: 'Grid', arabic: 'شبكة'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.current,
    required this.icon,
    required this.size,
    required this.tooltip,
  });

  final EpisodeViewMode mode;
  final EpisodeViewMode current;
  final IconData icon;
  final double size;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = mode == current;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Material(
          // The chosen one is filled rather than merely brighter: three
          // glyphs of the same colour gave no answer to which was on.
          color: selected ? colors.onSurface : Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => episodeViewMode.value = mode,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                icon,
                size: 18,
                color: selected ? colors.surface : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
