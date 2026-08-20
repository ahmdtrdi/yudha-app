import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/app/router/app_router.dart';
import 'package:yudha_mobile/core/theme/app_theme.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/pass/application/hired_pass_providers.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> with WidgetsBindingObserver {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthenticated = ref.watch(isAuthenticatedProvider);
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

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
