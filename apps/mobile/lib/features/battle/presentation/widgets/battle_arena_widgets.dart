import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';

abstract final class BattleClayPalette {
  static const Color navy = Color(0xFF0D2A52);
  static const Color navyEdge = Color(0xFF061A34);
  static const Color arenaFrame = Color(0xFF244963);
  static const Color cream = Color(0xFFFFF8EC);
  static const Color neutralEdge = Color(0xFFD5D0C5);
  static const Color ink = Color(0xFF17233F);
  static const Color mutedInk = Color(0xFF66708A);
  static const Color player = Color(0xFF2878F0);
  static const Color rival = Color(0xFFF05E5E);
}

enum BattleCharacterPose { idle, ready, attack, hit }

class BattleArenaFrame extends StatelessWidget {
  const BattleArenaFrame({
    required this.arenaAsset,
    required this.foregroundBuilder,
    this.arenaKey = const ValueKey<String>('battle-arena-board'),
    this.backgroundKey = const ValueKey<String>('battle-arena-background'),
    super.key,
  });

  final String arenaAsset;
  final Key arenaKey;
  final Key backgroundKey;
  final Widget Function(BuildContext, BoxConstraints) foregroundBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: arenaKey,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: BattleClayPalette.arenaFrame,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(52), width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: BattleClayPalette.navyEdge,
            blurRadius: 0,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.asset(
                  arenaAsset,
                  key: backgroundKey,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cacheWidth: 1024,
                  filterQuality: FilterQuality.medium,
                ),
                foregroundBuilder(context, constraints),
              ],
            );
          },
        ),
      ),
    );
  }
}

class BattleChampionStand extends StatelessWidget {
  const BattleChampionStand({
    required this.character,
    required this.pose,
    required this.accent,
    required this.destroyed,
    required this.ambientAnimation,
    this.semanticKey,
    super.key,
  });

  final CharacterVisualAssets character;
  final BattleCharacterPose pose;
  final Color accent;
  final bool destroyed;
  final Animation<double> ambientAnimation;
  final Key? semanticKey;

  @override
  Widget build(BuildContext context) {
    final Widget stand = Stack(
      key: semanticKey,
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 30,
          right: 30,
          bottom: 27,
          height: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(62),
              borderRadius: const BorderRadius.all(Radius.elliptical(60, 14)),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x3317233F), blurRadius: 7),
              ],
            ),
          ),
        ),
        Positioned(
          top: -4,
          left: 4,
          right: 4,
          bottom: 21,
          child: _BattleArenaHeroAsset(
            character: character,
            pose: pose,
            ambientAnimation: ambientAnimation,
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 0,
          height: 39,
          child: RepaintBoundary(
            child: CustomPaint(painter: _ChampionPodiumPainter(accent)),
          ),
        ),
        Positioned(
          bottom: 5,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(color: accent.withAlpha(90), blurRadius: 6),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 11,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );

    return AnimatedOpacity(
      opacity: destroyed ? 0.46 : 1,
      duration: const Duration(milliseconds: 240),
      child: ColorFiltered(
        colorFilter: destroyed
            ? const ColorFilter.matrix(<double>[
                0.32,
                0.32,
                0.32,
                0,
                0,
                0.32,
                0.32,
                0.32,
                0,
                0,
                0.32,
                0.32,
                0.32,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ])
            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: stand,
      ),
    );
  }
}

class _BattleArenaHeroAsset extends StatelessWidget {
  const _BattleArenaHeroAsset({
    required this.character,
    required this.pose,
    required this.ambientAnimation,
  });

  final CharacterVisualAssets character;
  final BattleCharacterPose pose;
  final Animation<double> ambientAnimation;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final String asset = switch (pose) {
      BattleCharacterPose.idle => character.idle,
      BattleCharacterPose.ready => character.ready,
      BattleCharacterPose.attack => character.attack,
      BattleCharacterPose.hit => character.hit,
    };
    return AnimatedBuilder(
      animation: ambientAnimation,
      builder: (BuildContext context, Widget? child) {
        final double wave = reduceMotion
            ? 0
            : math.sin(ambientAnimation.value * math.pi * 2);
        return Transform.translate(
          offset: Offset(0, wave * 1.8),
          child: Transform.rotate(angle: wave * 0.01, child: child),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 90),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Image.asset(
          asset,
          key: ValueKey<String>(asset),
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          cacheWidth: 360,
          filterQuality: FilterQuality.low,
          semanticLabel: 'Karakter di arena dalam pose ${pose.name}',
        ),
      ),
    );
  }
}

class BattleTowerAsset extends StatelessWidget {
  const BattleTowerAsset({
    required this.activeAsset,
    required this.destroyedAsset,
    required this.destroyed,
    required this.ambientAnimation,
    this.semanticKey,
    super.key,
  });

