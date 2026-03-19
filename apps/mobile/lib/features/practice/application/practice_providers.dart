import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/practice/application/practice_controller.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/data/repositories/mock_practice_repository.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';

final Provider<PracticeRepository> practiceRepositoryProvider =
    Provider<PracticeRepository>((Ref ref) => const MockPracticeRepository());

final StateNotifierProvider<PracticeController, PracticeState>
practiceControllerProvider =
    StateNotifierProvider<PracticeController, PracticeState>(
      (Ref ref) =>
          PracticeController(repository: ref.watch(practiceRepositoryProvider)),
    );
