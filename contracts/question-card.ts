export type CardEffect = 'damage' | 'heal';

export type PublicQuestionCard = {
  id: string;
  prompt: string;
  options: string[];
  weight: number;
  effect: CardEffect;
};
