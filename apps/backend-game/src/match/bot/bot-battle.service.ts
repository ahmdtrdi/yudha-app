import { Injectable, Logger } from '@nestjs/common';
import { GameEngine } from '../engine/game-engine';
import { RoomManager } from '../rooms/room-manager';
import { QuestionService } from '../questions/question.service';
import { MatchResultService } from '../results/match-result.service';
import type { InternalRoomState } from '../engine/battle.types';
import type { InternalCard } from '../questions/question.types';
import type { MatchEmit, MatchServiceResult } from '../match.service';
import { SERVER_MATCH_EVENTS } from '../../../../../contracts/match.events';
import {
  GamePlayerProfileService,
  type GamePlayerProfile,
} from '../profiles/game-player-profile.service';

const BOT_MIN_DELAY_MS = 3300;
const BOT_MAX_DELAY_MS = 5900;
const BOT_USER_ID = 'bot';

@Injectable()
export class BotBattleService {
  private readonly logger = new Logger(BotBattleService.name);
  private readonly botTimers = new Map<string, ReturnType<typeof setTimeout>>();
  private emitCallback: ((result: MatchServiceResult) => void) | null = null;
  private roundBreakCallback: ((room: InternalRoomState) => void) | null = null;

  constructor(
    private readonly engine: GameEngine,
    private readonly rooms: RoomManager,
    private readonly questions: QuestionService,
    private readonly matchResultService: MatchResultService,
    private readonly profiles: GamePlayerProfileService,
  ) {}

  /** Called by the gateway once the Server instance is available. */
  setEmitCallback(callback: (result: MatchServiceResult) => void): void {
    this.emitCallback = callback;
  }

  setRoundBreakCallback(callback: (room: InternalRoomState) => void): void {
    this.roundBreakCallback = callback;
  }

  /**
   * Create a bot match: room creation + schedule the bot's first turn.
   * Returns the created room so the caller can emit match_found + initial state.
   * Uses the same Supabase-backed question pool as PvP matches.
   */
  async createBotMatch(
    playerOrUserId: GamePlayerProfile | string,
    socketId: string,
  ): Promise<InternalRoomState> {
    const player =
      typeof playerOrUserId === 'string'
        ? await this.profiles.getProfile(playerOrUserId)
        : playerOrUserId;
    const cards = await this.questions.getMatchQuestionPool(player.target);
    const room = this.rooms.createBotRoom(
      player,
      this.profiles.botProfile(player.target),
      socketId,
      cards,
    );
    this.logger.log(
      `Bot match created: room=${room.roomId} player=${player.userId} target=${player.target}`,
    );
    this.scheduleNextBotTurn(room.roomId);
    return room;
  }

  /** Cancel any pending bot timer for a room. Safe to call multiple times. */
  cancelBotSchedule(roomId: string): void {
    const timer = this.botTimers.get(roomId);
    if (timer) {
      clearTimeout(timer);
      this.botTimers.delete(roomId);
      this.logger.log(`Bot schedule cancelled: room=${roomId}`);
    }
  }

  resumeBotSchedule(roomId: string): void {
    if (!this.botTimers.has(roomId)) {
      this.scheduleNextBotTurn(roomId);
    }
  }

  /** Check if a room is a bot match by inspecting playerB's userId. */
  isBotMatch(room: InternalRoomState): boolean {
    return room.players.playerB.userId === BOT_USER_ID;
  }

  private scheduleNextBotTurn(roomId: string): void {
    const delay =
      BOT_MIN_DELAY_MS + Math.random() * (BOT_MAX_DELAY_MS - BOT_MIN_DELAY_MS);
    const timer = setTimeout(() => this.executeBotTurn(roomId), delay);
    this.botTimers.set(roomId, timer);
  }

  private async executeBotTurn(roomId: string): Promise<void> {
    this.botTimers.delete(roomId);

    const room = this.rooms.getRoom(roomId);
    if (!room || room.status !== 'active') {
      return; // Match already ended — bail silently
    }

    const botPlayer = room.players.playerB;
    if (botPlayer.userId !== BOT_USER_ID) {
      this.logger.error(`executeBotTurn called on non-bot room: ${roomId}`);
      return;
    }

    // Select a card: prefer damage, fallback to first available
    const card = this.selectBotCard(botPlayer.hand);
    if (!card) {
      // No cards in hand — skip turn, reschedule
      this.logger.warn(
        `Bot has no cards in hand: room=${roomId}, rescheduling`,
      );
      this.scheduleNextBotTurn(roomId);
      return;
    }

    // Step 1: Open the card
    const openResult = this.engine.openCard(room, BOT_USER_ID, card.id);
    if (!openResult.ok) {
      this.logger.warn(
        `Bot open_card failed: room=${roomId} reason=${openResult.reason}`,
      );
      this.scheduleNextBotTurn(roomId);
      return;
    }

    // Step 2: Play the card with the correct answer
    const playResult = this.engine.playCard(
      room,
      BOT_USER_ID,
      card.id,
      card.correctOptionIndex,
    );
    if (!playResult.ok) {
      this.logger.warn(
        `Bot play_card failed: room=${roomId} reason=${playResult.reason}`,
      );
      this.scheduleNextBotTurn(roomId);
      return;
    }

    // Build emits for the human player
    const emits: MatchEmit[] = [];
    const humanUserId = room.players.playerA.userId;
    const humanSocketId = this.rooms.getSocketIdForUser(humanUserId);

    if (humanSocketId) {
      // play_card_result for the bot's action
      emits.push({
        socketId: humanSocketId,
        event: SERVER_MATCH_EVENTS.playCardResult,
        payload: playResult.playResult,
      });

      // Updated game state for the human
      emits.push({
        socketId: humanSocketId,
        event: SERVER_MATCH_EVENTS.gameStateUpdate,
        payload: this.engine.buildPublicState(room, humanUserId),
      });
    }

    // Check if match ended
    if (playResult.matchResult) {
      this.cancelBotSchedule(roomId);
      await this.persistBotMatch(room);

      if (humanSocketId) {
        emits.push({
          socketId: humanSocketId,
          event: SERVER_MATCH_EVENTS.matchResult,
          payload: room.result,
        });
      }

      this.rooms.scheduleCleanup(roomId);
    } else if (room.roundStatus === 'break') {
      this.roundBreakCallback?.(room);
    } else {
      // Match continues — schedule next bot turn
      this.scheduleNextBotTurn(roomId);
    }

    // Emit everything to the human player
    if (this.emitCallback && emits.length > 0) {
      this.emitCallback({ emits });
    }
  }

  private selectBotCard(hand: InternalCard[]): InternalCard | undefined {
    return hand.find((c) => c.effect === 'damage') ?? hand[0] ?? undefined;
  }

  private async persistBotMatch(room: InternalRoomState): Promise<void> {
    try {
      const deltas = await this.matchResultService.finalizeMatch(room);
      if (deltas && room.result) {
        room.result.progressionPersisted = deltas.progressionApplied;
        room.result.finalState.playerA.ratingDelta = deltas.ratingDeltaA;
        room.result.finalState.playerA.coinsDelta = deltas.coinsDeltaA;
        room.result.finalState.playerB.ratingDelta = deltas.ratingDeltaB;
        room.result.finalState.playerB.coinsDelta = deltas.coinsDeltaB;
      } else if (room.result) {
        room.result.progressionPersisted = false;
      }
    } catch (error) {
      if (room.result) {
        room.result.progressionPersisted = false;
      }
      this.logger.error(
        `Failed to persist bot match ${room.roomId}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }
}
