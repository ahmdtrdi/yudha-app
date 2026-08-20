import { Injectable } from '@nestjs/common';
import { randomInt, randomUUID } from 'node:crypto';
import type { BattleTarget } from '../../contracts/battle-state';
import { GameCoordinationService } from '../../redis/game-coordination.service';
import type { RedisPrivateReservation } from '../../redis/game-coordination.types';
import type { InternalRoomState } from '../engine/battle.types';
import type { InternalCard } from '../questions/question.types';
import type { GamePlayerProfile } from '../profiles/game-player-profile.service';
import { RoomManager } from './room-manager';
import type { RoomParticipant } from './room.types';

const PRIVATE_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const PRIVATE_CODE_LENGTH = 6;
const MAX_CODE_GENERATION_ATTEMPTS = 10;

export type PrivateReservation = {
  code: string;
  owner: RoomParticipant & { instanceId: string };
  target: BattleTarget;
  createdAt: Date;
  expiresAt: Date;
};

export type PrivateMatchCreated = {
  code: string;
  room: InternalRoomState;
  playerA: RoomParticipant;
  playerB: RoomParticipant;
  ownerInstanceId: string;
};

export type PrivateMatchmakingFailure =
  | 'matchmaking_conflict'
  | 'room_code_invalid'
  | 'code_generation_failed'
  | 'queue_unavailable';

@Injectable()
export class MatchmakingService {
  static readonly PRIVATE_ROOM_TTL_MS = 15 * 60 * 1000;

  private expiryCallback: ((reservation: PrivateReservation) => void) | null =
    null;
  private readonly expiryTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();

  constructor(
    readonly rooms: RoomManager,
    private readonly coordination: GameCoordinationService,
  ) {}

  setExpiryCallback(callback: (reservation: PrivateReservation) => void): void {
    this.expiryCallback = callback;
  }

  async hasPendingPrivateRoom(userId: string): Promise<boolean> {
    return Boolean(
      await this.coordination.getPrivateReservationForOwner(userId),
    );
  }

  async createPrivateRoom(
    profile: GamePlayerProfile,
    socketId: string,
  ): Promise<
    | { ok: true; reservation: PrivateReservation }
    | { ok: false; reason: PrivateMatchmakingFailure }
  > {
    if (this.rooms.getRoomForUser(profile.userId)?.status === 'active') {
      return { ok: false, reason: 'matchmaking_conflict' };
    }

    for (
      let attempt = 0;
      attempt < MAX_CODE_GENERATION_ATTEMPTS;
      attempt += 1
    ) {
      const code = this.generateCode();
      const result = await this.coordination.createPrivateReservation(
        profile,
        socketId,
        code,
      );
      if (result === 'unavailable') {
        return { ok: false, reason: 'queue_unavailable' };
      }
      if (result === 'conflict') {
        return { ok: false, reason: 'matchmaking_conflict' };
      }
      if (result === 'collision') continue;

      const stored = await this.coordination.getPrivateReservation(code);
      if (!stored) return { ok: false, reason: 'queue_unavailable' };
      const reservation = this.fromRedis(stored);
      this.scheduleExpiry(reservation);
      return { ok: true, reservation };
    }
    return { ok: false, reason: 'code_generation_failed' };
  }

  async validateJoin(
    profile: GamePlayerProfile,
    code: string,
  ): Promise<
    | { ok: true; reservation: PrivateReservation }
    | { ok: false; reason: PrivateMatchmakingFailure }
  > {
    const reservation = await this.coordination.getPrivateReservation(code);
    if (
      !reservation ||
      reservation.owner.userId === profile.userId ||
      reservation.target !== profile.target
    ) {
      return { ok: false, reason: 'room_code_invalid' };
    }
    if (this.rooms.getRoomForUser(profile.userId)?.status === 'active') {
      return { ok: false, reason: 'matchmaking_conflict' };
    }
    return { ok: true, reservation: this.fromRedis(reservation) };
  }

