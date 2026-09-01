import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_state.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

class SoloSetupController extends StateNotifier<SoloSetupState> {
  SoloSetupController() : super(const SoloSetupState());

  void selectMode(SoloSetupMode mode) {
    state = state.copyWith(
      mode: mode,
      clearRecommendation: mode != SoloSetupMode.auto,
      clearLegacyTopic: mode != SoloSetupMode.custom,
      clearMechanic: mode == SoloSetupMode.auto,
      clearQuestionCount: mode == SoloSetupMode.auto,
    );
  }

  void selectLegacyTopic(PracticeTopic topic) {
    state = state.copyWith(
      mode: SoloSetupMode.custom,
      legacyTopic: SoloLegacyTopicSelection(
        id: topic.id,
        category: topic.category,
        subcategory: topic.subcategory,
        name: topic.name,
      ),
      clearRecommendation: true,
    );
  }

  void selectMechanic(SoloMechanicMode mechanicMode) {
    state = state.copyWith(
      mechanicMode: mechanicMode,
      clearMode: state.mode == SoloSetupMode.auto,
      clearRecommendation: state.mode == SoloSetupMode.auto,
    );
  }

  void selectQuestionCount(SoloQuestionCount questionCount) {
    state = state.copyWith(
      questionCount: questionCount,
      clearMode: state.mode == SoloSetupMode.auto,
      clearRecommendation: state.mode == SoloSetupMode.auto,
    );
  }

  void selectCharacter(String characterId) {
    state = state.copyWith(characterId: characterId);
  }

  void reset() {
    state = const SoloSetupState();
  }
}
