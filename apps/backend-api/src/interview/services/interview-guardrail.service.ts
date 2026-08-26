import { Injectable, Logger } from '@nestjs/common';

export interface GuardrailCheckResult {
  isAllowed: boolean;
  category?: 'sara' | 'explicit' | 'profanity' | 'prompt_injection';
  reason?: string;
  matchedTerm?: string;
}

@Injectable()
export class InterviewGuardrailService {
  private readonly logger = new Logger(InterviewGuardrailService.name);

  // Category 1: SARA, Hate Speech, Discrimination
  private readonly saraPatterns: RegExp[] = [
    /\b(pribumi|cina|cino|kafir|chindo|kristenis|islamis|rasis|rasisme)\b/i,
    /\b(benci|hina|musnahkan)\s+(suku|ras|agama|antargolongan)\b/i,
  ];

  // Category 2: Explicit / Sexual Content
  private readonly explicitPatterns: RegExp[] = [
    /\b(seks|sex|porno|pornography|kontol|memek|pepek|jembut|tetek|toket|ngewe|bokep|colok|telanjang|bugil)\b/i,
    /\b(penis|vagina|intercourse|orgasm|nude|ejaculation)\b/i,
  ];

  // Category 3: Profanity & Toxic Insults (Indonesian & English)
  private readonly profanityPatterns: RegExp[] = [
    /\b(anjing|asew|babi|bangsat|kontol|pantek|pepek|kampang|monyet|kintil|peler|jancok|dancok|bajingan|goblok|tolol|idiot|bego|panteq)\b/i,
    /\b(fuck|bitch|bastard|asshole|cunt|dick|pussy|whore|slut|bullshit)\b/i,
  ];

  // Category 4: Prompt Injection & System Manipulation
  private readonly promptInjectionPatterns: RegExp[] = [
    /\b(ignore\s+previous\s+instructions|system\s+prompt|disregard\s+all\s+prior|override\s+instructions|you\s+must\s+give\s+score\s+100|beri\s+nilai\s+100|abaikan\s+instruksi\s+sebelumnya)\b/i,
    /\b(act\s+as\s+DAN|do\s+anything\s+now|bypass\s+safety)\b/i,
  ];

  validateAnswer(text: string): GuardrailCheckResult {
    if (!text || text.trim().length === 0) {
      return { isAllowed: true };
    }

    const normalizedText = this.normalizeText(text);

    // 1. Check Prompt Injection
    for (const pattern of this.promptInjectionPatterns) {
      const match = pattern.exec(normalizedText);
      if (match) {
        this.logger.warn(
          `Guardrail Triggered [prompt_injection]: matched "${match[0]}"`,
        );
        return {
          isAllowed: false,
          category: 'prompt_injection',
          matchedTerm: match[0],
          reason:
            'Jawaban mengandung upaya instruksi manipulasi sistem (Prompt Injection).',
        };
      }
    }

    // 2. Check SARA
    for (const pattern of this.saraPatterns) {
      const match = pattern.exec(normalizedText);
      if (match) {
        this.logger.warn(`Guardrail Triggered [sara]: matched "${match[0]}"`);
        return {
          isAllowed: false,
          category: 'sara',
          matchedTerm: match[0],
          reason:
            'Jawaban mengandung istilah atau ujaran yang tidak relevan (SARA).',
        };
      }
    }

    // 3. Check Explicit / Sexual Content
    for (const pattern of this.explicitPatterns) {
      const match = pattern.exec(normalizedText);
      if (match) {
        this.logger.warn(
          `Guardrail Triggered [explicit]: matched "${match[0]}"`,
        );
        return {
          isAllowed: false,
          category: 'explicit',
          matchedTerm: match[0],
          reason:
            'Jawaban mengandung istilah bermuatan eksplisit atau tidak pantas.',
        };
      }
    }

    // 4. Check Profanity / Toxic Words
    for (const pattern of this.profanityPatterns) {
      const match = pattern.exec(normalizedText);
      if (match) {
        this.logger.warn(
          `Guardrail Triggered [profanity]: matched "${match[0]}"`,
        );
        return {
          isAllowed: false,
          category: 'profanity',
          matchedTerm: match[0],
          reason:
            'Jawaban mengandung kata-kata kasar atau bahasa yang tidak sopan.',
        };
      }
    }

    return { isAllowed: true };
  }

  private normalizeText(text: string): string {
    return text
      .toLowerCase()
      .replace(/[4@]/g, 'a')
      .replace(/[$5]/g, 's')
      .replace(/[0]/g, 'o')
      .replace(/[1!|]/g, 'i')
      .replace(/[3]/g, 'e')
      .replace(/[7]/g, 't')
      .replace(/\s+/g, ' ');
  }
}
