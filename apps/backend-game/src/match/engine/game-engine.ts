import { Injectable } from '@nestjs/common';
import type { PublicBattleState } from '../../../../../contracts/battle-state';
import type { MatchResultPayload } from '../../../../../contracts/match.payloads';
import { QuestionDealer } from './question-dealer';
import type {
  BattleActionResult,
  BattleRole,
  FinishReason,
  InternalPlayerState,
  InternalRoomState,
  OpenCardSuccess,
  PlayCardSuccess,
  SurrenderSuccess,
} from './battle.types';
import { toPublicCard } from './battle.types';
import type { InternalCard } from '../questions/question.types';

@Injectable()
export class GameEngine {
  static readonly STARTING_HP = 100;
  static readonly MAX_HP = 100;
  static readonly ROUND_DURATION_MS = 180_000;
  static readonly ROUND_BREAK_MS = 3_000;
  static readonly MAX_ROUNDS = 3;
  static readonly WINS_TO_WIN = 2;
  static readonly BASE_DAMAGE = 5;
  static readonly COMBO_WINDOW_MS = 7_000;
  private readonly dealer = new QuestionDealer();

  createRoom(
    roomId: string,
    playerAUserId: string,
    playerBUserId: string,
    sharedQueue: ReturnType<QuestionDealer['createSharedQueue']>,
    reserveQueue: InternalCard[] = [],
  ): InternalRoomState {
    const startedAt = new Date();
    return {
      roomId,
      status: 'active',
      sharedQueue,
      reserveQueue,
      nextRecycleId: sharedQueue.length + reserveQueue.length + 1,
      currentRound: 1,
      playerARoundWins: 0,
      playerBRoundWins: 0,
      roundStatus: 'active',
      roundEndsAt: new Date(
        startedAt.getTime() +
          GameEngine.ROUND_BREAK_MS +
          GameEngine.ROUND_DURATION_MS,
      ),
      startedAt,
      players: {
        playerA: this.createPlayer(playerAUserId, 'playerA', sharedQueue),
        playerB: this.createPlayer(playerBUserId, 'playerB', sharedQueue),
      },
    };
  }

  openCard(
    room: InternalRoomState,
    userId: string,
    cardId: string,
  ): BattleActionResult<OpenCardSuccess> {
    const player = this.getPlayer(room, userId);
    if (!player)
      return this.reject('not_in_room', 'Player is not in this room.');
    if (room.status !== 'active')
      return this.reject('room_not_active', 'Room is not active.');
    if (room.roundStatus !== 'active') {
      return this.reject(
        'round_not_active',
        'The next round has not started yet.',
      );
    }
    if (player.openedCardId)
      return this.reject('card_already_open', 'Finish your opened card first.');
    if (!player.hand.some((card) => card.id === cardId)) {
      return this.reject('card_not_in_hand', 'Card is not in your hand.');
    }
    if (player.answeredCardIds.has(cardId)) {
      return this.reject('card_already_answered', 'Card was already answered.');
    }

    player.openedCardId = cardId;
    return { ok: true, room };
  }

