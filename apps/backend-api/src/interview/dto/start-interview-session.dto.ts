export class StartInterviewSessionDto {
  idempotencyKey: string;
  mode: string;
  targetRole: string;
  companyId: string;
  language?: string;
  responseStyle?: string;
}
