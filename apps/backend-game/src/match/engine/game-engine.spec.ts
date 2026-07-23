import { GameEngine } from './game-engine';
import { QuestionDealer } from './question-dealer';
import type { InternalCard } from '../questions/question.types';

/** Helper to create test cards */
const makeCards = (
  count: number,
  overrides: Partial<InternalCard> = {},
): InternalCard[] =>
  Array.from({ length: count }, (_, i) => ({
    id: `card_${i + 1}`,
    sourceQuestionId: `question_${i + 1}`,
    prompt: `Question ${i + 1}`,
    options: ['A', 'B', 'C', 'D'],
    correctOptionIndex: 1,
    weight: 1,
    effect: 'damage' as const,
    damageValue: 10,
    healValue: 0,
    timeLimitSeconds: 30,
    ...overrides,
  }));

/** Create heal cards */
const makeHealCards = (count: number): InternalCard[] =>
  makeCards(count, { effect: 'heal', damageValue: 0, healValue: 20 });

describe('GameEngine', () => {
  let engine: GameEngine;

  beforeEach(() => {
    engine = new GameEngine();
  });

  // ─── Room Creation ───

  describe('createRoom', () => {
    it('creates a room with active status and correct player setup', () => {
      const cards = makeCards(8);
      const room = engine.createRoom('room_1', 'player-a', 'player-b', cards);

      expect(room.roomId).toBe('room_1');
      expect(room.status).toBe('active');
      expect(room.players.playerA.userId).toBe('player-a');
      expect(room.players.playerB.userId).toBe('player-b');
      expect(room.players.playerA.role).toBe('playerA');
      expect(room.players.playerB.role).toBe('playerB');
    });

    it('sets starting HP to 100 for both players', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      expect(room.players.playerA.hp).toBe(100);
      expect(room.players.playerB.hp).toBe(100);
      expect(GameEngine.STARTING_HP).toBe(100);
    });

    it('deals HAND_SIZE cards to each player', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      expect(room.players.playerA.hand).toHaveLength(QuestionDealer.HAND_SIZE);
      expect(room.players.playerB.hand).toHaveLength(QuestionDealer.HAND_SIZE);
    });

    it('starts both players with 0 points and empty answered sets', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      expect(room.players.playerA.points).toBe(0);
      expect(room.players.playerB.points).toBe(0);
      expect(room.players.playerA.answeredCardIds.size).toBe(0);
      expect(room.players.playerB.answeredCardIds.size).toBe(0);
    });

    it('includes all supplied Supabase cards in the recyclable pool', () => {
      const active = makeCards(8);
      const reserve = makeCards(4).map((c, i) => ({
        ...c,
        id: `reserve_${i}`,
      }));
      const room = engine.createRoom('room_1', 'a', 'b', active, reserve);

      expect(room.sharedQueue).toHaveLength(12);
    });

    it('uses the supplied pool when no additional cards are provided', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      expect(room.sharedQueue).toHaveLength(8);
    });
  });

  // ─── openCard ───

  describe('openCard', () => {
    it('succeeds and sets openedCardId on the player', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const result = engine.openCard(room, 'a', 'card_1');

      expect(result.ok).toBe(true);
      expect(room.players.playerA.openedCardId).toBe('card_1');
    });

    it('rejects a player not in the room', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const result = engine.openCard(room, 'stranger', 'card_1');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('not_in_room');
    });

    it('rejects when room is not active', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      room.status = 'finished';

      const result = engine.openCard(room, 'a', 'card_1');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('room_not_active');
    });

    it('rejects when player already has an open card', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.openCard(room, 'a', 'card_1');

      const result = engine.openCard(room, 'a', 'card_2');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('card_already_open');
    });

    it('rejects a card not in the player hand', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const result = engine.openCard(room, 'a', 'nonexistent_card');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('card_not_in_hand');
    });

    it('rejects an already-answered card', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      room.players.playerA.answeredCardIds.add('card_1');

      const result = engine.openCard(room, 'a', 'card_1');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('card_already_answered');
    });
  });

  // ─── playCard ───

  describe('playCard', () => {
    it('rejects play_card before open_card', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const result = engine.playCard(room, 'a', 'card_1', 1);

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('card_not_opened');
    });

    it('deals damage on correct answer with damage card', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.openCard(room, 'a', 'card_1');

      const result = engine.playCard(room, 'a', 'card_1', 1); // correctOptionIndex=1

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.playResult.correct).toBe(true);
        expect(result.playResult.effect).toBe('damage');
        expect(result.playResult.effectValue).toBe(5);
        expect(result.playResult.projectileLevel).toBe(1);
        expect(room.players.playerB.hp).toBe(95);
        expect(room.players.playerA.points).toBe(5);
        expect(room.players.playerA.comboLevel).toBe(2);
      }
    });

    it('scales combo damage to 5, 10, then 15', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      for (const [index, expectedDamage] of [5, 10, 15].entries()) {
        const cardId = `card_${index + 1}`;
        engine.openCard(room, 'a', cardId);
        const result = engine.playCard(room, 'a', cardId, 1);
        expect(result.ok).toBe(true);
        if (result.ok) {
          expect(result.playResult.effectValue).toBe(expectedDamage);
          expect(result.playResult.projectileLevel).toBe(index + 1);
        }
      }
      expect(room.players.playerB.hp).toBe(70);
    });

    it('heals on correct answer with heal card (capped at MAX_HP)', () => {
      const healCards: InternalCard[] = Array.from({ length: 8 }, (_, i) => ({
        id: `card_${i + 1}`,
        sourceQuestionId: `question_${i + 1}`,
        prompt: `Q${i}`,
        options: ['A', 'B', 'C', 'D'],
        correctOptionIndex: 0,
        weight: 1,
        effect: 'heal' as const,
        damageValue: 0,
        healValue: 50,
        timeLimitSeconds: 30,
      }));
      const room = engine.createRoom('room_1', 'a', 'b', healCards);
      room.players.playerA.hp = 80;

      engine.openCard(room, 'a', 'card_1');
      const result = engine.playCard(room, 'a', 'card_1', 0);

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.playResult.correct).toBe(true);
        expect(result.playResult.effect).toBe('heal');
        // 80 + 50 = 130, but capped at 100
        expect(room.players.playerA.hp).toBe(100);
      }
    });

    it('has no effect on wrong answer', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.openCard(room, 'a', 'card_1');

      const result = engine.playCard(room, 'a', 'card_1', 0); // wrong (correct is 1)

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.playResult.correct).toBe(false);
        expect(result.playResult.effect).toBe('none');
        expect(result.playResult.effectValue).toBe(0);
        expect(room.players.playerB.hp).toBe(100); // unchanged
        expect(room.players.playerA.points).toBe(0);
      }
    });

    it('removes card from hand and marks as answered', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.openCard(room, 'a', 'card_1');
      engine.playCard(room, 'a', 'card_1', 1);

      expect(room.players.playerA.hand.some((c) => c.id === 'card_1')).toBe(
        false,
      );
      expect(room.players.playerA.answeredCardIds.has('card_1')).toBe(true);
      expect(room.players.playerA.openedCardId).toBeUndefined();
    });

    it('draws a new card from the shared queue after playing', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      const handSizeBefore = room.players.playerA.hand.length;

      engine.openCard(room, 'a', 'card_1');
      engine.playCard(room, 'a', 'card_1', 1);

      // Hand size should remain the same (drew a replacement from the queue)
      expect(room.players.playerA.hand.length).toBe(handSizeBefore);
    });

    it('recycles the Supabase pool with a fresh card-instance ID', () => {
      const active = makeCards(4); // Exactly HAND_SIZE, so no draws from main queue
      const reserve: InternalCard[] = [{
        id: 'reserve_1',
        sourceQuestionId: 'question_reserve_1',
        prompt: 'Reserve Q',
        options: ['A', 'B', 'C', 'D'],
        correctOptionIndex: 1,
        weight: 1,
        effect: 'damage',
        damageValue: 10,
        healValue: 0,
        timeLimitSeconds: 30,
      }];
      const room = engine.createRoom('room_1', 'a', 'b', active, reserve);

      engine.openCard(room, 'a', 'card_1');
      engine.playCard(room, 'a', 'card_1', 1);
      engine.openCard(room, 'a', 'card_2');
      engine.playCard(room, 'a', 'card_2', 1);

      // Equivalent draw positions recycle the shared pool with a fresh ID.
      const drawnCard = room.players.playerA.hand.find((c) => c.id.startsWith('card_r'));
      expect(drawnCard).toBeDefined();
    });

    it('continues through multiple full pool cycles with unique instance IDs', () => {
      const room = engine.createRoom(
        'room_recycling',
        'player-a',
        'player-b',
        makeCards(QuestionDealer.HAND_SIZE),
      );
      const instanceIds: string[] = [];
      const sourceIds: string[] = [];

      for (let draw = 0; draw < QuestionDealer.HAND_SIZE * 3; draw += 1) {
        const card = room.players.playerA.hand[0];
        instanceIds.push(card.id);
        sourceIds.push(card.sourceQuestionId);
        engine.openCard(room, 'player-a', card.id);
        engine.playCard(room, 'player-a', card.id, 0);
      }

      expect(room.status).toBe('active');
      expect(new Set(instanceIds).size).toBe(instanceIds.length);
      expect(new Set(sourceIds).size).toBe(QuestionDealer.HAND_SIZE);
      expect(
        instanceIds.slice(QuestionDealer.HAND_SIZE).every(
          (id) => id.startsWith('card_r'),
        ),
      ).toBe(true);
    });

    it('rejects invalid selectedOptionIndex', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.openCard(room, 'a', 'card_1');

      const result = engine.playCard(room, 'a', 'card_1', -1);
      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('invalid_selected_option');
    });

    it('rejects selectedOptionIndex >= options.length', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.openCard(room, 'a', 'card_1');

      const result = engine.playCard(room, 'a', 'card_1', 4);
      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('invalid_selected_option');
    });

    it('requires two hp_zero round wins to finish the match', () => {
      const cards = makeCards(8);
      const room = engine.createRoom('room_1', 'a', 'b', cards);
      room.players.playerB.hp = 5;

      engine.openCard(room, 'a', 'card_1');
      const firstRound = engine.playCard(room, 'a', 'card_1', 1);

      expect(firstRound.ok).toBe(true);
      if (firstRound.ok) {
        expect(firstRound.matchResult).toBeUndefined();
      }
      expect(room.roundStatus).toBe('break');
      expect(room.playerARoundWins).toBe(1);
      expect(room.status).toBe('active');

      expect(engine.startNextRound(room)).toBe(true);
      expect(room.currentRound).toBe(2);
      expect(room.players.playerA.hp).toBe(100);
      expect(room.players.playerB.hp).toBe(100);

      room.players.playerB.hp = 5;
      engine.openCard(room, 'a', 'card_2');
      const secondRound = engine.playCard(room, 'a', 'card_2', 1);

      expect(secondRound.ok).toBe(true);
      if (secondRound.ok) {
        expect(secondRound.matchResult).toBeDefined();
        expect(secondRound.matchResult!.reason).toBe('hp_zero');
        expect(secondRound.matchResult!.winnerUserId).toBe('a');
        expect(secondRound.matchResult!.loserUserId).toBe('b');
      }
      expect(room.playerARoundWins).toBe(2);
      expect(room.status).toBe('finished');
    });

    it('scopes cards independently per player', () => {
      const cards = makeCards(8);
      const room = engine.createRoom('room_1', 'a', 'b', cards);

      engine.openCard(room, 'a', 'card_1');
      engine.playCard(room, 'a', 'card_1', 1);

      // playerA consumed card_1, playerB still has it
      expect(room.players.playerA.hand.some((c) => c.id === 'card_1')).toBe(
        false,
      );
      expect(room.players.playerB.hand.some((c) => c.id === 'card_1')).toBe(
        true,
      );
      expect(room.players.playerA.answeredCardIds.has('card_1')).toBe(true);
      expect(room.players.playerB.answeredCardIds.has('card_1')).toBe(false);
    });
  });

  // ─── timeoutCard ───

  describe('timeoutCard', () => {
    it('resolves as incorrect with 0 effect', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.openCard(room, 'a', 'card_1');

      const result = engine.timeoutCard(room, 'a', 'card_1');

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.playResult.correct).toBe(false);
        expect(result.playResult.effect).toBe('none');
        expect(result.playResult.effectValue).toBe(0);
      }
    });

    it('removes the card from hand and marks as answered', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.openCard(room, 'a', 'card_1');

      engine.timeoutCard(room, 'a', 'card_1');

      expect(room.players.playerA.hand.some((c) => c.id === 'card_1')).toBe(
        false,
      );
      expect(room.players.playerA.answeredCardIds.has('card_1')).toBe(true);
      expect(room.players.playerA.openedCardId).toBeUndefined();
    });

    it('draws a replacement card from the queue', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      const handSizeBefore = room.players.playerA.hand.length;

      engine.openCard(room, 'a', 'card_1');
      engine.timeoutCard(room, 'a', 'card_1');

      expect(room.players.playerA.hand.length).toBe(handSizeBefore);
    });

    it('rejects when card is not opened', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const result = engine.timeoutCard(room, 'a', 'card_1');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('card_not_opened');
    });

    it('rejects a non-member', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const result = engine.timeoutCard(room, 'stranger', 'card_1');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('not_in_room');
    });
  });

  // ─── surrender ───

  describe('surrender', () => {
    it('marks the room as finished with the surrendering player as loser', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const result = engine.surrender(room, 'a');

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(room.status).toBe('finished');
        expect(result.matchResult.winnerUserId).toBe('b');
        expect(result.matchResult.loserUserId).toBe('a');
        expect(result.matchResult.reason).toBe('surrender');
        expect(result.matchResult.outcome).toBe('surrender');
      }
    });

    it('rejects a non-member', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const result = engine.surrender(room, 'stranger');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('not_in_room');
    });

    it('rejects when room is already finished', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      engine.surrender(room, 'a');

      const result = engine.surrender(room, 'b');

      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.reason).toBe('room_not_active');
    });
  });

  // ─── buildPublicState ───

  describe('buildPublicState', () => {
    it('returns player-relative self and opponent views', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const stateA = engine.buildPublicState(room, 'a');
      const stateB = engine.buildPublicState(room, 'b');

      expect(stateA.self.userId).toBe('a');
      expect(stateA.opponent.userId).toBe('b');
      expect(stateB.self.userId).toBe('b');
      expect(stateB.opponent.userId).toBe('a');
    });

    it('does not expose answer metadata in public state', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      const state = engine.buildPublicState(room, 'a');
      const publicCard = state.self.hand[0] as Record<string, unknown>;

      expect(publicCard.correctOptionIndex).toBeUndefined();
      expect(publicCard.explanation).toBeUndefined();
      expect(publicCard.damageValue).toBeUndefined();
      expect(publicCard.healValue).toBeUndefined();
    });

    it('reports correct phase transitions', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      // Active phase
      expect(engine.buildPublicState(room, 'a').phase).toBe('active');

      // Card opened phase
      engine.openCard(room, 'a', 'card_1');
      expect(engine.buildPublicState(room, 'a').phase).toBe('card_opened');

      // Other player still active
      expect(engine.buildPublicState(room, 'b').phase).toBe('active');
    });

    it('includes outcome after match finishes', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));
      room.currentRound = 2;
      room.playerARoundWins = 1;
      room.players.playerB.hp = 5;
      engine.openCard(room, 'a', 'card_1');
      engine.playCard(room, 'a', 'card_1', 1);

      const stateA = engine.buildPublicState(room, 'a');
      const stateB = engine.buildPublicState(room, 'b');

      expect(stateA.outcome).toBe('win');
      expect(stateB.outcome).toBe('lose');
      expect(stateA.phase).toBe('finished');
    });

    it('throws for a non-member', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      expect(() => engine.buildPublicState(room, 'stranger')).toThrow();
    });
  });

  // ─── Match end tie-breaking ───

  describe('match end tie-breaking', () => {
    it('keeps the match active after complete question-pool cycles', () => {
      const cards = makeCards(QuestionDealer.HAND_SIZE);
      const room = engine.createRoom('room_1', 'a', 'b', cards);
  describe('round timeout', () => {
    it('higher HP wins the round and two round wins finish the match', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      room.players.playerB.hp = 80;
      expect(engine.finishRoundOnTimeout(room)).toBeUndefined();
      expect(room.roundStatus).toBe('break');
      expect(room.playerARoundWins).toBe(1);

      engine.startNextRound(room);
      room.players.playerB.hp = 70;
      const result = engine.finishRoundOnTimeout(room);

      expect(room.status).toBe('active');
      expect(room.result).toBeUndefined();
      expect(
        room.players.playerA.hand.every((card) => card.id.startsWith('card_r')),
      ).toBe(true);
      expect(result).toBeDefined();
      expect(room.status).toBe('finished');
      expect(result?.reason).toBe('round_timeout');
      expect(result?.winnerUserId).toBe('a');
    });

    it('ends as a draw after at most three tied rounds', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      expect(engine.finishRoundOnTimeout(room)).toBeUndefined();
      expect(engine.startNextRound(room)).toBe(true);
      expect(engine.finishRoundOnTimeout(room)).toBeUndefined();
      expect(engine.startNextRound(room)).toBe(true);
      const result = engine.finishRoundOnTimeout(room);

      expect(room.currentRound).toBe(3);
      expect(room.status).toBe('finished');
      expect(result?.outcome).toBe('draw');
      expect(result?.winnerUserId).toBeNull();
    });
  });

  // ─── getPlayer / getOpponent ───

  describe('getPlayer / getOpponent', () => {
    it('returns the correct player and opponent', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      expect(engine.getPlayer(room, 'a')?.userId).toBe('a');
      expect(engine.getOpponent(room, 'a')?.userId).toBe('b');
      expect(engine.getPlayer(room, 'b')?.userId).toBe('b');
      expect(engine.getOpponent(room, 'b')?.userId).toBe('a');
    });

    it('returns undefined/fallback for non-members', () => {
      const room = engine.createRoom('room_1', 'a', 'b', makeCards(8));

      expect(engine.getPlayer(room, 'stranger')).toBeUndefined();
      expect(engine.getOpponent(room, 'stranger')?.userId).toBe('a');
    });
  });
});
