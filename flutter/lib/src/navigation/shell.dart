import 'package:flutter/material.dart';

import '../screens/history_screen.dart';
import '../screens/party_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/today_screen.dart';

/// Top-level navigation scaffold with 4 Phase-1 tabs.
///
/// Issue #1 scaffolds Settings as a bottom-nav tab per the issue spec.
/// The design docs (user-experience.md, C5) specify a 3-tab bar with Settings
/// behind a header gear icon; that model will be adopted when S4 Settings
/// lands and this shell is refined.
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
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.local_bar_outlined),
      selectedIcon: Icon(Icons.local_bar),
      label: 'Party',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  static const List<Widget> _screens = [
    TodayScreen(),
    HistoryScreen(),
    PartyScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: _destinations,
      ),
    );
  }
}