  final String activeAsset;
  final String destroyedAsset;
  final bool destroyed;
  final Animation<double> ambientAnimation;
  final Key? semanticKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: semanticKey,
      animation: ambientAnimation,
      builder: (BuildContext context, Widget? child) {
        final double float = (ambientAnimation.value - 0.5) * 2;
        return Transform.translate(
          offset: Offset(0, destroyed ? 4 : float),
          child: AnimatedRotation(
            turns: destroyed ? 0.018 : 0,
            duration: const Duration(milliseconds: 260),
            child: AnimatedOpacity(
              opacity: destroyed ? 0.42 : 1,
              duration: const Duration(milliseconds: 220),
              child: ColorFiltered(
                colorFilter: destroyed
                    ? const ColorFilter.matrix(<double>[
                        0.32,
                        0.32,
                        0.32,
                        0,
                        0,
                        0.32,
                        0.32,
                        0.32,
                        0,
                        0,
                        0.32,
                        0.32,
                        0.32,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: child!,
              ),
            ),
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Image.asset(
          destroyed ? destroyedAsset : activeAsset,
          key: ValueKey<String>(destroyed ? destroyedAsset : activeAsset),
          fit: BoxFit.contain,
          cacheWidth: 420,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}

class BattleDeckPanel extends StatelessWidget {
  const BattleDeckPanel({
    required this.cards,
    required this.compact,
    this.panelKey = const ValueKey<String>('battle-deck-panel'),
    super.key,
  });

  final List<Widget> cards;
  final bool compact;
  final Key panelKey;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        key: panelKey,
        width: compact ? 238 : 276,
        height: compact ? 98 : 116,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFB8C0CC), width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x2B17233F),
              blurRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List<Widget>.generate(3, (int index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                child: index < cards.length
                    ? cards[index]
                    : const SizedBox.shrink(),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class BattleArenaCard extends StatefulWidget {
  const BattleArenaCard({
    required this.cardId,
    required this.asset,
    required this.accent,
    required this.compact,
    required this.enabled,
    required this.selected,
    required this.onTap,
    this.exhausted = false,
    this.onExhausted,
    this.badge,
    super.key,
  });

  final String cardId;
  final String asset;
  final Color accent;
  final bool compact;
  final bool enabled;
  final bool selected;
  final bool exhausted;
  final VoidCallback onTap;
  final VoidCallback? onExhausted;
  final Widget? badge;

  @override
  State<BattleArenaCard> createState() => _BattleArenaCardState();
}

class _BattleArenaCardState extends State<BattleArenaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.exhausted) {
      _shakeController.forward(from: 0);
      widget.onExhausted?.call();
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (BuildContext context, Widget? child) {
        final double progress = _shakeController.value;
        return Transform.translate(
          offset: Offset(
            math.sin(progress * math.pi * 8) * 6 * (1 - progress),
            0,
          ),
          child: child,
        );
      },
      child: AnimatedScale(
        scale: widget.selected ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: widget.exhausted
              ? 0.48
              : widget.enabled || widget.selected
              ? 1
              : 0.58,
          duration: const Duration(milliseconds: 140),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey<String>('question-card-${widget.cardId}'),
              onTap: widget.enabled ? _handleTap : null,
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                key: ValueKey<String>('question-card-surface-${widget.cardId}'),
                padding: EdgeInsets.all(widget.compact ? 1 : 2),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(
                      widget.asset,
                      fit: BoxFit.contain,
                      cacheWidth: 180,
                      filterQuality: FilterQuality.low,
                    ),
                    Positioned(
                      left: widget.compact ? 3 : 4,
                      bottom: widget.compact ? 3 : 4,
                      child: Container(
                        width: widget.compact ? 19 : 22,
                        height: widget.compact ? 19 : 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.exhausted
                              ? const Color(0xFF7D8490)
                              : widget.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child:
                            widget.badge ??
                            SvgPicture.asset(
                              'assets/icons/lobby_swords_watermark.svg',
                              width: widget.compact ? 14 : 16,
                              height: widget.compact ? 14 : 16,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BattleQuestionSheetFrame extends StatelessWidget {
  const BattleQuestionSheetFrame({
    required this.accent,
    required this.child,
    this.sheetKey,
    super.key,
  });

  final Color accent;
  final Widget child;
  final Key? sheetKey;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: sheetKey,
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: BattleClayPalette.cream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: accent.withAlpha(90), width: 2),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _ChampionPodiumPainter extends CustomPainter {
  const _ChampionPodiumPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..isAntiAlias = true;
    final Rect shadow = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.66,
      size.width * 0.84,
      size.height * 0.28,
    );
    paint.color = Colors.black.withAlpha(45);
    canvas.drawOval(shadow.shift(const Offset(0, 3)), paint);

    final Path front = Path()
      ..moveTo(size.width * 0.16, size.height * 0.34)
      ..lineTo(size.width * 0.84, size.height * 0.34)
      ..lineTo(size.width * 0.75, size.height * 0.88)
      ..lineTo(size.width * 0.25, size.height * 0.88)
      ..close();
    paint.color = Color.alphaBlend(
      accent.withAlpha(55),
      const Color(0xFFD9C6A4),
    );
    canvas.drawPath(front, paint);

    final Rect top = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.13,
      size.width * 0.76,
      size.height * 0.38,
    );
    paint.color = Color.alphaBlend(
      accent.withAlpha(38),
      const Color(0xFFF3E1BD),
    );
    canvas.drawOval(top, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.alphaBlend(
        accent.withAlpha(145),
        const Color(0xFF8E7658),
      );
    canvas.drawOval(top, paint);
  }

  @override
  bool shouldRepaint(covariant _ChampionPodiumPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}