  playCard(
    room: InternalRoomState,
    userId: string,
    cardId: string,
    selectedOptionIndex: number,
  ): BattleActionResult<PlayCardSuccess> {
    const player = this.getPlayer(room, userId);
    const opponent = this.getOpponent(room, userId);
    if (!player || !opponent)
      return this.reject('not_in_room', 'Player is not in this room.');
    if (room.status !== 'active')
      return this.reject('room_not_active', 'Room is not active.');
    if (room.roundStatus !== 'active') {
      return this.reject(
        'round_not_active',
        'The next round has not started yet.',
      );
    }
    if (player.openedCardId !== cardId) {
      return this.reject(
        'card_not_opened',
        'Open this card before playing it.',
      );
    }

    const cardIndex = player.hand.findIndex((card) => card.id === cardId);
    if (cardIndex === -1)
      return this.reject('card_not_in_hand', 'Card is not in your hand.');
    if (player.answeredCardIds.has(cardId)) {
      return this.reject('card_already_answered', 'Card was already answered.');
    }

    const card = player.hand[cardIndex];
    if (
      !Number.isInteger(selectedOptionIndex) ||
      selectedOptionIndex < 0 ||
      selectedOptionIndex >= card.options.length
    ) {
      return this.reject(
        'invalid_selected_option',
        'Selected option is invalid.',
      );
    }

    const correct = selectedOptionIndex === card.correctOptionIndex;
    let effectValue = 0;
    let effect: 'damage' | 'heal' | 'none' = 'none';
    this.normalizeCombo(player);
    this.normalizeCombo(opponent);
    const projectileLevel = player.comboLevel;

    if (correct && card.effect === 'damage') {
      effect = 'damage';
      effectValue = this.damageForCombo(projectileLevel);
      opponent.hp = this.clampHp(opponent.hp - effectValue);
      player.points += effectValue;
      opponent.comboLevel = Math.max(1, opponent.comboLevel - 1);
      this.refreshComboExpiry(opponent);
    }

    if (correct && card.effect === 'heal') {
      effect = 'heal';
      effectValue = card.healValue;
      player.hp = this.clampHp(player.hp + effectValue);
      player.points += effectValue;
    }

    player.comboLevel = correct
      ? Math.min(3, player.comboLevel + 1)
      : Math.max(1, player.comboLevel - 1);
    this.refreshComboExpiry(player);

    player.hand.splice(cardIndex, 1);
    player.answeredCardIds.add(cardId);
    player.openedCardId = undefined;

    // Try drawing from main shared queue first
    let nextCard = this.dealer.drawAt(room.sharedQueue, player.nextDrawIndex);
    if (nextCard) {
      player.hand.push(nextCard);
      player.nextDrawIndex += 1;
    } else {
      // Main queue exhausted — try recycling from reserve buffer with a fresh card ID
      nextCard = this.drawFromReserve(room);
      if (nextCard) {
        player.hand.push(nextCard);
      }
    }

    const matchResult =
      opponent.hp <= 0 ? this.completeRound(room, 'hp_zero') : undefined;
    const playResult = {
      roomId: room.roomId,
      cardId,
      correct,
      effect,
      effectValue,
      projectileLevel,
    };

    return { ok: true, room, playResult, matchResult };
  }

  timeoutCard(
    room: InternalRoomState,
    userId: string,
    cardId: string,
  ): BattleActionResult<PlayCardSuccess> {
    const player = this.getPlayer(room, userId);
    const opponent = this.getOpponent(room, userId);
    if (!player || !opponent)
      return this.reject('not_in_room', 'Player is not in this room.');
    if (room.status !== 'active')
      return this.reject('room_not_active', 'Room is not active.');
    if (room.roundStatus !== 'active') {
      return this.reject(
        'round_not_active',
        'The next round has not started yet.',
      );
    }
    if (player.openedCardId !== cardId) {
      return this.reject('card_not_opened', 'Card is not opened.');
    }

    const cardIndex = player.hand.findIndex((card) => card.id === cardId);
    if (cardIndex === -1)
      return this.reject('card_not_in_hand', 'Card is not in your hand.');
    if (player.answeredCardIds.has(cardId)) {
      return this.reject('card_already_answered', 'Card was already answered.');
    }

    // Timeout is a wrong answer: 0 damage, 0 heal
    const correct = false;
    const effect: 'damage' | 'heal' | 'none' = 'none';
    const effectValue = 0;
    const projectileLevel = 1;
    this.normalizeCombo(player);
    player.comboLevel = Math.max(1, player.comboLevel - 1);
    this.refreshComboExpiry(player);

    player.hand.splice(cardIndex, 1);
    player.answeredCardIds.add(cardId);
    player.openedCardId = undefined;

    // Try drawing from main shared queue first
    let nextCard = this.dealer.drawAt(room.sharedQueue, player.nextDrawIndex);
    if (nextCard) {
      player.hand.push(nextCard);
      player.nextDrawIndex += 1;
    } else {
      // Main queue exhausted — try recycling from reserve buffer
      nextCard = this.drawFromReserve(room);
      if (nextCard) {
        player.hand.push(nextCard);
      }
    }

    const playResult = {
      roomId: room.roomId,
      cardId,
      correct,
      effect,
      effectValue,
      projectileLevel,
    };

    return { ok: true, room, playResult };
  }

  surrender(
    room: InternalRoomState,
    userId: string,
  ): BattleActionResult<SurrenderSuccess> {
    const player = this.getPlayer(room, userId);
    if (!player)
      return this.reject('not_in_room', 'Player is not in this room.');
    if (room.status !== 'active')
      return this.reject('room_not_active', 'Room is not active.');
    const result = this.finish(
      room,
      'surrender',
      this.getOpponent(room, userId)?.userId ?? null,
      userId,
    );
    return { ok: true, room, matchResult: result };
  }

