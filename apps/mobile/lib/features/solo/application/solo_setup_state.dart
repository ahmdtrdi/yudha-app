import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

enum SoloSetupMode { auto, balanced, recommended, custom }

class SoloLegacyTopicSelection {
  const SoloLegacyTopicSelection({
    required this.id,
    required this.category,
    required this.name,
    this.subcategory,
  });

  final String id;
  final String category;
  final String? subcategory;
  final String name;
}

class SoloSetupState {
  const SoloSetupState({
    this.mode,
    this.mechanicMode,
    this.questionCount,
    this.recommendationId,
    this.legacyTopic,
    this.characterId,
  });

  final SoloSetupMode? mode;
  final SoloMechanicMode? mechanicMode;
  final SoloQuestionCount? questionCount;
  final String? recommendationId;
  final SoloLegacyTopicSelection? legacyTopic;
  final String? characterId;

  bool get usesUnavailableRecommendation =>
      mode == SoloSetupMode.auto || mode == SoloSetupMode.recommended;

  bool get canOpenLoadout =>
      mode == SoloSetupMode.balanced &&
      mechanicMode == SoloMechanicMode.standard &&
      questionCount != null;

  SoloSetupState copyWith({
    SoloSetupMode? mode,
    SoloMechanicMode? mechanicMode,
    SoloQuestionCount? questionCount,
    String? recommendationId,
    SoloLegacyTopicSelection? legacyTopic,
    String? characterId,
    bool clearMode = false,
    bool clearRecommendation = false,
    bool clearLegacyTopic = false,
    bool clearMechanic = false,
    bool clearQuestionCount = false,
  }) {
    return SoloSetupState(
      mode: clearMode ? null : mode ?? this.mode,
      mechanicMode: clearMechanic ? null : mechanicMode ?? this.mechanicMode,
      questionCount: clearQuestionCount
          ? null
          : questionCount ?? this.questionCount,
      recommendationId: clearRecommendation
          ? null
          : recommendationId ?? this.recommendationId,
      legacyTopic: clearLegacyTopic ? null : legacyTopic ?? this.legacyTopic,
      characterId: characterId ?? this.characterId,
    );
  }
}
