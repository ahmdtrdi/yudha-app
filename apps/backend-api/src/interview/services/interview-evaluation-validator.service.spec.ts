import { ServiceUnavailableException } from '@nestjs/common';
import { InterviewEvaluationValidator } from './interview-evaluation-validator.service';

describe('InterviewEvaluationValidator', () => {
  const validator = new InterviewEvaluationValidator();

  it('accepts a complete interview evaluation', () => {
    const evaluation = {
      overallScore: 80,
      dimensions: {
        relevance: 80,
        clarity: 80,
        structure: 80,
        confidence: 80,
        impact: 80,
        authenticity: 80,
      },
      strengths: ['Relevant answer'],
      improvements: ['Add one measurable result'],
      suggestedRewrite: 'A stronger answer.',
      nextQuestion: 'What did you learn from the experience?',
      shouldEndSession: false,
    };

    expect(validator.parse(evaluation)).toEqual(evaluation);
  });

  it('rejects an out-of-range dimension score', () => {
    const evaluation = {
      overallScore: 80,
      dimensions: {
        relevance: 101,
        clarity: 80,
        structure: 80,
        confidence: 80,
        impact: 80,
        authenticity: 80,
      },
      strengths: ['Relevant answer'],
      improvements: ['Add one measurable result'],
      suggestedRewrite: 'A stronger answer.',
      nextQuestion: 'What did you learn from the experience?',
      shouldEndSession: false,
    };

    expect(() => validator.parse(evaluation)).toThrow(
      ServiceUnavailableException,
    );
  });
});
