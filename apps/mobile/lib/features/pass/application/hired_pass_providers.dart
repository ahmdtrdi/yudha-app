import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/pass/data/repositories/hired_pass_repository.dart';
import 'package:yudha_mobile/features/pass/domain/entities/hired_pass_status.dart';

final Provider<HiredPassRepository> hiredPassRepositoryProvider =
    Provider<HiredPassRepository>((Ref ref) {
      final HiredPassRepository repository = HiredPassRepository(
        accessToken: ref.watch(authAccessTokenProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

final FutureProvider<HiredPassStatus> hiredPassStatusProvider =
    FutureProvider<HiredPassStatus>((Ref ref) {
      return ref.watch(hiredPassRepositoryProvider).fetchStatus();
    });
