import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/pvp/application/battle_providers.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

class AppTabShell extends ConsumerWidget {
  const AppTabShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const List<_TabItemData> _tabs = <_TabItemData>[
    _TabItemData(
      route: AppRoutes.lobby,
      label: 'Lobby',
      defaultAsset: 'assets/icons/navigation/nav_lobby_default.svg',
    ),
    _TabItemData(
      route: AppRoutes.pvp,
      label: 'PvP',
      defaultAsset: 'assets/icons/navigation/nav_pvp_default.svg',
    ),
    _TabItemData(
      route: AppRoutes.leaderboard,
      label: 'Rank',
      defaultAsset: 'assets/icons/navigation/nav_rank_default.svg',
    ),
    _TabItemData(
      route: AppRoutes.practice,
      label: 'Practice',
      defaultAsset: 'assets/icons/navigation/nav_practice_default.svg',
    ),
    _TabItemData(
      route: AppRoutes.profile,
      label: 'Profile',
      defaultAsset: 'assets/icons/navigation/nav_profile_default.svg',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BattlePhase battlePhase = ref.watch(
      battleControllerProvider.select((state) => state.phase),
    );
    final bool hideNav =
        location.startsWith(AppRoutes.pvp) &&
        battlePhase != BattlePhase.preBattle;

    return Scaffold(
      body: child,
      bottomNavigationBar: hideNav
          ? null
          : ColoredBox(
              key: const ValueKey<String>('app-tab-background'),
              color: AppColors.scholarCream,
              child: SafeArea(
                // Installed iOS PWAs need a little extra breathing room above
                // the home indicator beyond the reported safe inset.
                minimum: EdgeInsets.only(bottom: kIsWeb ? 10 : 4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: SizedBox(
                    height: 71,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          bottom: 5,
                          child: DecoratedBox(
                            key: const ValueKey<String>('app-tab-clay-base'),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDE1E7),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.warriorNavy.withValues(
                                    alpha: 0.1,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          top: 5,
                          child: Container(
                            key: const ValueKey<String>('app-tab-capsule'),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0xFFE8EBEF),
                              ),
                            ),
                            child: Row(
                              children: List<Widget>.generate(_tabs.length, (
                                int index,
                              ) {
                                final _TabItemData tab = _tabs[index];
                                final bool selected = index == _selectedIndex;
                                return Expanded(
                                  child: Semantics(
                                    key: ValueKey<String>(
                                      'app-tab-${tab.label}',
                                    ),
                                    button: true,
                                    selected: selected,
                                    label: tab.label,
                                    child: Tooltip(
                                      message: tab.label,
                                      child: InkWell(
                                        onTap: () => context.go(tab.route),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          alignment: Alignment.center,
                                          children: <Widget>[
                                            if (selected)
                                              Positioned.fill(
                                                child: _ActiveTabIndicator(
                                                  tabLabel: tab.label,
                                                ),
                                              ),
                                            Center(
                                              child: SvgPicture.asset(
                                                tab.defaultAsset,
                                                width: 27,
                                                height: 27,
                                                colorFilter: ColorFilter.mode(
                                                  selected
                                                      ? const Color(0xFF0066DE)
                                                      : const Color(0xFF6C89A5),
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _ActiveTabIndicator extends StatelessWidget {
  const _ActiveTabIndicator({required this.tabLabel});

  final String tabLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: ValueKey<String>('app-tab-indicator-$tabLabel'),
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Positioned.fill(
          child: ClipPath(
            clipper: _ActiveTabHighlightClipper(),
            child: const DecoratedBox(
              key: ValueKey<String>('app-tab-highlight-gradient'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[
                    Color(0x240066DE),
                    Color(0x0A0066DE),
                    Color(0x000066DE),
                  ],
                  stops: <double>[0, 0.42, 1],
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 52,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF0066DE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
      ],
    );
  }
}

class _ActiveTabHighlightClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.88, size.height)
      ..lineTo(size.width * 0.12, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TabItemData {
  const _TabItemData({
    required this.route,
    required this.label,
    required this.defaultAsset,
  });

  final String route;
  final String label;
  final String defaultAsset;
}
