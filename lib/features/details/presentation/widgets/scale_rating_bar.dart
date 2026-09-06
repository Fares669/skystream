import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// 1–10 star bar matching APK `ScaleRatingBar`: filled/empty gold stars.
/// Leftmost star is 1 and rightmost is 10 even on an RTL page. Only the
/// tapped (or newly selected) star bounces.
class ScaleRatingBar extends StatefulWidget {
  const ScaleRatingBar({
    super.key,
    required this.rating,
    this.onChanged,
    this.enabled = true,
    this.starSize = 28,
    this.itemCount = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
  });

  final int rating;
  final ValueChanged<int>? onChanged;
  final bool enabled;
  final double starSize;
  final int itemCount;
  final EdgeInsets padding;

  @override
  State<ScaleRatingBar> createState() => _ScaleRatingBarState();
}

class _ScaleRatingBarState extends State<ScaleRatingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;
  int? _pulseIndex;

  /// The star the pointer is over, if any.
  ///
  /// Hovering fills up to it, so a viewer sees the score they are about to
  /// leave before committing to it — the same way the bar reads after they
  /// have chosen.
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 1.28,
    ).animate(CurvedAnimation(parent: _bounce, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(covariant ScaleRatingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rating != widget.rating && widget.rating > 0) {
      _pulseIndex ??= widget.rating;
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _select(int value) {
    if (!widget.enabled || widget.onChanged == null) return;
    setState(() => _pulseIndex = value);
    _bounce.forward(from: 0);
    widget.onChanged!(value);
  }

  @override
  Widget build(BuildContext context) {
    const gold = AppTheme.animeWitcherAccent;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              for (var index = 1; index <= widget.itemCount; index++)
                _StarButton(
                  index: index,
                  filled: index <= (_hoverIndex ?? widget.rating),
                  previewing: _hoverIndex != null,
                  pulsing: index == _pulseIndex && _bounce.isAnimating,
                  scale: _scale.value,
                  size: widget.starSize,
                  color: gold,
                  enabled: widget.enabled && widget.onChanged != null,
                  padding: widget.padding,
                  onPressed: () => _select(index),
                  onHover: (hovering) {
                    if (!widget.enabled || widget.onChanged == null) return;
                    setState(() => _hoverIndex = hovering ? index : null);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.index,
    required this.filled,
    required this.previewing,
    required this.pulsing,
    required this.scale,
    required this.size,
    required this.color,
    required this.enabled,
    required this.padding,
    required this.onPressed,
    required this.onHover,
  });

  final int index;
  final bool filled;

  /// Whether the fill is a hover preview rather than the score on record.
  final bool previewing;

  final bool pulsing;
  final double scale;
  final double size;
  final Color color;
  final bool enabled;
  final EdgeInsets padding;
  final VoidCallback onPressed;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final icon = filled ? Icons.star_rounded : Icons.star_border_rounded;
    final child = Transform.scale(
      scale: pulsing ? scale : 1,
      child: Icon(
        icon,
        size: size,
        // A previewed star is a shade softer than a chosen one, so the bar
        // still says which is a promise and which is a record.
        color: filled
            ? (previewing ? color.withValues(alpha: 0.75) : color)
            : color.withValues(alpha: 0.38),
      ),
    );
    return Semantics(
      button: enabled,
      selected: filled,
      label: '$index',
      child: InkWell(
        onTap: enabled ? onPressed : null,
        onHover: onHover,
        customBorder: const CircleBorder(),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
