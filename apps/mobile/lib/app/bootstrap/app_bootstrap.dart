import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/core/services/app_provider_observer.dart';

typedef AppBuilder = Widget Function();

abstract final class AppBootstrap {
  static void run(AppBuilder builder) {
    runZonedGuarded<Future<void>>(
      () async {
        WidgetsFlutterBinding.ensureInitialized();

        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          Zone.current.handleUncaughtError(
            details.exception,
            details.stack ?? StackTrace.current,
          );
        };

        if (AppConfig.hasSupabaseConfig) {
          await Supabase.initialize(
            url: AppConfig.supabaseUrl,
            publishableKey: AppConfig.supabasePublishableKey,
          );
        } else {
          log(
            'Supabase config is missing. Auth-backed features are disabled.',
            name: 'AppBootstrap',
          );
        }

        runApp(
          ProviderScope(
            observers: <ProviderObserver>[AppProviderObserver()],
            child: builder(),
          ),
        );
      },
      (Object error, StackTrace stackTrace) {
        log(
          'Uncaught app error',
          name: 'AppBootstrap',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }
}
