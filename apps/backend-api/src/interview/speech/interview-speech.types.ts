export interface UploadedAudioFile {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
  size: number;
}

export interface InterviewSpeechTranscriptionInput {
  audio: Buffer;
  fileName: string;
  mimeType: string;
  language?: string;
  prompt?: string;
}

export interface InterviewSpeechTranscription {
  text: string;
  language: string | null;
  durationSeconds: number | null;
  provider: string;
}

export interface InterviewSpeechSynthesisInput {
  text: string;
  language?: string;
}

export interface InterviewSpeechSynthesisResult {
  audio: Buffer;
  contentType: string;
  fileExtension: string;
  provider: string;
}

export interface InterviewSpeechTranscriptionClient {
  transcribe(
    input: InterviewSpeechTranscriptionInput,
  ): Promise<InterviewSpeechTranscription>;
}

export interface InterviewSpeechSynthesisClient {
  synthesize(
    input: InterviewSpeechSynthesisInput,
  ): Promise<InterviewSpeechSynthesisResult>;
}
