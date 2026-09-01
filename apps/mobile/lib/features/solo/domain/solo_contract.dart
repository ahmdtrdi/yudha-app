enum SoloMechanicMode {
  focus('focus'),
  standard('standard'),
  speed('speed');

  const SoloMechanicMode(this.wireValue);

  final String wireValue;

  static SoloMechanicMode parse(Object? value) {
    return values.firstWhere(
      (SoloMechanicMode mode) => mode.wireValue == value,
      orElse: () => throw SoloContractException(
        field: 'mechanicMode',
        message: 'Unknown Solo mechanic mode: $value',
      ),
    );
  }
}

enum SoloQuestionSelectionType {
  balanced('balanced'),
  recommended('recommended'),
  custom('custom');

  const SoloQuestionSelectionType(this.wireValue);

  final String wireValue;

  static SoloQuestionSelectionType parse(Object? value) {
    return values.firstWhere(
      (SoloQuestionSelectionType type) => type.wireValue == value,
      orElse: () => throw SoloContractException(
        field: 'questionSelection.type',
        message: 'Unknown Solo question selection: $value',
      ),
    );
  }
}

enum SoloQuestionCount {
  twenty(20),
  thirtyFive(35),
  fifty(50);

  const SoloQuestionCount(this.value);

  final int value;

  static SoloQuestionCount parse(Object? value) {
    return values.firstWhere(
      (SoloQuestionCount count) => count.value == value,
      orElse: () => throw SoloContractException(
        field: 'questionCount',
        message: 'Unknown Solo question count: $value',
      ),
    );
  }
}

sealed class SoloQuestionSelection {
  const SoloQuestionSelection();

  SoloQuestionSelectionType get type;

  Map<String, Object> toJson();

  static SoloQuestionSelection fromJson(Object? value) {
    final Map<String, dynamic> json = _requireMap(value, 'questionSelection');
    final SoloQuestionSelectionType type = SoloQuestionSelectionType.parse(
      json['type'],
    );
    switch (type) {
      case SoloQuestionSelectionType.balanced:
        _rejectUnknownKeys(json, 'questionSelection', const <String>{'type'});
        return const SoloBalancedQuestionSelection();
      case SoloQuestionSelectionType.recommended:
        _rejectUnknownKeys(json, 'questionSelection', const <String>{'type'});
        return const SoloRecommendedQuestionSelection();
      case SoloQuestionSelectionType.custom:
        _rejectUnknownKeys(json, 'questionSelection', const <String>{
          'type',
          'skillIds',
        });
        return SoloCustomQuestionSelection(
          _requireUniqueTextList(
            json['skillIds'],
            'questionSelection.skillIds',
          ),
        );
    }
  }
}

final class SoloBalancedQuestionSelection extends SoloQuestionSelection {
  const SoloBalancedQuestionSelection();

  @override
  SoloQuestionSelectionType get type => SoloQuestionSelectionType.balanced;

  @override
  Map<String, Object> toJson() => <String, Object>{'type': type.wireValue};
}

final class SoloRecommendedQuestionSelection extends SoloQuestionSelection {
  const SoloRecommendedQuestionSelection();

  @override
  SoloQuestionSelectionType get type => SoloQuestionSelectionType.recommended;

  @override
  Map<String, Object> toJson() => <String, Object>{'type': type.wireValue};
}

final class SoloCustomQuestionSelection extends SoloQuestionSelection {
  SoloCustomQuestionSelection(List<String> skillIds)
    : skillIds = List<String>.unmodifiable(_validateSkillIds(skillIds));

  final List<String> skillIds;

  @override
  SoloQuestionSelectionType get type => SoloQuestionSelectionType.custom;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'type': type.wireValue,
    'skillIds': skillIds,
  };
}

class SoloSessionConfiguration {
  SoloSessionConfiguration({
    required this.mechanicMode,
    required this.questionCount,
    required this.questionSelection,
    String? recommendationId,
  }) : recommendationId = _validateRecommendationIdentity(
         questionSelection,
         recommendationId,
       );

  factory SoloSessionConfiguration.fromJson(Map<String, dynamic> json) {
    _rejectUnknownKeys(json, 'configuration', const <String>{
      'mechanicMode',
      'questionCount',
      'questionSelection',
      'recommendationId',
    });
    return SoloSessionConfiguration(
      mechanicMode: SoloMechanicMode.parse(json['mechanicMode']),
      questionCount: SoloQuestionCount.parse(json['questionCount']),
      questionSelection: SoloQuestionSelection.fromJson(
        json['questionSelection'],
      ),
      recommendationId: _optionalText(
        json['recommendationId'],
        'recommendationId',
      ),
    );
  }

  final SoloMechanicMode mechanicMode;
  final SoloQuestionCount questionCount;
  final SoloQuestionSelection questionSelection;
  final String? recommendationId;

  Map<String, Object> toJson() => <String, Object>{
    'mechanicMode': mechanicMode.wireValue,
    'questionCount': questionCount.value,
    'questionSelection': questionSelection.toJson(),
    'recommendationId': ?recommendationId,
  };
}

class SoloDraftSessionRequest {
  SoloDraftSessionRequest({
    required String idempotencyKey,
    required String characterId,
    required this.configuration,
  }) : idempotencyKey = _requireText(idempotencyKey, 'idempotencyKey'),
       characterId = _requireText(characterId, 'characterId');

