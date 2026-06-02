import type { CardEffect, PublicQuestionCard } from '../../../../../contracts/question-card';

export type InternalCard = PublicQuestionCard & {
  correctOptionIndex: number;
  explanation?: string;
  damageValue: number;
  healValue: number;
};

export type QuestionSeed = {
  id: string;
  prompt: string;
  options: [string, string, string, string];
  correctOptionIndex: number;
  weight: number;
  effect: CardEffect;
  explanation?: string;
};