  buildPublicState(room: InternalRoomState, userId: string): PublicBattleState {
    const self = this.getPlayer(room, userId);
    const opponent = this.getOpponent(room, userId);
    if (!self || !opponent) {
      throw new Error('Cannot build battle state for non-member.');
    }
    this.normalizeCombo(self);
    this.normalizeCombo(opponent);

    return {
      roomId: room.roomId,
      status: room.status,
      self: {
        userId: self.userId,
        role: self.role,
        hp: self.hp,
        points: self.points,
        comboLevel: self.comboLevel,
        hand: self.hand.map(toPublicCard),
        openedCardId: self.openedCardId,
        answeredCardIds: Array.from(self.answeredCardIds),
        connected: self.connected,
      },
      opponent: {
        userId: opponent.userId,
        role: opponent.role,
        hp: opponent.hp,
        points: opponent.points,
        comboLevel: opponent.comboLevel,
        connected: opponent.connected,
      },
      currentRound: room.currentRound,
      roundSecondsRemaining: this.roundSecondsRemaining(room),
      selfRoundWins:
        self.role === 'playerA' ? room.playerARoundWins : room.playerBRoundWins,
      opponentRoundWins:
        self.role === 'playerA' ? room.playerBRoundWins : room.playerARoundWins,
      lastRoundOutcome: this.lastRoundOutcomeFor(room, userId),
      phase: this.phaseFor(room, self.openedCardId),
      outcome: room.result ? this.outcomeFor(room.result, userId) : undefined,
    };
  }

  private createPlayer(
    userId: string,
    role: BattleRole,
    sharedQueue: InternalRoomState['sharedQueue'],
  ): InternalPlayerState {
    return {
      userId,
      socketId: null,
      role,
      hp: GameEngine.STARTING_HP,
      points: 0,
      comboLevel: 1,
      hand: this.dealer.createStartingHand(sharedQueue),
      answeredCardIds: new Set<string>(),
      nextDrawIndex: QuestionDealer.HAND_SIZE,
      connected: true,
    };
  }

  finishRoundOnTimeout(
    room: InternalRoomState,
  ): MatchResultPayload | undefined {
    if (room.status !== 'active' || room.roundStatus !== 'active') {
      return room.result;
    }
    return this.completeRound(room, 'round_timeout');
  }

  startNextRound(room: InternalRoomState): boolean {
    if (
      room.status !== 'active' ||
      room.roundStatus !== 'break' ||
      room.currentRound >= GameEngine.MAX_ROUNDS
    ) {
      return false;
    }
    room.currentRound += 1;
    room.roundStatus = 'active';
    room.nextRoundAt = undefined;
    room.lastRoundWinnerUserId = undefined;
    room.roundEndsAt = new Date(Date.now() + GameEngine.ROUND_DURATION_MS);
    for (const player of Object.values(room.players)) {
      player.hp = GameEngine.STARTING_HP;
      player.points = 0;
      player.comboLevel = 1;
      player.comboExpiresAt = undefined;
      player.openedCardId = undefined;
      player.hand = this.dealer.createStartingHand(room.sharedQueue);
      player.answeredCardIds.clear();
      player.nextDrawIndex = QuestionDealer.HAND_SIZE;
    }
    return true;
  }

  private completeRound(
    room: InternalRoomState,
    reason: Extract<FinishReason, 'hp_zero' | 'round_timeout'>,
  ): MatchResultPayload | undefined {
    if (room.result) return room.result;
    const { playerA, playerB } = room.players;
    let roundWinnerUserId: string | null = null;
    if (playerA.hp > playerB.hp) roundWinnerUserId = playerA.userId;
    if (playerB.hp > playerA.hp) roundWinnerUserId = playerB.userId;

    if (roundWinnerUserId === playerA.userId) room.playerARoundWins += 1;
    if (roundWinnerUserId === playerB.userId) room.playerBRoundWins += 1;
    room.lastRoundWinnerUserId = roundWinnerUserId;
    room.roundEndsAt = undefined;
    playerA.openedCardId = undefined;
    playerB.openedCardId = undefined;

    const matchFinished =
      room.playerARoundWins >= GameEngine.WINS_TO_WIN ||
      room.playerBRoundWins >= GameEngine.WINS_TO_WIN ||
      room.currentRound >= GameEngine.MAX_ROUNDS;
    if (!matchFinished) {
      room.roundStatus = 'break';
      room.nextRoundAt = new Date(Date.now() + GameEngine.ROUND_BREAK_MS);
      return undefined;
    }

    if (room.playerARoundWins > room.playerBRoundWins) {
      return this.finish(room, reason, playerA.userId, playerB.userId);
    }
    if (room.playerBRoundWins > room.playerARoundWins) {
      return this.finish(room, reason, playerB.userId, playerA.userId);
    }
    return this.finish(room, 'draw', null, null);
  }

