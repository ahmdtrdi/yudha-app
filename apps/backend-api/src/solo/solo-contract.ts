import {
  SOLO_MECHANIC_MODES,
  SOLO_QUESTION_SELECTION_TYPES,
  type LegacyPracticeCompatibility,
  type SoloContractErrorCode,
  type SoloDraftSessionRequest,
  type SoloMechanicMode,
  type SoloQuestionSelection,
  type SoloQuestionSelectionType,
} from './solo-contract.types';

const MAX_CONTRACT_TEXT_LENGTH = 160;

export class SoloContractValidationError extends Error {
  readonly code: SoloContractErrorCode = 'SOLO_CONFIGURATION_INVALID';

  constructor(
    readonly field: string,
    message: string,
  ) {
    super(message);
    this.name = 'SoloContractValidationError';
  }
}

export function parseSoloDraftSessionRequest(
  input: unknown,
): SoloDraftSessionRequest {
  const request = requireRecord(input, 'request');
  rejectUnknownKeys(request, 'request', [
    'idempotencyKey',
    'mechanicMode',
    'questionSelection',
    'recommendationId',
  ]);

  const idempotencyKey = requireText(request.idempotencyKey, 'idempotencyKey');
  const mechanicMode = requireEnum(
    request.mechanicMode,
    'mechanicMode',
    SOLO_MECHANIC_MODES,
  );
  const questionSelection = parseQuestionSelection(request.questionSelection);
  const recommendationId = optionalText(
    request.recommendationId,
    'recommendationId',
  );

  if (questionSelection.type === 'recommended' && !recommendationId) {
    throw invalid(
      'recommendationId',
      'recommendationId is required for recommended question selection.',
    );
  }
  if (questionSelection.type !== 'recommended' && recommendationId) {
    throw invalid(
      'recommendationId',
      'recommendationId is only allowed for recommended question selection.',
    );
  }

  return {
    idempotencyKey,
    mechanicMode,
    questionSelection,
    ...(recommendationId ? { recommendationId } : {}),
  };
}

export function describeLegacyPracticeCompatibility(input: {
  category?: string | null;
  subcategory?: string | null;
}): LegacyPracticeCompatibility {
  const category = normalizeLegacyText(input.category);
  const subcategory = normalizeLegacyText(input.subcategory);

  return {
    canonicalActivity: 'solo',
    source: 'practice',
    evidenceFidelity: 'legacy',
    legacyFilter: { category, subcategory },
    effectiveMechanicMode: null,
    effectiveQuestionSelection: null,
    limitations: [
      'Legacy Practice does not prove a V2 mechanic.',
      'Legacy category filters do not prove a V2 question-selection strategy.',
      'Legacy attempts must not fabricate V2 timing or evidence fields.',
    ],
  };
}

function parseQuestionSelection(input: unknown): SoloQuestionSelection {
  const selection = requireRecord(input, 'questionSelection');
  const type = requireEnum(
    selection.type,
    'questionSelection.type',
    SOLO_QUESTION_SELECTION_TYPES,
  );

  if (type === 'custom') {
    rejectUnknownKeys(selection, 'questionSelection', ['type', 'skillIds']);
    return {
      type,
      skillIds: requireUniqueTextList(
        selection.skillIds,
        'questionSelection.skillIds',
      ),
    };
  }

  rejectUnknownKeys(selection, 'questionSelection', ['type']);
  return { type };
}

function requireRecord(value: unknown, field: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw invalid(field, `${field} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function requireEnum<T extends string>(
  value: unknown,
  field: string,
  allowed: readonly T[],
): T {
  if (typeof value !== 'string' || !allowed.includes(value as T)) {
    throw invalid(field, `${field} must be one of: ${allowed.join(', ')}.`);
  }
  return value as T;
}

function requireText(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw invalid(field, `${field} must be a non-empty string.`);
  }
  const normalized = value.trim();
  if (normalized.length > MAX_CONTRACT_TEXT_LENGTH) {
    throw invalid(
      field,
      `${field} must not exceed ${MAX_CONTRACT_TEXT_LENGTH} characters.`,
    );
  }
  return normalized;
}

function optionalText(value: unknown, field: string): string | undefined {
  return value === undefined || value === null
    ? undefined
    : requireText(value, field);
}

function requireUniqueTextList(value: unknown, field: string): string[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw invalid(field, `${field} must contain at least one skill ID.`);
  }
  const values = value.map((item, index) =>
    requireText(item, `${field}[${index}]`),
  );
  if (new Set(values).size !== values.length) {
    throw invalid(field, `${field} must not contain duplicate skill IDs.`);
  }
  return values;
}

function rejectUnknownKeys(
  value: Record<string, unknown>,
  field: string,
  allowedKeys: readonly string[],
): void {
  const unknownKey = Object.keys(value).find(
    (key) => !allowedKeys.includes(key),
  );
  if (unknownKey) {
    throw invalid(
      `${field}.${unknownKey}`,
      `${field} contains an unknown field.`,
    );
  }
}

function normalizeLegacyText(value: string | null | undefined): string | null {
  const normalized = value?.trim();
  return normalized ? normalized : null;
}

function invalid(field: string, message: string): SoloContractValidationError {
  return new SoloContractValidationError(field, message);
}

export function isSoloMechanicMode(value: unknown): value is SoloMechanicMode {
  return (
    typeof value === 'string' &&
    SOLO_MECHANIC_MODES.includes(value as SoloMechanicMode)
  );
}

export function isSoloQuestionSelectionType(
  value: unknown,
): value is SoloQuestionSelectionType {
  return (
    typeof value === 'string' &&
    SOLO_QUESTION_SELECTION_TYPES.includes(value as SoloQuestionSelectionType)
  );
}
