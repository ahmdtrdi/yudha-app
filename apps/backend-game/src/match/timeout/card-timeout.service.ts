import { Injectable, Logger } from '@nestjs/common';

const DEFAULT_TIMEOUT_SECONDS = 10;

/**
 * Service that manages per-card turn timeout timers in live matches.
 *
 * When a player opens a card, a timer is scheduled based on card.timeLimitSeconds.
 * If the player submits play_card before the timer fires, the timer is cancelled.
 * If the timer fires, the server auto-resolves the card as a timeout (0 effect)
 * and advances the battle state.
 */
@Injectable()
export class CardTimeoutService {
  private readonly logger = new Logger(CardTimeoutService.name);
  private readonly timers = new Map<string, ReturnType<typeof setTimeout>>();

  /**
   * Schedule a timeout timer for a player's opened card.
   */
  scheduleTimeout(
    roomId: string,
    userId: string,
    cardId: string,
    timeLimitSeconds: number | undefined,
    onTimeout: (roomId: string, userId: string, cardId: string) => void,
  ): void {
    this.clearTimeout(roomId, userId);

    const seconds = timeLimitSeconds && timeLimitSeconds > 0 ? timeLimitSeconds : DEFAULT_TIMEOUT_SECONDS;
    const key = this.buildKey(roomId, userId);

    this.logger.log(`Scheduled card timeout: room=${roomId} user=${userId} card=${cardId} (${seconds}s)`);

    const timer = setTimeout(() => {
      this.timers.delete(key);
      this.logger.log(`Card timeout fired: room=${roomId} user=${userId} card=${cardId}`);
      onTimeout(roomId, userId, cardId);
    }, seconds * 1000);

    this.timers.set(key, timer);
  }

  /**
   * Clear any pending card timeout timer for a user in a room.
   */
  clearTimeout(roomId: string, userId: string): void {
    const key = this.buildKey(roomId, userId);
    const existing = this.timers.get(key);
    if (existing) {
      clearTimeout(existing);
      this.timers.delete(key);
      this.logger.log(`Cleared card timeout: room=${roomId} user=${userId}`);
    }
  }

  /**
   * Cancel all pending card timeout timers for a room (e.g. on match end or disposal).
   */
  cancelAllTimersForRoom(roomId: string): void {
    const prefix = `${roomId}:`;
    for (const key of Array.from(this.timers.keys())) {
      if (key.startsWith(prefix)) {
        const timer = this.timers.get(key);
        if (timer) clearTimeout(timer);
        this.timers.delete(key);
      }
    }
    this.logger.log(`Cancelled all card timers for room=${roomId}`);
  }

  private buildKey(roomId: string, userId: string): string {
    return `${roomId}:${userId}`;
  }
}
