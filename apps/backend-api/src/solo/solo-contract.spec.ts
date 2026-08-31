import {
  describeLegacyPracticeCompatibility,
  isSoloMechanicMode,
  isSoloQuestionSelectionType,
  parseSoloDraftSessionRequest,
  SoloContractValidationError,
} from './solo-contract';

describe('Solo draft compatibility contract', () => {
  it('accepts canonical balanced, recommended, and custom configurations', () => {
    expect(
      parseSoloDraftSessionRequest({
        idempotencyKey: 'solo-balanced-1',
        mechanicMode: 'focus',
        questionSelection: { type: 'balanced' },
      }),
    ).toEqual({
      idempotencyKey: 'solo-balanced-1',
      mechanicMode: 'focus',
      questionSelection: { type: 'balanced' },
    });

    expect(
      parseSoloDraftSessionRequest({
        idempotencyKey: 'solo-recommended-1',
        mechanicMode: 'standard',
        questionSelection: { type: 'recommended' },
        recommendationId: 'rec-1',
      }),
    ).toMatchObject({
      mechanicMode: 'standard',
      questionSelection: { type: 'recommended' },
      recommendationId: 'rec-1',
    });

    expect(
      parseSoloDraftSessionRequest({
        idempotencyKey: 'solo-custom-1',
        mechanicMode: 'speed',
        questionSelection: {
          type: 'custom',
          skillIds: ['cpns.tiu.numerik.percentage-increase'],
        },
      }),
    ).toMatchObject({
      mechanicMode: 'speed',
      questionSelection: {
        type: 'custom',
        skillIds: ['cpns.tiu.numerik.percentage-increase'],
      },
    });
  });

  it.each([
    [{ mechanicMode: 'calm' }, 'mechanicMode'],
    [{ questionSelection: { type: 'weak_topics' } }, 'questionSelection.type'],
    [
      { questionSelection: { type: 'custom', skillIds: [] } },
      'questionSelection.skillIds',
    ],
    [
      {
        questionSelection: {
          type: 'custom',
          skillIds: ['skill-1', 'skill-1'],
        },
      },
      'questionSelection.skillIds',
    ],
  ])('rejects invalid draft input %p', (override, expectedField) => {
    const request = {
      idempotencyKey: 'solo-1',
      mechanicMode: 'focus',
      questionSelection: { type: 'balanced' },
      ...override,
    };

    expectInvalidField(
      () => parseSoloDraftSessionRequest(request),
      expectedField,
    );
  });

  it('requires recommendation identity only for recommended selection', () => {
    expectInvalidField(
      () =>
        parseSoloDraftSessionRequest({
          idempotencyKey: 'solo-1',
          mechanicMode: 'focus',
          questionSelection: { type: 'recommended' },
        }),
      'recommendationId',
    );

    expectInvalidField(
      () =>
        parseSoloDraftSessionRequest({
          idempotencyKey: 'solo-1',
          mechanicMode: 'focus',
          questionSelection: { type: 'balanced' },
          recommendationId: 'rec-1',
        }),
      'recommendationId',
    );
  });

  it('describes legacy Practice without fabricating V2 configuration', () => {
    expect(
      describeLegacyPracticeCompatibility({
        category: ' tiu ',
        subcategory: 'numerik',
      }),
    ).toMatchObject({
      canonicalActivity: 'solo',
      source: 'practice',
      evidenceFidelity: 'legacy',
      legacyFilter: { category: 'tiu', subcategory: 'numerik' },
      effectiveMechanicMode: null,
      effectiveQuestionSelection: null,
    });
  });

  it('recognizes only the proposed public enum values', () => {
    expect(['focus', 'standard', 'speed'].every(isSoloMechanicMode)).toBe(true);
    expect(isSoloMechanicMode('untimed')).toBe(false);
    expect(
      ['balanced', 'recommended', 'custom'].every(isSoloQuestionSelectionType),
    ).toBe(true);
    expect(isSoloQuestionSelectionType('auto')).toBe(false);
  });
});

function expectInvalidField(operation: () => unknown, field: string): void {
  try {
    operation();
    throw new Error(`Expected Solo contract validation to reject ${field}.`);
  } catch (error: unknown) {
    expect(error).toBeInstanceOf(SoloContractValidationError);
    if (!(error instanceof SoloContractValidationError)) {
      return;
    }
    expect(error.code).toBe('SOLO_CONFIGURATION_INVALID');
    expect(error.field).toBe(field);
  }
}
