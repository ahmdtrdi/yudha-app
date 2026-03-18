import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';

class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YUDHA Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Pilih mode untuk memulai',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _RouteButton(
              label: 'PvP Battle',
              onTap: () => context.go(AppRoutes.pvp),
            ),
            _RouteButton(
              label: 'Leaderboard',
              onTap: () => context.go(AppRoutes.leaderboard),
            ),
            _RouteButton(
              label: 'Practice Session',
              onTap: () => context.go(AppRoutes.practice),
            ),
            _RouteButton(
              label: 'Profile',
              onTap: () => context.go(AppRoutes.profile),
            ),
            _RouteButton(
              label: 'Interview',
              onTap: () => context.push(AppRoutes.interview),
            ),
            _RouteButton(
              label: 'Store',
              onTap: () => context.push(AppRoutes.store),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteButton extends StatelessWidget {
  const _RouteButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(onPressed: onTap, child: Text(label)),
    );
  }
}
