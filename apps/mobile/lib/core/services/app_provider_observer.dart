import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (previousValue == newValue) {
      return;
    }

    log(
      'Provider updated: ${provider.name ?? provider.runtimeType}',
      name: 'RiverpodObserver',
    );
  }
}
