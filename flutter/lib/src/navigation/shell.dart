import 'package:flutter/material.dart';

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
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: _destinations,
      ),
    );
  }
}
