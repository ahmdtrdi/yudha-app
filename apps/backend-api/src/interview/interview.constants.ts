export const INTERVIEW_LLM_CLIENT = Symbol('INTERVIEW_LLM_CLIENT');

export const INTERVIEW_EVALUATION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: [
    'overallScore',
    'dimensions',
    'candidateFacts',
    'strengths',
    'improvements',
    'suggestedRewrite',
    'nextQuestion',
    'shouldEndSession',
    'endReason',
    'coachNote',
  ],
  properties: {
    overallScore: scoreSchema(),
    dimensions: {
      type: 'object',
      additionalProperties: false,
      required: [
        'relevance',
        'clarity',
        'structure',
        'confidence',
        'impact',
        'authenticity',
      ],
      properties: {
        relevance: scoreSchema(),
        clarity: scoreSchema(),
        structure: scoreSchema(),
        confidence: scoreSchema(),
        impact: scoreSchema(),
        authenticity: scoreSchema(),
      },
    },
    candidateFacts: {
      type: 'array',
      maxItems: 8,
      items: nonEmptyStringSchema(),
    },
    strengths: stringListSchema(),
    improvements: stringListSchema(),
    suggestedRewrite: nonEmptyStringSchema(),
    nextQuestion: nonEmptyStringSchema(),
    shouldEndSession: {
      type: 'boolean',
    },
    endReason: nullableStringSchema(),
    coachNote: nullableStringSchema(),
  },
} as const;

function scoreSchema() {
  return {
    type: 'integer',
    minimum: 0,
    maximum: 100,
  } as const;
}

function stringListSchema() {
  return {
    type: 'array',
    minItems: 1,
    maxItems: 5,
    items: nonEmptyStringSchema(),
  } as const;
}

function nonEmptyStringSchema() {
  return {
    type: 'string',
    minLength: 1,
  } as const;
}

function nullableStringSchema() {
  return {
    type: ['string', 'null'],
  } as const;
}
