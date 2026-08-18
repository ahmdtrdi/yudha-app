export class SubmitPracticeAnswerDto {
  idempotencyKey: string;
  sessionQuestionId: string;
  selectedOptionIndex: number;
  responseTimeMs?: number;
  usedHint: boolean;
}
