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

@Injectable()
export class GameEngine {
  static readonly STARTING_HP = 100;
  static readonly MAX_HP = 100;
  private readonly dealer = new QuestionDealer();

  createRoom(roomId: string, playerAUserId: string, playerBUserId: string, sharedQueue: ReturnType<QuestionDealer['createSharedQueue']>): InternalRoomState {
    return {
      roomId,
      status: 'active',
      sharedQueue,
      startedAt: new Date(),
      players: {
        playerA: this.createPlayer(playerAUserId, 'playerA', sharedQueue),
        playerB: this.createPlayer(playerBUserId, 'playerB', sharedQueue),
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
    const nextCard = this.dealer.drawAt(room.sharedQueue, player.nextDrawIndex);
    if (nextCard) {
      player.hand.push(nextCard);
      player.nextDrawIndex += 1;
    }

    const matchResult = this.resolveMatchEnd(room, opponent.hp <= 0 ? 'hp_zero' : undefined);
    const playResult = {
      roomId: room.roomId,
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

  buildPublicState(room: InternalRoomState, userId: string): PublicBattleState {
    const self = this.getPlayer(room, userId);
    const opponent = this.getOpponent(room, userId);
    if (!self || !opponent) {
      throw new Error('Cannot build battle state for non-member.');
    }

    return {
      roomId: room.roomId,
      status: room.status,
      self: {
        userId: self.userId,
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
      hand: this.dealer.createStartingHand(sharedQueue),
      answeredCardIds: new Set<string>(),
      nextDrawIndex: QuestionDealer.HAND_SIZE,
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
    if (this.isQuestionExhausted(room)) {
      return this.finishByComparison(room, 'question_exhaustion');
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

  private isQuestionExhausted(room: InternalRoomState): boolean {
    const allDrawn =
      room.players.playerA.nextDrawIndex >= room.sharedQueue.length &&
      room.players.playerB.nextDrawIndex >= room.sharedQueue.length;
    const noPlayableCards =
      room.players.playerA.hand.length === 0 && room.players.playerB.hand.length === 0;
    const noOpenedCards =
      !room.players.playerA.openedCardId && !room.players.playerB.openedCardId;
    return allDrawn && noPlayableCards && noOpenedCards;
  }

  private getPlayer(room: InternalRoomState, userId: string): InternalPlayerState | undefined {
    return Object.values(room.players).find((player) => player.userId === userId);
  }

  private getOpponent(room: InternalRoomState, userId: string): InternalPlayerState | undefined {
    return Object.values(room.players).find((player) => player.userId !== userId);
  }

  private clampHp(value: number): number {
    return Math.max(0, Math.min(GameEngine.MAX_HP, value));
  }

  private reject(reason: string, message: string): BattleActionResult<never> {
    return { ok: false, reason, message, recoverable: true };
  }
}
