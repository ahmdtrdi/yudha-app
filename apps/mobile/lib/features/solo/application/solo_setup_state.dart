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
    this.mechanicMode = SoloMechanicMode.focus,
    this.recommendationId,
    this.legacyTopic,
    this.characterId,
  });

  final SoloSetupMode? mode;
  final SoloMechanicMode mechanicMode;
  final String? recommendationId;
  final SoloLegacyTopicSelection? legacyTopic;
  final String? characterId;

  bool get usesUnavailableRecommendation =>
      mode == SoloSetupMode.auto || mode == SoloSetupMode.recommended;

  bool get canOpenLoadout =>
      mode == SoloSetupMode.balanced ||
      (mode == SoloSetupMode.custom && legacyTopic != null);

  SoloSetupState copyWith({
    SoloSetupMode? mode,
    SoloMechanicMode? mechanicMode,
    String? recommendationId,
    SoloLegacyTopicSelection? legacyTopic,
    String? characterId,
    bool clearMode = false,
    bool clearRecommendation = false,
    bool clearLegacyTopic = false,
  }) {
    return SoloSetupState(
      mode: clearMode ? null : mode ?? this.mode,
      mechanicMode: mechanicMode ?? this.mechanicMode,
      recommendationId: clearRecommendation
          ? null
          : recommendationId ?? this.recommendationId,
      legacyTopic: clearLegacyTopic ? null : legacyTopic ?? this.legacyTopic,
      characterId: characterId ?? this.characterId,
    );
  }
}
