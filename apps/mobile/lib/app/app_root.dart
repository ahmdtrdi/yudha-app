import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/app/router/app_router.dart';
import 'package:yudha_mobile/core/theme/app_theme.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/notifications/application/daily_reminder_providers.dart';
import 'package:yudha_mobile/features/notifications/domain/daily_reminder_state.dart';
import 'package:yudha_mobile/features/pass/application/hired_pass_providers.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> with WidgetsBindingObserver {
  String? _recordedWebDeliveryId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(isAuthenticatedProvider)) {
      unawaited(ref.read(gameEconomyProvider.notifier).refresh());
      unawaited(ref.read(dailyReminderProvider.notifier).syncInstallation());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthenticated = ref.watch(isAuthenticatedProvider);
    ref.watch(dailyReminderProvider);
    ref.listen<bool>(isAuthenticatedProvider, (bool? previous, bool next) {
      if (previous == true && !next) {
        unawaited(ref.read(gameEconomyProvider.notifier).clearSession());
        ref.invalidate(hiredPassStatusProvider);
      }
    });
    if (isAuthenticated) {
      ref.watch(gameEconomyProvider);
      ref.watch(hiredPassStatusProvider);
    }
    final router = ref.watch(appRouterProvider);
    if (kIsWeb && isAuthenticated) {
      final deliveryId = Uri.base.queryParameters['notificationDeliveryId'];
      if (deliveryId != null && deliveryId != _recordedWebDeliveryId) {
        _recordedWebDeliveryId = deliveryId;
        scheduleMicrotask(
          () => ref.read(dailyReminderProvider.notifier).markOpened(deliveryId),
        );
      }
    }
    ref.listen<DailyReminderState>(dailyReminderProvider, (
      DailyReminderState? previous,
      DailyReminderState next,
    ) {
      final tap = next.pendingTap;
      if (tap == null || identical(tap, previous?.pendingTap)) return;
      scheduleMicrotask(() {
        router.go(tap.route);
        unawaited(
          ref.read(dailyReminderProvider.notifier).markOpened(tap.deliveryId),
        );
        ref.read(dailyReminderProvider.notifier).clearPendingTap();
      });
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();

        final Size screenSize = MediaQuery.sizeOf(context);
        // On actual mobile browser viewport, render full screen without container framing
        if (screenSize.width <= 480) {
          return child ?? const SizedBox.shrink();
        }

        // Modern standard phone frame (iPhone 15 Pro Max / Galaxy S24+)
        const double targetPhoneWidth = 412.0;
        const double targetPhoneHeight = 890.0;
        const Size targetPhoneSize = Size(targetPhoneWidth, targetPhoneHeight);

        return ColoredBox(
          color: const Color(0xFF070E18),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Container(
                  width: targetPhoneWidth,
                  height: targetPhoneHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(44),
                    border: Border.all(
                      color: const Color(0xFF223249),
                      width: 4,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 40,
                        spreadRadius: 2,
                        offset: const Offset(0, 16),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0D49B5).withValues(alpha: 0.2),
                        blurRadius: 60,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: targetPhoneSize,
                      ),
                      child: SizedBox(
                        width: targetPhoneWidth,
                        height: targetPhoneHeight,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
