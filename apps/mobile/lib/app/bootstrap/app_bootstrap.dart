import 'dart:async';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/auth/data/app_auth_storage.dart';
import 'package:yudha_mobile/firebase_options.dart';

typedef AppBuilder = Widget Function();

abstract final class AppBootstrap {
  static void run(AppBuilder builder) {
    runZonedGuarded<Future<void>>(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        _configureRendering();

        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          Zone.current.handleUncaughtError(
            details.exception,
            details.stack ?? StackTrace.current,
          );
        };

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        if (AppConfig.hasSupabaseConfig) {
          await Supabase.initialize(
            url: AppConfig.supabaseUrl,
            publishableKey: AppConfig.supabasePublishableKey,
            authOptions: FlutterAuthClientOptions(
              autoRefreshToken: true,
              localStorage: AppAuthStorage.instance,
            ),
          );
        } else {
          log(
            'Supabase config is missing. Auth-backed features are disabled.',
            name: 'AppBootstrap',
          );
        }

        runApp(ProviderScope(child: builder()));
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

  static void _configureRendering() {
    // Avoid layout shifts and network-dependent text rendering. All fonts used
    // by the app are bundled under assets/fonts.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Keep decoded gameplay images bounded on memory-constrained phones.
    final ImageCache imageCache = PaintingBinding.instance.imageCache;
    imageCache
      ..maximumSize = 160
      ..maximumSizeBytes = 64 << 20;

    // Let each screen's own background continue beneath the status bar/cutout.
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }
}
