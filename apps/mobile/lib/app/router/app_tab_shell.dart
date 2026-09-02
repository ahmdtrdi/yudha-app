import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/pvp/application/battle_providers.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

class AppTabShell extends ConsumerStatefulWidget {
  const AppTabShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppTabShell> createState() => _AppTabShellState();
}

class _AppTabShellState extends ConsumerState<AppTabShell>
    with SingleTickerProviderStateMixin {
  final LayerLink _learningMenuLink = LayerLink();
  late final AnimationController _learningMenuController;

  static const List<_TabItemData> _tabs = <_TabItemData>[
    _TabItemData(
      route: AppRoutes.lobby,
      label: 'Lobby',
      asset: 'assets/icons/navigation/nav_lobby_default.svg',
    ),
    _TabItemData(
      route: AppRoutes.leaderboard,
      label: 'Leaderboard',
      asset: 'assets/icons/navigation/nav_rank_default.svg',
    ),
    _TabItemData.learning(),
    _TabItemData(
      route: AppRoutes.analytics,
      label: 'Analytics',
      icon: Icons.analytics_outlined,
    ),
    _TabItemData(
      route: AppRoutes.profile,
      label: 'Profile',
      asset: 'assets/icons/navigation/nav_profile_default.svg',
    ),
  ];

  bool _isLearningMenuOpen = false;
  bool _isLearningMenuMounted = false;

  @override
  void initState() {
    super.initState();
    _learningMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    )..addStatusListener(_handleLearningMenuStatus);
  }

  @override
  void dispose() {
    _learningMenuController
      ..removeStatusListener(_handleLearningMenuStatus)
      ..dispose();
    super.dispose();
  }

  void _handleLearningMenuStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed ||
        !_isLearningMenuMounted ||
        !mounted) {
      return;
    }
    setState(() => _isLearningMenuMounted = false);
  }

  @override
  void didUpdateWidget(covariant AppTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location && _isLearningMenuMounted) {
      unawaited(_closeLearningMenu());
    }
  }

  void _toggleLearningMenu() {
    if (_isLearningMenuOpen) {
      unawaited(_closeLearningMenu());
      return;
    }
    _openLearningMenu();
  }

  void _openLearningMenu() {
    if (_isLearningMenuOpen) return;
    setState(() {
      _isLearningMenuOpen = true;
      _isLearningMenuMounted = true;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _learningMenuController.value = 1;
    } else {
      unawaited(_learningMenuController.forward());
    }
  }

  Future<void> _closeLearningMenu() async {
    if (!_isLearningMenuMounted) return;
    if (_isLearningMenuOpen && mounted) {
      setState(() => _isLearningMenuOpen = false);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _learningMenuController.value = 0;
      return;
    }
    await _learningMenuController.reverse();
  }

  Future<void> _openLearningDestination(String route) async {
    await _closeLearningMenu();
    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final BattlePhase battlePhase = ref.watch(
      battleControllerProvider.select((state) => state.phase),
    );
    final bool hideNav =
        widget.location == AppRoutes.soloSession ||
        (widget.location.startsWith(AppRoutes.pvp) &&
            battlePhase != BattlePhase.preBattle);

    return PopScope(
      canPop: !_isLearningMenuMounted,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_closeLearningMenu());
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Scaffold(
            body: Stack(
              children: <Widget>[
                Positioned.fill(child: widget.child),
                if (_isLearningMenuMounted)
                  Positioned.fill(
                    child: ModalBarrier(
                      key: const ValueKey<String>('learning-menu-barrier'),
                      color: Colors.transparent,
                      dismissible: true,
                      onDismiss: () => unawaited(_closeLearningMenu()),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: hideNav ? null : _buildNavigationBackground(),
          ),
          if (!hideNav)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                type: MaterialType.transparency,
                child: _buildNavigationBar(),
              ),
            ),
          if (_isLearningMenuMounted)
            CompositedTransformFollower(
              link: _learningMenuLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topCenter,
              followerAnchor: Alignment.bottomCenter,
              offset: const Offset(0, -18),
              child: IgnorePointer(
                ignoring: !_isLearningMenuOpen,
                child: _LearningMenu(
                  animation: _learningMenuController,
                  onSelected: _openLearningDestination,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return SafeArea(
      minimum: EdgeInsets.only(bottom: kIsWeb ? 10 : 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: SizedBox(
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                top: 7,
                bottom: 5,
                child: DecoratedBox(
                  key: const ValueKey<String>('app-tab-clay-base'),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE1E7),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.warriorNavy.withValues(alpha: 0.1),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                top: 12,
                child: Container(
                  key: const ValueKey<String>('app-tab-capsule'),
                  clipBehavior: Clip.none,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE8EBEF)),
                  ),
                  child: Row(
                    children: _tabs
                        .map((tab) => Expanded(child: _buildTab(tab)))
                        .toList(growable: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBackground() {
    return ColoredBox(
      key: const ValueKey<String>('app-tab-background'),
      color: AppColors.scholarCream,
      child: SafeArea(
        minimum: EdgeInsets.only(bottom: kIsWeb ? 10 : 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: SizedBox(
            height: 80,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (_isLearningMenuMounted)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -96,
                    child: _LearningMenuGlow(
                      animation: _learningMenuController,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(_TabItemData tab) {
    final bool selected = tab.isLearning
        ? _isLearningMenuOpen || _isLearningRoute
        : _isRouteSelected(tab.route!);
    return Semantics(
      key: ValueKey<String>('app-tab-${tab.label}'),
      button: true,
      selected: selected,
      label: tab.label,
      child: Tooltip(
        message: tab.label,
        child: InkWell(
          onTap: tab.isLearning
              ? _toggleLearningMenu
              : () {
                  _closeLearningMenu();
                  context.go(tab.route!);
                },
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: <Widget>[
              if (selected && !tab.isLearning)
                Positioned.fill(
                  child: _ActiveTabIndicator(tabLabel: tab.label),
                ),
              Center(
                child: tab.isLearning
                    ? CompositedTransformTarget(
                        link: _learningMenuLink,
                        child: _LearningTabButton(
                          isSelected: selected,
                          expansion: _learningMenuController,
                        ),
                      )
                    : _TabIcon(tab: tab, selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isRouteSelected(String route) {
    if (route == AppRoutes.lobby) return widget.location == route;
    return widget.location.startsWith(route);
  }

  bool get _isLearningRoute =>
      widget.location.startsWith(AppRoutes.learning) ||
      widget.location.startsWith(AppRoutes.solo) ||
      widget.location.startsWith(AppRoutes.pvp) ||
      widget.location.startsWith(AppRoutes.interview);
}

class _LearningTabButton extends StatelessWidget {
  const _LearningTabButton({required this.isSelected, required this.expansion});

  final bool isSelected;
  final Animation<double> expansion;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: expansion,
      builder: (BuildContext context, Widget? child) {
        final double progress = Curves.easeOutCubic.transform(expansion.value);
        return Transform.translate(
          offset: const Offset(0, -14),
          child: Transform.scale(
            scale: 1 - (progress * 0.06),
            child: AnimatedContainer(
              key: const ValueKey<String>('learning-tab-button'),
              duration: const Duration(milliseconds: 180),
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0066DE)
                    : const Color(0xFFE4F5FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF83E7FF) : Colors.white,
                  width: 3,
                ),
                boxShadow: <BoxShadow>[
                  const BoxShadow(
                    color: Color(0xFFD1D8E2),
                    blurRadius: 0,
                    offset: Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(
                      0xFF0066DE,
                    ).withValues(alpha: 0.12 + progress * 0.18),
                    blurRadius: 14 + progress * 14,
                    spreadRadius: progress * 6,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: progress * math.pi / 8,
                child: Icon(
                  Icons.star_rounded,
                  size: 34,
                  color: isSelected ? Colors.white : const Color(0xFF0066DE),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.tab, required this.selected});

  final _TabItemData tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? const Color(0xFF0066DE)
        : const Color(0xFF6C89A5);
    if (tab.asset case final String asset) {
      return SvgPicture.asset(
        asset,
        width: 27,
        height: 27,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(tab.icon, size: 27, color: color);
  }
}

class _LearningMenu extends StatelessWidget {
  const _LearningMenu({required this.animation, required this.onSelected});

  final Animation<double> animation;
  final Future<void> Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('learning-menu'),
      width: 286,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _LearningMenuMotion(
                  animation: animation,
                  interval: const Interval(0.12, 1, curve: Curves.easeOutBack),
                  beginOffset: const Offset(92, 54),
                  child: _LearningMenuAction(
                    label: 'Solo',
                    asset: 'assets/icons/navigation/nav_practice_default.svg',
                    fillColor: const Color(0xFFEFFCFF),
                    iconColor: const Color(0xFF0066DE),
                    shadowColor: const Color(0xFF83E7FF),
                    onTap: () => unawaited(onSelected(AppRoutes.solo)),
                  ),
                ),
                const SizedBox(width: 78),
                _LearningMenuMotion(
                  animation: animation,
                  interval: const Interval(0.12, 1, curve: Curves.easeOutBack),
                  beginOffset: const Offset(-92, 54),
                  child: _LearningMenuAction(
                    label: 'Interview',
                    icon: Icons.smart_toy_outlined,
                    fillColor: const Color(0xFFFFF0FA),
                    iconColor: const Color(0xFF9A3C7D),
                    shadowColor: const Color(0xFFF5B7E0),
                    onTap: () => unawaited(onSelected(AppRoutes.interview)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 18,
            child: _LearningMenuMotion(
              animation: animation,
              interval: const Interval(0, 0.82, curve: Curves.easeOutBack),
              beginOffset: const Offset(0, 50),
              child: _LearningMenuAction(
                label: 'PvP',
                asset: 'assets/icons/navigation/nav_pvp_default.svg',
                fillColor: const Color(0xFFFFF6ED),
                iconColor: const Color(0xFFD56A1B),
                shadowColor: const Color(0xFFFDAA55),
                onTap: () => unawaited(onSelected(AppRoutes.pvp)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningMenuMotion extends StatelessWidget {
  const _LearningMenuMotion({
    required this.animation,
    required this.interval,
    required this.beginOffset,
    required this.child,
  });

  final Animation<double> animation;
  final Curve interval;
  final Offset beginOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double progress = interval.transform(animation.value);
        return Opacity(
          opacity: progress.clamp(0, 1),
          child: Transform.translate(
            offset: Offset.lerp(beginOffset, Offset.zero, progress)!,
            child: Transform.scale(scale: 0.28 + progress * 0.72, child: child),
          ),
        );
      },
    );
  }
}

class _LearningMenuGlow extends StatelessWidget {
  const _LearningMenuGlow({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double progress = Curves.easeOut.transform(animation.value);
          return Opacity(
            opacity: progress,
            child: Transform.scale(scale: 0.72 + progress * 0.28, child: child),
          );
        },
        child: const Center(
          child: DecoratedBox(
            key: ValueKey<String>('learning-menu-shared-glow'),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 1.35),
                radius: 1.05,
                colors: <Color>[
                  Color(0xFFFFFFFF),
                  Color(0xE6FFFFFF),
                  Color(0x80FFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: <double>[0, 0.34, 0.68, 1],
              ),
            ),
            child: SizedBox(width: 270, height: 148),
          ),
        ),
      ),
    );
  }
}

class _LearningMenuAction extends StatelessWidget {
  const _LearningMenuAction({
    required this.label,
    required this.onTap,
    required this.fillColor,
    required this.iconColor,
    required this.shadowColor,
    this.asset,
    this.icon,
  }) : assert(asset != null || icon != null);

  final String label;
  final VoidCallback onTap;
  final Color fillColor;
  final Color iconColor;
  final Color shadowColor;
  final String? asset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey<String>('learning-menu-$label'),
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xFFD1D8E2),
                  blurRadius: 0,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Material(
            key: ValueKey<String>('learning-menu-surface-$label'),
            color: fillColor,
            shape: const CircleBorder(
              side: BorderSide(color: Colors.white, width: 2),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 0,
                      offset: Offset(0, 4),
                    ),
                    const BoxShadow(
                      color: Color(0x240066DE),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: asset == null
                    ? Icon(icon, size: 27, color: iconColor)
                    : SvgPicture.asset(
                        asset!,
                        width: 27,
                        height: 27,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
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
    this.asset,
    this.icon,
  }) : isLearning = false,
       assert(asset != null || icon != null);

  const _TabItemData.learning()
    : route = null,
      label = 'Learning',
      asset = null,
      icon = null,
      isLearning = true;

  final String? route;
  final String label;
  final String? asset;
  final IconData? icon;
  final bool isLearning;
}
