import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animewitcher/core/navigation/taskbar_destination.dart';
import 'package:animewitcher/shared/widgets/apple_liquid_glass.dart';
import 'package:animewitcher/shared/widgets/custom_bottom_nav.dart';

import '../../core/utils/responsive_breakpoints.dart';
import '../../features/settings/presentation/general_settings_provider.dart';

/// Whether a back press is allowed to pop the shell route itself.
///
/// Backing out of the app is Android's gesture and still belongs there. On a
/// desktop window there is nothing underneath this route, so the pop tears the
/// view down and leaves an empty black window with only the caption buttons —
/// which is what a stray back press looked like.
bool shellBackLeavesApp({
  required bool isAtDefaultHome,
  required bool isDesktopPlatform,
}) => isAtDefaultHome && !isDesktopPlatform;

class AppScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  void _onItemTapped(int index, BuildContext context) {
    if (appleUsesPersistentLiquidGlassHeader) {
      applePersistentGlassHeaderController.setActiveBranch(index);
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  int _getRouteIndex(String route) {
    return taskbarDestinationForRoute(route)?.branchIndex ??
        TaskbarDestination.home.branchIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (appleUsesPersistentLiquidGlassHeader) {
      final activeBranch = widget.navigationShell.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          applePersistentGlassHeaderController.setActiveBranch(activeBranch);
        }
      });
    }

    final generalSettings = ref.watch(generalSettingsProvider);
    final defaultIndex = _getRouteIndex(generalSettings.defaultHomeScreen);
    final taskbarDestinations = visibleTaskbarDestinations(
      generalSettings.taskbarOrder,
      generalSettings.hiddenTaskbarItems,
    );
    final isAtDefaultHome = widget.navigationShell.currentIndex == defaultIndex;

    final bottomInset = CustomBottomNavBar.bottomInsetFor(context);
    final navBarTotalHeight = CustomBottomNavBar.height + bottomInset;
    final mq = MediaQuery.of(context);

    return PopScope(
      canPop: shellBackLeavesApp(
        isAtDefaultHome: isAtDefaultHome,
        isDesktopPlatform: ResponsiveBreakpoints.isDesktopPlatform(),
      ),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isAtDefaultHome) return;
        widget.navigationShell.goBranch(defaultIndex);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: MediaQuery(
          data: mq.copyWith(
            padding: mq.padding.copyWith(
              bottom: mq.padding.bottom + navBarTotalHeight,
            ),
            viewPadding: mq.viewPadding.copyWith(
              bottom: mq.viewPadding.bottom + navBarTotalHeight,
            ),
          ),
          child: widget.navigationShell,
        ),
        bottomNavigationBar: CustomBottomNavBar.usesNativeAppleTabBar
            ? CustomBottomNavBar(
                currentBranchIndex: widget.navigationShell.currentIndex,
                destinations: taskbarDestinations,
                onTap: (destination) =>
                    _onItemTapped(destination.branchIndex, context),
              )
            : Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: bottomInset,
                ),
                child: CustomBottomNavBar(
                  currentBranchIndex: widget.navigationShell.currentIndex,
                  destinations: taskbarDestinations,
                  onTap: (destination) =>
                      _onItemTapped(destination.branchIndex, context),
                ),
              ),
      ),
    );
  }
}
