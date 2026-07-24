import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';

String splashDestination({required bool isAuthenticated}) {
  return isAuthenticated ? AppRoutes.lobby : AppRoutes.login;
}

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  static const Duration _minimumDisplayTime = Duration(milliseconds: 300);
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(_minimumDisplayTime, () {
      if (!mounted) {
        return;
      }
      final bool isAuthenticated = ref.read(isAuthenticatedProvider);

      context.go(splashDestination(isAuthenticated: isAuthenticated));
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.splashBlue,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/branding/app-icon-new.png',
                      width: 220,
                      height: 220,
                      cacheWidth: 660,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Menyiapkan arena belajarmu...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(210),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
}
