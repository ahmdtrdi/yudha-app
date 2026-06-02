import { GameEngine } from './game-engine';
import { QuestionDealer } from './question-dealer';
import type { InternalCard } from '../questions/question.types';

const cards: InternalCard[] = [
  {
    id: 'card_1',
    prompt: '1 + 1 = ?',
    options: ['1', '2', '3', '4'],
    correctOptionIndex: 1,
    weight: 1,
    effect: 'damage',
    damageValue: 100,
    healValue: 0,
  },
  {
    id: 'card_2',
    prompt: '2 + 2 = ?',
    options: ['2', '3', '4', '5'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'heal',
    damageValue: 0,
    healValue: 20,
  },
  {
    id: 'card_3',
    prompt: '3 + 3 = ?',
    options: ['4', '5', '6', '7'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
    damageValue: 10,
    healValue: 0,
  },
  {
    id: 'card_4',
    prompt: '4 + 4 = ?',
    options: ['6', '7', '8', '9'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
    damageValue: 10,
    healValue: 0,
  },
  {
    id: 'card_5',
    prompt: '5 + 5 = ?',
    options: ['8', '9', '10', '11'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
    damageValue: 10,
    healValue: 0,
  },
  {
    id: 'card_6',
    prompt: '6 + 6 = ?',
    options: ['10', '11', '12', '13'],
    correctOptionIndex: 2,
    weight: 1,
    effect: 'damage',
    damageValue: 10,
    healValue: 0,
  },
];

describe('GameEngine', () => {
  let engine: GameEngine;

  beforeEach(() => {
    engine = new GameEngine();
  });

  it('scopes identical card IDs independently per player', () => {
    const room = engine.createRoom('room_1', 'player-a', 'player-b', cards);

    expect(engine.openCard(room, 'player-a', 'card_1').ok).toBe(true);
    const result = engine.playCard(room, 'player-a', 'card_1', 1);

    expect(result.ok).toBe(true);
    expect(room.players.playerA.hand.some((card) => card.id === 'card_1')).toBe(false);
    expect(room.players.playerB.hand.some((card) => card.id === 'card_1')).toBe(true);
    expect(room.players.playerA.answeredCardIds.has('card_1')).toBe(true);
    expect(room.players.playerB.answeredCardIds.has('card_1')).toBe(false);
  });

  it('rejects play_card before open_card', () => {
    const room = engine.createRoom('room_1', 'player-a', 'player-b', cards);

    const result = engine.playCard(room, 'player-a', 'card_1', 1);

    expect(result.ok).toBe(false);
  });

  it('sets room to finished before returning a match result', () => {
    const room = engine.createRoom('room_1', 'player-a', 'player-b', cards);

    engine.openCard(room, 'player-a', 'card_1');
    const result = engine.playCard(room, 'player-a', 'card_1', 1);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.matchResult).toBeDefined();
      expect(room.status).toBe('finished');
      expect(engine.buildPublicState(room, 'player-a').status).toBe('finished');
    }
  });

  it('does not expose answer metadata in public state', () => {
    const room = engine.createRoom('room_1', 'player-a', 'player-b', cards);

    const publicCard = engine.buildPublicState(room, 'player-a').self.hand[0] as Record<string, unknown>;

    expect(publicCard.correctOptionIndex).toBeUndefined();
    expect(publicCard.explanation).toBeUndefined();
    expect(publicCard.damageValue).toBeUndefined();
  });
});
