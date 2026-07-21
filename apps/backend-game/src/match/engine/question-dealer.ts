import { Injectable } from '@nestjs/common';
import type { InternalCard } from '../questions/question.types';

@Injectable()
export class QuestionDealer {
  static readonly HAND_SIZE = 4;

  createSharedQueue(cards: InternalCard[]): InternalCard[] {
    return cards.map((card) => ({ ...card, options: [...card.options] }));
  }

  createStartingHand(sharedQueue: InternalCard[]): InternalCard[] {
    return sharedQueue
      .slice(0, QuestionDealer.HAND_SIZE)
      .map((card) => ({ ...card, options: [...card.options] }));
  }

  drawAt(sharedQueue: InternalCard[], index: number): InternalCard | undefined {
    const card = sharedQueue[index];
    return card ? { ...card, options: [...card.options] } : undefined;
  }
}
