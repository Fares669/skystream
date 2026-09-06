import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/account/animewitcher_account_models.dart';
import '../../characters/presentation/characters_screen.dart';
import '../../settings/presentation/account_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/presentation/widgets/settings_widgets.dart';
import 'broadcast_schedule_screen.dart';
import 'coming_soon_screen.dart';
import 'global_statistics_screen.dart';
import 'recent_watched_screen.dart';
import 'seasons_screen.dart';
import '../../../shared/widgets/apple_liquid_glass.dart';
import '../../../core/utils/localized_text.dart';
import 'more_sidebar_shell.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  /// One sidebar row per settings group, drawn from the settings screen
  /// itself so the two cannot list different things.
  List<MoreDestination> _settingsDestinations(
    BuildContext context,
    WidgetRef ref,
  ) {
    const icons = <IconData>[
      Icons.tune_rounded,
      Icons.play_circle_outline_rounded,
      Icons.download_rounded,
      Icons.image_outlined,
      Icons.storage_rounded,
      Icons.info_outline_rounded,
    ];

    final groups = const SettingsScreen()
        .settingsSections(context, ref)
        .whereType<SettingsGroup>()
        .toList(growable: false);

    return <MoreDestination>[
      for (var i = 0; i < groups.length; i++)
        MoreDestination(
          icon: i < icons.length ? icons[i] : Icons.settings_rounded,
          label: groups[i].title,
          builder: (_) => _SettingsGroupPane(index: i),
        ),
    ];
  }

  bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = _isArabic(context);
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 88;
    final accountState = ref.watch(animeWitcherAccountControllerProvider);
    final accountProfile = accountState.asData?.value.profile;
    final accountPhotoUrl = accountProfile?.photoUrl?.trim() ?? '';

    // A window with room for two columns keeps the list of destinations on
    // screen beside the one being read, and opens on the account rather than
    // on a page of links to press.
    //
    // Measured in pixels rather than asked of the device class: the sidebar
    // takes 272 of them, and what is left has to be a page in its own right.
    // A tablet in portrait is "tablet or larger" and has no such room.
    const twoPaneMinimumWidth = 1000.0;
    if (MediaQuery.sizeOf(context).width >= twoPaneMinimumWidth) {
      return Scaffold(
        appBar: AppBar(centerTitle: false),
        body: MoreSidebarShell(
          header: MoreSidebarHeader(
            name: accountProfile == null
                ? appText(context, english: 'Sign in', arabic: 'تسجيل الدخول')
                : _accountDisplayName(accountProfile),
            // No address here. This card sits on screen the whole time the
            // More section is open, and the account page is where an address
            // belongs — behind an eye, at that.
            subtitle: accountProfile == null
                ? appText(
                    context,
                    english: 'Sync your lists and progress',
                    arabic: 'مزامنة القوائم والتقدم',
                  )
                : appText(
                    context,
                    english: 'Signed in',
                    arabic: 'مسجّل الدخول',
                  ),
            photoUrl: accountPhotoUrl,
          ),
          groups: <MoreDestinationGroup>[
            MoreDestinationGroup(
              heading: moreHeadingSetup(context),
              items: <MoreDestination>[
                MoreDestination(
                  icon: Icons.person_rounded,
                  label: isArabic
                      ? 'حساب AnimeWitcher'
                      : 'AnimeWitcher account',
                  builder: (_) => const AnimeWitcherAccountScreen(),
                ),
              ],
            ),
            MoreDestinationGroup(
              heading: moreHeadingWatching(context),
              items: <MoreDestination>[
                MoreDestination(
                  icon: Icons.history_rounded,
                  label: isArabic ? 'آخر المشاهدات' : 'Recently watched',
                  builder: (_) => const RecentWatchedScreen(),
                ),
                MoreDestination(
                  icon: Icons.groups_rounded,
                  label: isArabic ? 'الشخصيات' : 'Characters',
                  builder: (_) => const CharactersScreen(),
                ),
              ],
            ),
            MoreDestinationGroup(
              heading: moreHeadingBrowse(context),
              items: <MoreDestination>[
                MoreDestination(
                  icon: Icons.upcoming_rounded,
                  label: isArabic ? 'القادم قريبًا' : 'Coming soon',
                  builder: (_) => const ComingSoonScreen(),
                ),
                MoreDestination(
                  icon: Icons.query_stats_rounded,
                  label: isArabic ? 'الإحصائيات العالمية' : 'Global statistics',
                  builder: (_) => const GlobalStatisticsScreen(),
                ),
                MoreDestination(
                  icon: Icons.calendar_month_rounded,
                  label: isArabic ? 'المواسم' : 'Seasons',
                  builder: (_) => const SeasonsScreen(),
                ),
                MoreDestination(
                  icon: Icons.calendar_view_week_rounded,
                  label: isArabic ? 'جدول البث' : 'Broadcast schedule',
                  builder: (_) => const BroadcastScheduleScreen(),
                ),
              ],
            ),
            // Settings arrive as their own rows rather than as one row that
            // opens a page of six groups: the sidebar is the place a viewer
            // looks for "player" or "downloads", and a list of names is what
            // it is for.
            MoreDestinationGroup(
              heading: moreHeadingApp(context),
              items: _settingsDestinations(context, ref),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      // No title: the window's caption buttons are painted over this same
      // corner, and the two collided. The bar stays for its spacing.
      appBar: AppBar(centerTitle: false),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
        children: [
          _MoreTile(
            icon: accountProfile == null
                ? Icons.account_circle_rounded
                : Icons.cloud_done_rounded,
            leading: accountPhotoUrl.isEmpty
                ? null
                : CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundImage: NetworkImage(accountPhotoUrl),
                    onForegroundImageError: (_, _) {},
                    child: Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
            title: accountProfile == null
                ? (isArabic
                      ? 'تسجيل الدخول أو إنشاء حساب'
                      : 'Sign in or create an account')
                : _accountDisplayName(accountProfile),
            subtitle: accountState.isLoading
                ? (isArabic
                      ? 'جارٍ التحقق من الحساب...'
                      : 'Checking account...')
                : accountProfile == null
                ? (isArabic
                      ? 'مزامنة القوائم والحلقات المشاهدة '
                            'وتقدم التشغيل'
                      : 'Sync lists, watched episodes, and playback progress')
                : accountProfile.email ??
                      (isArabic ? 'المزامنة مفعلة' : 'Synchronization enabled'),
            trailing: accountState.isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const AnimeWitcherAccountScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.history_rounded,
            title: isArabic ? 'آخر المشاهدات' : 'Recently watched',
            subtitle: isArabic
                ? 'آخر الأنميات والأفلام التي شاهدتها'
                : 'Anime and movies you watched recently',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const RecentWatchedScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.groups_rounded,
            title: isArabic ? 'الشخصيات' : 'Characters',
            subtitle: isArabic
                ? 'تصفح الشخصيات وابحث عنها وأدر المفضلة'
                : 'Browse, search, and favorite characters',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const CharactersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.upcoming_rounded,
            title: isArabic ? 'القادم قريبًا' : 'Coming soon',
            subtitle: isArabic
                ? 'أنميات لم يتم بثها بعد حسب بيانات AnimeWitcher'
                : 'Anime that has not aired yet, from AnimeWitcher',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const ComingSoonScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.query_stats_rounded,
            title: isArabic ? 'الإحصائيات العالمية' : 'Global statistics',
            subtitle: isArabic
                ? 'إحصائيات المشاهدات والحلقات والأفلام'
                : 'Global viewing, episode, and movie statistics',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const GlobalStatisticsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.calendar_month_rounded,
            title: isArabic ? 'المواسم' : 'Seasons',
            subtitle: isArabic
                ? 'الموسم السابق والحالي والقادم وجميع المواسم'
                : 'Previous, current, next, and all seasons',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const SeasonsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.calendar_view_week_rounded,
            title: isArabic ? 'جدول البث' : 'Broadcast schedule',
            subtitle: isArabic
                ? 'الأنميات موزعة على أيام الأسبوع السبعة'
                : 'Anime grouped across the seven weekdays',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => const BroadcastScheduleScreen(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: theme.dividerColor.withValues(alpha: 0.55)),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.settings_rounded,
            title: isArabic ? 'الإعدادات' : 'Settings',
            subtitle: isArabic
                ? 'إعدادات التطبيق والمشغل'
                : 'App and player settings',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The same glass every other surface in the app wears — the taskbar, the
    // menus, the buttons on an anime's page. These rows were the last flat
    // panels left, each with its glyph in a filled square of the accent,
    // which made a column of eight read as eight badges rather than a list.
    return AppleLiquidGlassSurface(
      borderRadius: BorderRadius.circular(18),
      interactive: true,
      // One blur per row, in a list that scrolls: the cost lands on every
      // frame and buys a blurred copy of the flat page behind it.
      fallbackBlur: false,
      fallbackColor: colors.surfaceContainerHighest.withValues(alpha: 0.75),
      fallbackBorder: BorderSide(
        color: colors.onSurfaceVariant.withValues(alpha: 0.1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                leading ?? Icon(icon, size: 24, color: colors.onSurface),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _accountDisplayName(AnimeWitcherProfile profile) {
  final userName = profile.userName?.trim() ?? '';
  if (userName.isNotEmpty) return userName;
  final email = profile.email?.trim() ?? '';
  return email.isEmpty ? 'AnimeWitcher' : email;
}

/// One settings group, filling the pane beside the sidebar.
///
/// Read from the settings screen on every build rather than captured once:
/// these rows show live values — the theme, the concurrency, the cache size —
/// and a captured widget would go stale the moment one changed.
class _SettingsGroupPane extends ConsumerWidget {
  const _SettingsGroupPane({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = const SettingsScreen()
        .settingsSections(context, ref)
        .whereType<SettingsGroup>()
        .toList(growable: false);
    if (index >= groups.length) return const SizedBox.shrink();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        8,
        16,
        8,
        MediaQuery.viewPaddingOf(context).bottom + 96,
      ),
      children: [groups[index]],
    );
  }
}
