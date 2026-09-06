import 'package:flutter/material.dart';

import 'glass_dialog.dart';

/// Pushes [route] on the root navigator so it covers [AppScaffold] and the
/// bottom taskbar. This is the same stack used by [DetailsRoute] and
/// [ViewAllRoute], and by More-tab screens.
Future<T?> pushOverTaskbar<T>(BuildContext context, Route<T> route) {
  return Navigator.of(context, rootNavigator: true).push<T>(route);
}

/// Shows a modal bottom sheet on the root navigator so it covers the floating
/// pill taskbar. Branch-navigator sheets paint underneath [AppScaffold]'s
/// `bottomNavigationBar` and hide Cancel / the last server row.
Future<T?> showModalOverTaskbar<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    // Drawn inside the glass instead, so the sheet is one surface rather
    // than a handle with a bordered panel under it.
    showDragHandle: false,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    // The sheet brings its own glass, so the default opaque card would only
    // paint over it.
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (context) => GlassSheetSurface(
      showHandle: showDragHandle,
      child: Builder(builder: builder),
    ),
  );
}
