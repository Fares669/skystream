import 'package:flutter/material.dart';
import '../../../../core/utils/layout_constants.dart';

import 'package:animewitcher/core/utils/localized_text.dart';
import '../../../../shared/widgets/apple_liquid_glass.dart';

/// A run of settings under a quiet heading.
///
/// Harbor's shape, on the phone and the desktop alike: no card around the
/// rows, no fill behind them, just a small grey label and the settings
/// themselves separated by hairlines. The panel had been drawing a box around
/// content that was already a list, and an accent-coloured heading shouting
/// over settings nobody needs shouted at.
class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LayoutConstants.spacingMd,
              LayoutConstants.spacingLg,
              LayoutConstants.spacingMd,
              LayoutConstants.spacingXs,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        Column(children: children),
      ],
    );
  }
}

/// The ground the option panels stand on.
///
/// One flat fill at four-tenths opacity vanished into the app's black page:
/// the rows read as printed straight onto the background rather than sitting
/// on a panel. A fuller fill, a lit top edge, and a border you can actually
/// see make the panel a panel again.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.child,
    this.radius = 16,
    this.fill,
    this.border,
  });

  final Widget child;
  final double radius;

  /// Overrides the fill — a hover state or a warning, in practice.
  final Color? fill;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppleLiquidGlassSurface(
      borderRadius: BorderRadius.circular(radius),
      // Six of these stack up a settings page, and each blur is a layer the
      // GPU re-reads on every scrolled frame — for a picture of the flat page
      // behind them. The fill alone looks the same and costs nothing.
      fallbackBlur: false,
      fallbackColor:
          fill ?? colors.surfaceContainerHighest.withValues(alpha: 0.82),
      fallbackBorder: BorderSide(
        color: border ?? colors.onSurfaceVariant.withValues(alpha: 0.18),
      ),
      // A sheen rather than a second colour: it lifts the top edge on the
      // fallback fill and still reads correctly over Apple's own glass.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0.01),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class SettingsTile extends StatefulWidget {
  final IconData icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;
  final bool isBeta;
  final FocusNode? focusNode;

  const SettingsTile({
    super.key,
    required this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
    this.isBeta = false,
    this.focusNode,
  });

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Focus(
          // Passive observer — we want the inner ListTile's InkWell to remain
          // the actual focus target (it's what handles onTap when OK is
          // pressed). hasFocus on this node reflects "any descendant focused"
          // so onFocusChange still fires when the tile is reached.
          focusNode: widget.focusNode,
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) {
            setState(() => _isFocused = f);
            if (f) {
              // Center the focused setting row in the viewport.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ctx = FocusManager.instance.primaryFocus?.context;
                final ro = ctx?.findRenderObject();
                if (ctx != null && ctx.mounted && ro != null) {
                  Scrollable.maybeOf(ctx)?.position.ensureVisible(
                    ro,
                    alignment: 0.5,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.fastOutSlowIn,
                  );
                }
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _isFocused
                  ? primary.withValues(alpha: 0.22)
                  : Colors.transparent,
              border: Border.all(
                color: _isFocused ? primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                focusColor: Colors.transparent,
                hoverColor: primary.withValues(alpha: 0.10),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.spacingMd,
                  vertical: LayoutConstants.spacingXs,
                ),
                // The glyph without a tile around it. A filled square on
                // every row made a column of settings read as a column of
                // badges; Harbor draws the mark and nothing else.
                leading:
                    widget.leading ??
                    SizedBox.square(
                      dimension: 24,
                      child: Icon(
                        widget.icon,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 21,
                      ),
                    ),
                minLeadingWidth: 24,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ),
                    if (widget.isBeta) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          appText(context, english: 'BETA', arabic: 'تجريبي'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: widget.subtitle != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          widget.subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      )
                    : null,
                trailing:
                    widget.trailing ??
                    const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: widget.onTap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        if (!widget.isLast && !_isFocused)
          // A hairline between rows, not a box around them.
          Divider(
            height: 1,
            indent: LayoutConstants.spacingMd,
            endIndent: LayoutConstants.spacingMd,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
          ),
      ],
    );
  }
}
