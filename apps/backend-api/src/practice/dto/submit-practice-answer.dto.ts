export class SubmitPracticeAnswerDto {
  sessionQuestionId: string;
  selectedOptionIndex: number;
  responseTimeMs?: number;
  usedHint?: boolean;
}
