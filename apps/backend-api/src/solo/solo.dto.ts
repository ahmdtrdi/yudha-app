export class CreateSoloSessionDto {
  idempotencyKey: string;
  mechanicMode: string;
  questionCount: number;
  questionSelection: unknown;
  recommendationId?: string;
  characterId: string;
}

export class SubmitSoloAnswerDto {
  idempotencyKey: string;
  sessionQuestionId: string;
  selectedOptionIndex?: number | null;
  usedHint?: boolean;
}

export class OpenSoloQuestionDto {
  idempotencyKey: string;
}

export class FinishSoloSessionDto {
  idempotencyKey: string;
}
