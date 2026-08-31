import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_controller.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_state.dart';

final AutoDisposeStateNotifierProvider<SoloSetupController, SoloSetupState>
soloSetupControllerProvider =
    StateNotifierProvider.autoDispose<SoloSetupController, SoloSetupState>(
      (Ref ref) => SoloSetupController(),
    );