  factory SoloDraftSessionRequest.fromJson(Map<String, dynamic> json) {
    _rejectUnknownKeys(json, 'request', const <String>{
      'idempotencyKey',
      'mechanicMode',
      'questionCount',
      'questionSelection',
      'recommendationId',
      'characterId',
    });
    return SoloDraftSessionRequest(
      idempotencyKey: _requireText(json['idempotencyKey'], 'idempotencyKey'),
      characterId: _requireText(json['characterId'], 'characterId'),
      configuration: SoloSessionConfiguration.fromJson(<String, dynamic>{
        'mechanicMode': json['mechanicMode'],
        'questionCount': json['questionCount'],
        'questionSelection': json['questionSelection'],
        if (json.containsKey('recommendationId'))
          'recommendationId': json['recommendationId'],
      }),
    );
  }

  final String idempotencyKey;
  final String characterId;
  final SoloSessionConfiguration configuration;

  Map<String, Object> toJson() => <String, Object>{
    'idempotencyKey': idempotencyKey,
    'characterId': characterId,
    ...configuration.toJson(),
  };
}

enum SoloCompatibilityWarningCode {
  speedBaselineUnavailable('speed_baseline_unavailable'),
  focusRecommendedBeforeSpeed('focus_recommended_before_speed'),
  recommendationUnavailable('recommendation_unavailable');

  const SoloCompatibilityWarningCode(this.wireValue);

  final String wireValue;
}

class SoloCompatibilityWarning {
  const SoloCompatibilityWarning({required this.code, required this.message});

  final SoloCompatibilityWarningCode code;
  final String message;
}

class SoloConfigurationResolution {
  const SoloConfigurationResolution({
    required this.requested,
    required this.effectiveMechanicMode,
    required this.effectiveQuestionSelection,
    required this.warnings,
    required this.operational,
  });

  final SoloSessionConfiguration requested;
  final SoloMechanicMode? effectiveMechanicMode;
  final SoloQuestionSelection? effectiveQuestionSelection;
  final List<SoloCompatibilityWarning> warnings;
  final bool operational;
}

class LegacyPracticeSoloCompatibility {
  LegacyPracticeSoloCompatibility({String? category, String? subcategory})
    : category = _normalizeLegacyText(category),
      subcategory = _normalizeLegacyText(subcategory);

  static const String canonicalActivity = 'solo';
  static const String source = 'practice';
  static const String evidenceFidelity = 'legacy';

  final String? category;
  final String? subcategory;

  SoloMechanicMode? get effectiveMechanicMode => null;
  SoloQuestionSelection? get effectiveQuestionSelection => null;

  List<String> get limitations => const <String>[
    'Legacy Practice does not prove a V2 mechanic.',
    'Legacy category filters do not prove a V2 question-selection strategy.',
    'Legacy attempts must not fabricate V2 timing or evidence fields.',
  ];
}

class SoloContractException implements Exception {
  const SoloContractException({required this.field, required this.message});

  static const String code = 'SOLO_CONFIGURATION_INVALID';

  final String field;
  final String message;

  @override
  String toString() => message;
}

const int _maxContractTextLength = 160;

Map<String, dynamic> _requireMap(Object? value, String field) {
  if (value is! Map<String, dynamic>) {
    throw SoloContractException(
      field: field,
      message: '$field must be an object.',
    );
  }
  return value;
}

String _requireText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw SoloContractException(
      field: field,
      message: '$field must be a non-empty string.',
    );
  }
  final String normalized = value.trim();
  if (normalized.length > _maxContractTextLength) {
    throw SoloContractException(
      field: field,
      message: '$field must not exceed $_maxContractTextLength characters.',
    );
  }
  return normalized;
}

String? _optionalText(Object? value, String field) {
  return value == null ? null : _requireText(value, field);
}

List<String> _requireUniqueTextList(Object? value, String field) {
  if (value is! List<dynamic> || value.isEmpty) {
    throw SoloContractException(
      field: field,
      message: '$field must contain at least one skill ID.',
    );
  }
  return _validateSkillIds(
    value
        .asMap()
        .entries
        .map(
          (MapEntry<int, dynamic> entry) =>
              _requireText(entry.value, '$field[${entry.key}]'),
        )
        .toList(growable: false),
  );
}

List<String> _validateSkillIds(List<String> values) {
  if (values.isEmpty) {
    throw const SoloContractException(
      field: 'questionSelection.skillIds',
      message: 'questionSelection.skillIds must contain at least one skill ID.',
    );
  }
  final List<String> normalized = values
      .asMap()
      .entries
      .map(
        (MapEntry<int, String> entry) => _requireText(
          entry.value,
          'questionSelection.skillIds[${entry.key}]',
        ),
      )
      .toList(growable: false);
  if (normalized.toSet().length != normalized.length) {
    throw const SoloContractException(
      field: 'questionSelection.skillIds',
      message: 'questionSelection.skillIds must not contain duplicates.',
    );
  }
  return normalized;
}

String? _validateRecommendationIdentity(
  SoloQuestionSelection selection,
  String? recommendationId,
) {
  final String? normalized = _optionalText(
    recommendationId,
    'recommendationId',
  );
  if (selection.type == SoloQuestionSelectionType.recommended &&
      normalized == null) {
    throw const SoloContractException(
      field: 'recommendationId',
      message:
          'recommendationId is required for recommended question selection.',
    );
  }
  if (selection.type != SoloQuestionSelectionType.recommended &&
      normalized != null) {
    throw const SoloContractException(
      field: 'recommendationId',
      message:
          'recommendationId is only allowed for recommended question selection.',
    );
  }
  return normalized;
}

void _rejectUnknownKeys(
  Map<String, dynamic> value,
  String field,
  Set<String> allowedKeys,
) {
  for (final String key in value.keys) {
    if (!allowedKeys.contains(key)) {
      throw SoloContractException(
        field: '$field.$key',
        message: '$field contains an unknown field.',
      );
    }
  }
}

String? _normalizeLegacyText(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
