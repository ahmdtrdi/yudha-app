import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';

class AppTabShell extends StatelessWidget {
  const AppTabShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const List<_TabItemData> _tabs = <_TabItemData>[
    _TabItemData(
      route: AppRoutes.lobby,
      label: 'Lobby',
      defaultAsset: 'assets/icons/navigation/nav_lobby_default.svg',
      activeAsset: 'assets/icons/navigation/nav_lobby_active.svg',
    ),
    _TabItemData(
      route: AppRoutes.pvp,
      label: 'PvP',
      defaultAsset: 'assets/icons/navigation/nav_pvp_default.svg',
      activeAsset: 'assets/icons/navigation/nav_pvp_active.svg',
    ),
    _TabItemData(
      route: AppRoutes.leaderboard,
      label: 'Rank',
      defaultAsset: 'assets/icons/navigation/nav_rank_default.svg',
      activeAsset: 'assets/icons/navigation/nav_rank_active.svg',
    ),
    _TabItemData(
      route: AppRoutes.practice,
      label: 'Practice',
      defaultAsset: 'assets/icons/navigation/nav_practice_default.svg',
      activeAsset: 'assets/icons/navigation/nav_practice_active.svg',
    ),
    _TabItemData(
      route: AppRoutes.profile,
      label: 'Profile',
      defaultAsset: 'assets/icons/navigation/nav_profile_default.svg',
      activeAsset: 'assets/icons/navigation/nav_profile_active.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppColors.warriorNavy.withValues(alpha: 0.08),
            ),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.warriorNavy.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 4),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: 4,
            ),
            child: Row(
              children: List<Widget>.generate(_tabs.length, (int index) {
                final _TabItemData tab = _tabs[index];
                final bool selected = index == _selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go(tab.route),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Icon container — active gets a navy rounded square
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.warriorNavy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: selected
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.warriorNavy.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              selected ? tab.activeAsset : tab.defaultAsset,
                              width: 22,
                              height: 22,
                              colorFilter: selected
                                  ? null
                                  : ColorFilter.mode(
                                      AppColors.textMuted,
                                      BlendMode.srcIn,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Label — always visible below the icon
                        Text(
                          tab.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? AppColors.warriorNavy
                                : AppColors.textMuted,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  int get _selectedIndex {
    for (int i = 0; i < _tabs.length; i++) {
      final String route = _tabs[i].route;
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

class _TabItemData {
  const _TabItemData({
    required this.route,
    required this.label,
    required this.defaultAsset,
    required this.activeAsset,
  });

  final String route;
  final String label;
  final String defaultAsset;
  final String activeAsset;
}
