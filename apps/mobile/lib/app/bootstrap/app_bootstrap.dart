import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/core/services/app_provider_observer.dart';

typedef AppBuilder = Widget Function();

abstract final class AppBootstrap {
  static void run(AppBuilder builder) {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };

    runZonedGuarded<void>(
      () {
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
