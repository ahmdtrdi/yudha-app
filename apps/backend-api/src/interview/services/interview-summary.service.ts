import { ConflictException, Injectable } from '@nestjs/common';
import {
  InterviewDimensions,
  InterviewEvaluation,
  InterviewFinalSummary,
} from '../interview.types';

const dimensionNames: (keyof InterviewDimensions)[] = [
  'relevance',
  'clarity',
  'structure',
  'confidence',
  'impact',
  'authenticity',
];

@Injectable()
export class InterviewSummaryService {
  appendRollingSummary(
    summary: string,
    evaluation: InterviewEvaluation,
  ): string {
    const line = [
      `Score ${evaluation.overallScore}.`,
      `Candidate facts: ${evaluation.candidateFacts.join('; ') || 'none'}.`,
      `Strengths: ${evaluation.strengths.join('; ')}.`,
      `Improve: ${evaluation.improvements.join('; ')}.`,
    ].join(' ');

    return [summary, line].filter(Boolean).join('\n').slice(-1600);
  }

  buildFinalSummary(evaluations: InterviewEvaluation[]): InterviewFinalSummary {
    if (evaluations.length === 0) {
      throw new ConflictException(
        'Submit at least one interview answer before completing the session.',
      );
    }

    const dimensions = Object.fromEntries(
      dimensionNames.map((dimension) => [
        dimension,
        this.average(
          evaluations.map((evaluation) => evaluation.dimensions[dimension]),
        ),
      ]),
    ) as unknown as InterviewDimensions;

    return {
      overallScore: this.average(
        evaluations.map((evaluation) => evaluation.overallScore),
      ),
      dimensions,
      strengths: this.uniqueItems(
        evaluations.flatMap((evaluation) => evaluation.strengths),
      ),
      improvements: this.uniqueItems(
        evaluations.flatMap((evaluation) => evaluation.improvements),
      ),
      answerCount: evaluations.length,
    };
  }

  private uniqueItems(items: string[]): string[] {
    return [...new Set(items)].slice(0, 5);
  }

  private average(values: number[]): number {
    return Math.round(
      values.reduce((total, value) => total + value, 0) / values.length,
    );
  }
}
