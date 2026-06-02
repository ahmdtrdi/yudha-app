export class SubmitInterviewTurnDto {
  idempotencyKey: string;
  answer: {
    type: string;
    text: string;
  };
}
