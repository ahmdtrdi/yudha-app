import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';
import 'package:yudha_mobile/features/solo/application/solo_setup_state.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

class SoloSetupController extends StateNotifier<SoloSetupState> {
  SoloSetupController() : super(const SoloSetupState());

  void applyRecommendedPreset([LearningRecommendation? recommendation]) {
    if (recommendation != null) {
      final String topicLabel =
          recommendation.subcategory ??
          recommendation.category ??
          recommendation.skillLabel;
      state = SoloSetupState(
        mode: SoloSetupMode.recommended,
        mechanicMode: SoloMechanicMode.parse(recommendation.mechanicMode),
        questionCount: SoloQuestionCount.twenty,
        recommendationId: recommendation.id,
        legacyTopic: SoloLegacyTopicSelection(
          id: recommendation.skillId,
          category: recommendation.category ?? '',
          subcategory: recommendation.subcategory,
          name: '$topicLabel (Rekomendasi)',
        ),
      );
      return;
    }
    state = const SoloSetupState(
      mode: SoloSetupMode.auto,
      mechanicMode: SoloMechanicMode.standard,
      questionCount: SoloQuestionCount.twenty,
    );
  }

  void beginManualSetup() {
    state = const SoloSetupState();
  }

  void selectMode(SoloSetupMode mode) {
    state = state.copyWith(
      mode: mode,
      clearRecommendation: mode != SoloSetupMode.recommended,
      clearLegacyTopic: mode != SoloSetupMode.custom && mode != SoloSetupMode.recommended,
      mechanicMode: mode == SoloSetupMode.auto
          ? SoloMechanicMode.standard
          : state.mechanicMode ?? SoloMechanicMode.standard,
      questionCount: mode == SoloSetupMode.auto
          ? SoloQuestionCount.twenty
          : state.questionCount ?? SoloQuestionCount.twenty,
    );
  }

  void selectRecommendation(LearningRecommendation recommendation) {
    final String topicLabel =
        recommendation.subcategory ??
        recommendation.category ??
        recommendation.skillLabel;
    state = state.copyWith(
      mode: SoloSetupMode.recommended,
      recommendationId: recommendation.id,
      legacyTopic: SoloLegacyTopicSelection(
        id: recommendation.skillId,
        category: recommendation.category ?? '',
        subcategory: recommendation.subcategory,
        name: '$topicLabel (Rekomendasi)',
      ),
      clearRecommendation: false,
      clearLegacyTopic: false,
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
