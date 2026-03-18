import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';

class AppTabShell extends StatelessWidget {
  const AppTabShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const List<String> _tabRoutes = <String>[
    AppRoutes.lobby,
    AppRoutes.pvp,
    AppRoutes.leaderboard,
    AppRoutes.practice,
    AppRoutes.profile,
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Lobby'),
        NavigationDestination(icon: Icon(Icons.sports_esports), label: 'PvP'),
        NavigationDestination(
          icon: Icon(Icons.emoji_events_outlined),
          label: 'Rank',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          label: 'Practice',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: _destinations,
        onDestinationSelected: (int index) {
          context.go(_tabRoutes[index]);
        },
      ),
    );
  }

  int get _selectedIndex {
    for (int i = 0; i < _tabRoutes.length; i++) {
      final String route = _tabRoutes[i];
      if (route == AppRoutes.lobby && location == AppRoutes.lobby) {
        return i;
      }
      if (route != AppRoutes.lobby && location.startsWith(route)) {
        return i;
      }
    }
    return 0;
  }
}
