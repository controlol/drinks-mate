import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/providers.dart';
import '../screens/history_screen.dart';
import '../screens/party_screen.dart';
import '../screens/today_screen.dart';

/// Top-level navigation scaffold.
///
/// Three-tab bottom bar (Today → Party → History) per C5 and user-experience.md.
/// Settings is reached via the gear icon in each tab's header (full-screen push);
/// the tab bar is hidden while Settings is open because the Navigator route
/// covers [AppShell] entirely — matching the spec exactly.
///
/// [IndexedStack] keeps all three screens alive so scroll position and loaded
/// data survive tab switches.
///
/// Also owns two of the five lazy auto-end trigger points (party-session.md
/// §Auto-end is computed lazily): app foreground and Today/Party/History tab
/// open. [IndexedStack] keeps every tab's state alive, so a tab switch after
/// the first never re-runs `initState` — the check has to live here, on
/// [NavigationBar.onDestinationSelected] plus once in [initState] for the
/// initial Today tab. The other three trigger points (drink logged, Settings
/// opened) are handled at their own call sites.
///
/// Also the single [WidgetsBindingObserver] in the app: on
/// [AppLifecycleState.resumed] it invalidates the day-boundary providers
/// (issue #95) so a stale "today"/7-day window is corrected immediately on
/// resume, rather than relying solely on each provider's own boundary
/// [Timer] — which may not fire promptly if the OS suspended the app across
/// the boundary.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.water_drop_outlined),
      selectedIcon: Icon(Icons.water_drop),
      label: 'Today',
    ),
    NavigationDestination(
      icon: Icon(Icons.local_bar_outlined),
      selectedIcon: Icon(Icons.local_bar),
      label: 'Party',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'History',
    ),
  ];

  static const List<Widget> _screens = [
    TodayScreen(),
    PartyScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkAutoEnd());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkAutoEnd());
      _invalidateDayWindowProviders();
    }
  }

  Future<void> _checkAutoEnd() =>
      ref.read(partySessionRepositoryProvider).checkAndApplyAutoEnd();

  /// Forces every day-boundary provider to recompute "now" and resubscribe
  /// on resume (issue #95), rather than relying solely on each provider's
  /// own boundary [Timer] to have fired while backgrounded.
  void _invalidateDayWindowProviders() {
    ref.invalidate(todayTotalMlProvider);
    ref.invalidate(todayEntriesProvider);
    ref.invalidate(sevenDayAverageMlProvider);
    ref.invalidate(sevenDayDaysOnGoalProvider);
    ref.invalidate(presetUsageStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          unawaited(_checkAutoEnd());
        },
        destinations: _destinations,
      ),
    );
  }
}