  async joinPrivateRoom(
    profile: GamePlayerProfile,
    socketId: string,
    code: string,
    cards: InternalCard[],
  ): Promise<
    | { ok: true; match: PrivateMatchCreated }
    | { ok: false; reason: PrivateMatchmakingFailure }
  > {
    const validation = await this.validateJoin(profile, code);
    if (!validation.ok) return validation;

    const consumed = await this.coordination.consumePrivateReservation(
      profile,
      code,
      randomUUID(),
      validation.reservation.owner.userId,
      validation.reservation.owner.instanceId,
    );
    if (consumed.type === 'unavailable') {
      return { ok: false, reason: 'queue_unavailable' };
    }
    if (consumed.type === 'conflict') {
      return { ok: false, reason: 'matchmaking_conflict' };
    }
    if (consumed.type !== 'joined') {
      return { ok: false, reason: 'room_code_invalid' };
    }

    this.clearExpiry(code);
    const reservation = this.fromRedis(consumed.reservation);
    const playerB: RoomParticipant = { ...profile, socketId };
    const room = this.rooms.createPrivateRoom(
      reservation.owner,
      playerB,
      cards,
    );
    return {
      ok: true,
      match: {
        code,
        room,
        playerA: reservation.owner,
        playerB,
        ownerInstanceId: reservation.owner.instanceId,
      },
    };
  }

  async cancelPrivateRoom(
    ownerUserId: string,
    code: string,
  ): Promise<
    | { ok: true; reservation: PrivateReservation }
    | { ok: false; reason: 'room_code_invalid' | 'queue_unavailable' }
  > {
    if (!this.coordination.available) {
      return { ok: false, reason: 'queue_unavailable' };
    }
    const reservation = await this.coordination.cancelPrivateReservation(
      ownerUserId,
      code,
    );
    if (!reservation) return { ok: false, reason: 'room_code_invalid' };
    this.clearExpiry(code);
    return { ok: true, reservation: this.fromRedis(reservation) };
  }

  async rebindOwnerSocket(userId: string, socketId: string): Promise<void> {
    const reservation =
      await this.coordination.getPrivateReservationForOwner(userId);
    if (reservation) {
      await this.coordination.updatePrivateOwnerSocket(reservation, socketId);
    }
  }

  async disconnectOwner(
    userId: string,
    socketId: string,
  ): Promise<PrivateReservation | undefined> {
    const reservation =
      await this.coordination.getPrivateReservationForOwner(userId);
    if (!reservation || reservation.owner.socketId !== socketId)
      return undefined;
    const cancelled = await this.coordination.cancelPrivateReservation(
      userId,
      reservation.code,
    );
    if (!cancelled) return undefined;
    this.clearExpiry(reservation.code);
    return this.fromRedis(cancelled);
  }

  private scheduleExpiry(reservation: PrivateReservation): void {
    this.clearExpiry(reservation.code);
    const timer = setTimeout(
      () => {
        this.expiryTimers.delete(reservation.code);
        this.expiryCallback?.(reservation);
      },
      Math.max(0, reservation.expiresAt.getTime() - Date.now()),
    );
    timer.unref?.();
    this.expiryTimers.set(reservation.code, timer);
  }

  private clearExpiry(code: string): void {
    const timer = this.expiryTimers.get(code);
    if (timer) clearTimeout(timer);
    this.expiryTimers.delete(code);
  }

  private fromRedis(reservation: RedisPrivateReservation): PrivateReservation {
    return {
      ...reservation,
      createdAt: new Date(reservation.createdAt),
      expiresAt: new Date(reservation.expiresAt),
    };
  }

  private generateCode(): string {
    let code = '';
    for (let index = 0; index < PRIVATE_CODE_LENGTH; index += 1) {
      code += PRIVATE_CODE_ALPHABET[randomInt(PRIVATE_CODE_ALPHABET.length)];
    }
    return code;
  }
}