  private finish(
    room: InternalRoomState,
    reason: MatchResultPayload['reason'],
    winnerUserId: string | null,
    loserUserId: string | null,
  ): MatchResultPayload {
    if (room.result) return room.result;
    room.status = 'finished';
    room.endedAt = new Date();
    room.result = {
      roomId: room.roomId,
      outcome:
        reason === 'surrender' ? 'surrender' : winnerUserId ? 'win' : 'draw',
      winnerUserId,
      loserUserId,
      reason,
      finalState: {
        playerA: {
          userId: room.players.playerA.userId,
          hp: room.players.playerA.hp,
          points: room.players.playerA.points,
        },
        playerB: {
          userId: room.players.playerB.userId,
          hp: room.players.playerB.hp,
          points: room.players.playerB.points,
        },
      },
    };
    return room.result;
  }

  private outcomeFor(
    result: MatchResultPayload,
    userId: string,
  ): PublicBattleState['outcome'] {
    if (result.reason === 'surrender' && result.loserUserId === userId)
      return 'surrender';
    if (!result.winnerUserId) return 'draw';
    return result.winnerUserId === userId ? 'win' : 'lose';
  }

  private phaseFor(
    room: InternalRoomState,
    openedCardId?: string,
  ): PublicBattleState['phase'] {
    if (room.status === 'finished') return 'finished';
    if (room.status === 'waiting') return 'waiting';
    if (room.roundStatus === 'break') return 'round_break';
    if (openedCardId) return 'card_opened';
    return 'active';
  }

  private roundSecondsRemaining(room: InternalRoomState): number {
    if (!room.roundEndsAt || room.roundStatus !== 'active') return 0;
    return Math.min(
      GameEngine.ROUND_DURATION_MS / 1000,
      Math.max(0, Math.ceil((room.roundEndsAt.getTime() - Date.now()) / 1000)),
    );
  }

  private lastRoundOutcomeFor(
    room: InternalRoomState,
    userId: string,
  ): PublicBattleState['lastRoundOutcome'] {
    if (room.lastRoundWinnerUserId === undefined) return undefined;
    if (room.lastRoundWinnerUserId === null) return 'draw';
    return room.lastRoundWinnerUserId === userId ? 'win' : 'lose';
  }

  damageForCombo(comboLevel: number): number {
    return Math.max(1, Math.min(3, comboLevel)) * GameEngine.BASE_DAMAGE;
  }

  private normalizeCombo(player: InternalPlayerState): void {
    if (
      player.comboLevel > 1 &&
      player.comboExpiresAt &&
      player.comboExpiresAt.getTime() <= Date.now()
    ) {
      player.comboLevel = 1;
      player.comboExpiresAt = undefined;
    }
  }

  private refreshComboExpiry(player: InternalPlayerState): void {
    player.comboExpiresAt =
      player.comboLevel > 1
        ? new Date(Date.now() + GameEngine.COMBO_WINDOW_MS)
        : undefined;
  }

  /**
   * Draw a card from the reserve buffer with a fresh card-instance ID.
   * Returns undefined if reserve is also exhausted.
   */
  private drawFromReserve(room: InternalRoomState): InternalCard | undefined {
    if (room.reserveQueue.length === 0) return undefined;
    const card = room.reserveQueue.shift()!;
    const freshId = `card_r${room.nextRecycleId}`;
    room.nextRecycleId += 1;
    return { ...card, id: freshId, options: [...card.options] };
  }

  getPlayer(
    room: InternalRoomState,
    userId: string,
  ): InternalPlayerState | undefined {
    return Object.values(room.players).find(
      (player) => player.userId === userId,
    );
  }

  getOpponent(
    room: InternalRoomState,
    userId: string,
  ): InternalPlayerState | undefined {
    return Object.values(room.players).find(
      (player) => player.userId !== userId,
    );
  }

  private clampHp(value: number): number {
    return Math.max(0, Math.min(GameEngine.MAX_HP, value));
  }

  private reject(reason: string, message: string): BattleActionResult<never> {
    return { ok: false, reason, message, recoverable: true };
  }
}
