import 'package:flutter/material.dart';
import 'package:animewitcher/l10n/generated/app_localizations.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// The colour of the show more / show less toggle.
  ///
  /// The accent is right in a card on the page's own background and loud on
  /// artwork, where the words around it are white.
  final Color? toggleColor;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 4,
    this.style,
    this.textAlign,
    this.toggleColor,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;
  bool _toggleFocused = false;

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  // Cached `TextPainter.didExceedMaxLines` result. Recomputed only when the
  // input that affects it (text, maxLines, style, max width) actually
  // changes — not on every parent rebuild. Without this, scrolling /
  // theming / locale change can re-run a full TextPainter.layout() for
  // multi-hundred-character synopses every frame.
  bool _didExceedMaxLines = false;
  String? _cachedText;
  int? _cachedMaxLines;
  double? _cachedMaxWidth;
  TextStyle? _cachedStyle;
  TextDirection? _cachedTextDirection;

  bool _recomputeIfNeeded(
    BoxConstraints constraints,
    TextDirection textDirection,
  ) {
    if (_cachedText == widget.text &&
        _cachedMaxLines == widget.maxLines &&
        _cachedMaxWidth == constraints.maxWidth &&
        _cachedStyle == widget.style &&
        _cachedTextDirection == textDirection) {
      return _didExceedMaxLines;
    }
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: widget.maxLines,
      textDirection: textDirection,
    )..layout(maxWidth: constraints.maxWidth);
    _didExceedMaxLines = textPainter.didExceedMaxLines;
    textPainter.dispose();
    _cachedText = widget.text;
    _cachedMaxLines = widget.maxLines;
    _cachedMaxWidth = constraints.maxWidth;
    _cachedStyle = widget.style;
    _cachedTextDirection = textDirection;
    return _didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTruncated = _recomputeIfNeeded(constraints, textDirection);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _isExpanded ? null : widget.maxLines,
              overflow: _isExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: widget.style,
              textAlign: widget.textAlign,
            ),
            if (isTruncated || _isExpanded) ...[
              const SizedBox(height: 4),
              // Focusable toggle with a clear keyboard/D-pad focus cue (the
              // default InkWell focus overlay is invisible over the hero image).
              // FocusableActionDetector only highlights for keyboard/remote
              // navigation — never for a touch tap — and maps Enter/Select to
              // the toggle.
              FocusableActionDetector(
                mouseCursor: SystemMouseCursors.click,
                onShowFocusHighlight: (v) => setState(() => _toggleFocused = v),
                actions: <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      _toggle();
                      return null;
                    },
                  ),
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _toggleFocused
                          ? colorScheme.primary.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _toggleFocused
                            ? colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: _toggleFocused
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.55,
                                ),
                                blurRadius: 18,
                                spreadRadius: 1.5,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      _isExpanded ? l10n.showLess : l10n.showMore,
                      style: TextStyle(
                        color: widget.toggleColor ?? colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: (widget.style?.fontSize ?? 14) * 0.9,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
