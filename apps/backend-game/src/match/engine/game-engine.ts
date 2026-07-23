import { Injectable } from '@nestjs/common';
import type { PublicBattleState } from '../../../../../contracts/battle-state';
import type { MatchResultPayload } from '../../../../../contracts/match.payloads';
import { QuestionDealer } from './question-dealer';
import type {
  BattleActionResult,
  BattlePlayerSeed,
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
  private readonly dealer = new QuestionDealer();

  createRoom(
    roomId: string,
    mode: InternalRoomState['mode'],
    target: InternalRoomState['target'],
    playerA: BattlePlayerSeed,
    playerB: BattlePlayerSeed,
    sharedQueue: ReturnType<QuestionDealer['createSharedQueue']>,
  ): InternalRoomState;
  createRoom(
    roomId: string,
    playerAUserId: string,
    playerBUserId: string,
    sharedQueue: ReturnType<QuestionDealer['createSharedQueue']>,
    legacyReserve?: InternalCard[],
  ): InternalRoomState;
  createRoom(
    roomId: string,
    modeOrPlayerA: InternalRoomState['mode'] | string,
    targetOrPlayerB: InternalRoomState['target'] | string,
    playerAOrQueue:
      | BattlePlayerSeed
      | ReturnType<QuestionDealer['createSharedQueue']>,
    playerBOrReserve?: BattlePlayerSeed | InternalCard[],
    modernQueue?: ReturnType<QuestionDealer['createSharedQueue']>,
  ): InternalRoomState {
    const modern = modernQueue !== undefined;
    const mode: InternalRoomState['mode'] = modern
      ? (modeOrPlayerA as InternalRoomState['mode'])
      : 'casual';
    const target: InternalRoomState['target'] = modern
      ? (targetOrPlayerB as InternalRoomState['target'])
      : 'cpns';
    const playerA: BattlePlayerSeed = modern
      ? (playerAOrQueue as BattlePlayerSeed)
      : this.legacyPlayer(modeOrPlayerA, 'Player A');
    const playerB: BattlePlayerSeed = modern
      ? (playerBOrReserve as BattlePlayerSeed)
      : this.legacyPlayer(targetOrPlayerB, 'Player B');
    const sharedQueue = modern
      ? modernQueue
      : this.dealer.createSharedQueue([
          ...(playerAOrQueue as InternalCard[]),
          ...((playerBOrReserve as InternalCard[] | undefined) ?? []),
        ]);
    return {
      roomId,
      status: 'active',
      mode,
      target,
      sharedQueue,
      startedAt: new Date(),
      players: {
        playerA: this.createPlayer(playerA, 'playerA', sharedQueue),
        playerB: this.createPlayer(playerB, 'playerB', sharedQueue),
      },
    };
  }

  private legacyPlayer(userId: string, displayName: string): BattlePlayerSeed {
    return {
      userId,
      displayName,
      loadout: {
        characterId: 'character-basic-squire',
        towerId: 'tower-garda-biru',
      },
    };
  }

  openCard(room: InternalRoomState, userId: string, cardId: string): BattleActionResult<OpenCardSuccess> {
    const player = this.getPlayer(room, userId);
    if (!player) return this.reject('not_in_room', 'Player is not in this room.');
    if (room.status !== 'active') return this.reject('room_not_active', 'Room is not active.');
    if (player.openedCardId) return this.reject('card_already_open', 'Finish your opened card first.');
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
    if (!player || !opponent) return this.reject('not_in_room', 'Player is not in this room.');
    if (room.status !== 'active') return this.reject('room_not_active', 'Room is not active.');
    if (player.openedCardId !== cardId) {
      return this.reject('card_not_opened', 'Open this card before playing it.');
    }

    const cardIndex = player.hand.findIndex((card) => card.id === cardId);
    if (cardIndex === -1) return this.reject('card_not_in_hand', 'Card is not in your hand.');
    if (player.answeredCardIds.has(cardId)) {
      return this.reject('card_already_answered', 'Card was already answered.');
    }

    const card = player.hand[cardIndex];
    if (
      !Number.isInteger(selectedOptionIndex) ||
      selectedOptionIndex < 0 ||
      selectedOptionIndex >= card.options.length
    ) {
      return this.reject('invalid_selected_option', 'Selected option is invalid.');
    }

    const correct = selectedOptionIndex === card.correctOptionIndex;
    let effectValue = 0;
    let effect: 'damage' | 'heal' | 'none' = 'none';

    if (correct && card.effect === 'damage') {
      effect = 'damage';
      effectValue = card.damageValue;
      opponent.hp = this.clampHp(opponent.hp - effectValue);
      player.points += effectValue;
    }

    if (correct && card.effect === 'heal') {
      effect = 'heal';
      effectValue = card.healValue;
      player.hp = this.clampHp(player.hp + effectValue);
      player.points += effectValue;
    }

    player.hand.splice(cardIndex, 1);
    player.answeredCardIds.add(cardId);
    player.openedCardId = undefined;

    const nextCard = this.drawNextCard(room, player);
    if (nextCard) {
      player.hand.push(nextCard);
    }

    const matchResult = this.resolveMatchEnd(room, opponent.hp <= 0 ? 'hp_zero' : undefined);
    const playResult = {
      roomId: room.roomId,
      actorUserId: userId,
      cardId,
      correct,
      effect,
      effectValue,
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
    if (!player || !opponent) return this.reject('not_in_room', 'Player is not in this room.');
    if (room.status !== 'active') return this.reject('room_not_active', 'Room is not active.');
    if (player.openedCardId !== cardId) {
      return this.reject('card_not_opened', 'Card is not opened.');
    }

    const cardIndex = player.hand.findIndex((card) => card.id === cardId);
    if (cardIndex === -1) return this.reject('card_not_in_hand', 'Card is not in your hand.');
    if (player.answeredCardIds.has(cardId)) {
      return this.reject('card_already_answered', 'Card was already answered.');
    }

    // Timeout is a wrong answer: 0 damage, 0 heal
    const correct = false;
    const effect: 'damage' | 'heal' | 'none' = 'none';
    const effectValue = 0;

    player.hand.splice(cardIndex, 1);
    player.answeredCardIds.add(cardId);
    player.openedCardId = undefined;

    const nextCard = this.drawNextCard(room, player);
    if (nextCard) {
      player.hand.push(nextCard);
    }

    const matchResult = this.resolveMatchEnd(room, opponent.hp <= 0 ? 'hp_zero' : undefined);
    const playResult = {
      roomId: room.roomId,
      actorUserId: userId,
      cardId,
      correct,
      effect,
      effectValue,
    };

    return { ok: true, room, playResult, matchResult };
  }

  surrender(room: InternalRoomState, userId: string): BattleActionResult<SurrenderSuccess> {
    const player = this.getPlayer(room, userId);
    if (!player) return this.reject('not_in_room', 'Player is not in this room.');
    if (room.status !== 'active') return this.reject('room_not_active', 'Room is not active.');
    const result = this.finish(room, 'surrender', this.getOpponent(room, userId)?.userId ?? null, userId);
    return { ok: true, room, matchResult: result };
  }

  finishDisconnected(room: InternalRoomState, userId: string): MatchResultPayload {
    const disconnected = this.getPlayer(room, userId);
    const opponent = this.getOpponent(room, userId);
    if (!disconnected || !opponent) {
      throw new Error('Cannot finish disconnect for a non-member.');
    }
    if (!opponent.connected) {
      return this.finish(room, 'disconnect', null, null);
    }
    return this.finish(room, 'disconnect', opponent.userId, disconnected.userId);
  }

  buildPublicState(room: InternalRoomState, userId: string): PublicBattleState {
    const self = this.getPlayer(room, userId);
    const opponent = this.getOpponent(room, userId);
    if (!self || !opponent) {
      throw new Error('Cannot build battle state for non-member.');
    }

    return {
      roomId: room.roomId,
      status: room.status,
      mode: room.mode,
      target: room.target,
      self: {
        userId: self.userId,
        displayName: self.displayName,
        loadout: self.loadout,
        role: self.role,
        hp: self.hp,
        points: self.points,
        hand: self.hand.map(toPublicCard),
        openedCardId: self.openedCardId,
        answeredCardIds: Array.from(self.answeredCardIds),
        connected: self.connected,
      },
      opponent: {
        userId: opponent.userId,
        displayName: opponent.displayName,
        loadout: opponent.loadout,
        role: opponent.role,
        hp: opponent.hp,
        points: opponent.points,
        connected: opponent.connected,
      },
      phase: this.phaseFor(room, self.openedCardId),
      outcome: room.result ? this.outcomeFor(room.result, userId) : undefined,
    };
  }

  private createPlayer(
    seed: BattlePlayerSeed,
    role: BattleRole,
    sharedQueue: InternalRoomState['sharedQueue'],
  ): InternalPlayerState {
    const hand = this.dealer.createStartingHand(sharedQueue);
    return {
      userId: seed.userId,
      displayName: seed.displayName,
      loadout: seed.loadout,
      socketId: null,
      role,
      hp: GameEngine.STARTING_HP,
      points: 0,
      hand,
      answeredCardIds: new Set<string>(),
      nextDrawIndex: hand.length,
      connected: true,
    };
  }

  private resolveMatchEnd(
    room: InternalRoomState,
    preferredReason?: FinishReason,
  ): MatchResultPayload | undefined {
    if (room.result) return room.result;
    if (preferredReason === 'hp_zero') {
      return this.finishByComparison(room, 'hp_zero');
    }
    return undefined;
  }

  private finishByComparison(room: InternalRoomState, reason: FinishReason): MatchResultPayload {
    const { playerA, playerB } = room.players;
    if (playerA.hp > playerB.hp) return this.finish(room, reason, playerA.userId, playerB.userId);
    if (playerB.hp > playerA.hp) return this.finish(room, reason, playerB.userId, playerA.userId);
    if (playerA.points > playerB.points) return this.finish(room, reason, playerA.userId, playerB.userId);
    if (playerB.points > playerA.points) return this.finish(room, reason, playerB.userId, playerA.userId);
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
      mode: room.mode,
      target: room.target,
      outcome: reason === 'surrender' ? 'surrender' : winnerUserId ? 'win' : 'draw',
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

  private outcomeFor(result: MatchResultPayload, userId: string): PublicBattleState['outcome'] {
    if (result.reason === 'surrender' && result.loserUserId === userId) return 'surrender';
    if (!result.winnerUserId) return 'draw';
    return result.winnerUserId === userId ? 'win' : 'lose';
  }

  private phaseFor(room: InternalRoomState, openedCardId?: string): PublicBattleState['phase'] {
    if (room.status === 'finished') return 'finished';
    if (room.status === 'waiting') return 'waiting';
    if (openedCardId) return 'card_opened';
    return 'active';
  }

  private drawNextCard(
    room: InternalRoomState,
    player: InternalPlayerState,
  ): InternalCard | undefined {
    if (room.sharedQueue.length === 0) return undefined;
    const absoluteIndex = player.nextDrawIndex;
    const source = room.sharedQueue[absoluteIndex % room.sharedQueue.length];
    player.nextDrawIndex += 1;
    return {
      ...source,
      id:
        absoluteIndex < room.sharedQueue.length
          ? source.id
          : `card_r${absoluteIndex + 1}`,
      options: [...source.options],
    };
  }

  getPlayer(room: InternalRoomState, userId: string): InternalPlayerState | undefined {
    return Object.values(room.players).find((player) => player.userId === userId);
  }

  getOpponent(room: InternalRoomState, userId: string): InternalPlayerState | undefined {
    return Object.values(room.players).find((player) => player.userId !== userId);
  }

  private clampHp(value: number): number {
    return Math.max(0, Math.min(GameEngine.MAX_HP, value));
  }

  private reject(reason: string, message: string): BattleActionResult<never> {
    return { ok: false, reason, message, recoverable: true };
  }
}
