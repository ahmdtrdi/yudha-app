import { Injectable, Logger } from '@nestjs/common';
import type { MatchLogEntry, MatchLogAction, MatchLogRpcEntry } from './match-log.types';

/**
 * In-memory per-room buffer for match action logs.
 *
 * Actions are recorded during the match (zero DB writes mid-battle)
 * and flushed as a batch when the match ends, alongside the match_results
 * persistence call — preserving the PRD §6 Risk #1 constraint.
 */
@Injectable()
export class MatchLogBuffer {
  private readonly logger = new Logger(MatchLogBuffer.name);
  private readonly buffers = new Map<string, MatchLogEntry[]>();

  /** Append a log entry for a room. */
  record(roomId: string, userId: string, action: MatchLogAction, payload: Record<string, unknown>): void {
    if (!this.buffers.has(roomId)) {
      this.buffers.set(roomId, []);
    }
    this.buffers.get(roomId)!.push({
      userId,
      action,
      payload,
      createdAt: new Date(),
    });
  }

  /** Drain the buffer for a room and return the entries (for persistence). Clears the buffer. */
  drain(roomId: string): MatchLogEntry[] {
    const entries = this.buffers.get(roomId) ?? [];
    this.buffers.delete(roomId);
    return entries;
  }

  /** Convert drained entries to the shape expected by the Supabase RPC/insert. */
  toRpcEntries(entries: MatchLogEntry[]): MatchLogRpcEntry[] {
    return entries.map((entry) => ({
      user_id: entry.userId,
      action: entry.action,
      payload: entry.payload,
      created_at: entry.createdAt.toISOString(),
    }));
  }

  /** Safety cleanup — clear buffer for a room without persistence (e.g. both players disconnect). */
  clear(roomId: string): void {
    if (this.buffers.delete(roomId)) {
      this.logger.warn(`Buffer cleared without persistence: room=${roomId}`);
    }
  }

  /** Check if a room has any buffered entries. */
  has(roomId: string): boolean {
    return this.buffers.has(roomId);
  }
}
