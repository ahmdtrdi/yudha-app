import { Injectable } from '@nestjs/common';
import { randomInt } from 'node:crypto';
import type { BattleTarget } from '../../contracts/battle-state';
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
  owner: RoomParticipant;
  target: BattleTarget;
  createdAt: Date;
  expiresAt: Date;
};

export type PrivateMatchCreated = {
  code: string;
  room: InternalRoomState;
  playerA: RoomParticipant;
  playerB: RoomParticipant;
};

export type PrivateMatchmakingFailure =
  | 'matchmaking_conflict'
  | 'room_code_invalid'
  | 'code_generation_failed';

type ReservationRecord = PrivateReservation & {
  timer: ReturnType<typeof setTimeout>;
};

@Injectable()
export class MatchmakingService {
  static readonly PRIVATE_ROOM_TTL_MS = 15 * 60 * 1000;

  private readonly reservations = new Map<string, ReservationRecord>();
  private readonly ownerCodes = new Map<string, string>();
  private expiryCallback: ((reservation: PrivateReservation) => void) | null =
    null;

  constructor(readonly rooms: RoomManager) {}

  setExpiryCallback(callback: (reservation: PrivateReservation) => void): void {
    this.expiryCallback = callback;
  }

  hasPendingPrivateRoom(userId: string): boolean {
    return this.ownerCodes.has(userId);
  }

  createPrivateRoom(
    profile: GamePlayerProfile,
    socketId: string,
  ):
    | { ok: true; reservation: PrivateReservation }
    | { ok: false; reason: PrivateMatchmakingFailure } {
    if (this.hasMatchmakingConflict(profile.userId)) {
      return { ok: false, reason: 'matchmaking_conflict' };
    }

    const code = this.generateUniqueCode();
    if (!code) return { ok: false, reason: 'code_generation_failed' };

    const createdAt = new Date();
    const expiresAt = new Date(
      createdAt.getTime() + MatchmakingService.PRIVATE_ROOM_TTL_MS,
    );
    const reservation: PrivateReservation = {
      code,
      owner: { ...profile, socketId },
      target: profile.target,
      createdAt,
      expiresAt,
    };
    const timer = setTimeout(
      () => this.expire(code),
      Math.max(0, expiresAt.getTime() - Date.now()),
    );
    timer.unref?.();

    this.reservations.set(code, { ...reservation, timer });
    this.ownerCodes.set(profile.userId, code);
    return { ok: true, reservation };
  }

  validateJoin(
    profile: GamePlayerProfile,
    code: string,
  ): { ok: true } | { ok: false; reason: PrivateMatchmakingFailure } {
    const reservation = this.getUsableReservation(code);
    if (
      !reservation ||
      reservation.owner.userId === profile.userId ||
      reservation.target !== profile.target
    ) {
      return { ok: false, reason: 'room_code_invalid' };
    }
    if (this.hasMatchmakingConflict(profile.userId)) {
      return { ok: false, reason: 'matchmaking_conflict' };
    }
    return { ok: true };
  }

  joinPrivateRoom(
    profile: GamePlayerProfile,
    socketId: string,
    code: string,
    cards: InternalCard[],
  ):
    | { ok: true; match: PrivateMatchCreated }
    | { ok: false; reason: PrivateMatchmakingFailure } {
    const validation = this.validateJoin(profile, code);
    if (!validation.ok) return validation;

    const reservation = this.getUsableReservation(code);
    if (!reservation) return { ok: false, reason: 'room_code_invalid' };

    this.deleteReservation(reservation);
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
      },
    };
  }

  cancelPrivateRoom(
    ownerUserId: string,
    code: string,
  ):
    | { ok: true; reservation: PrivateReservation }
    | { ok: false; reason: 'room_code_invalid' } {
    const reservation = this.getUsableReservation(code);
    if (!reservation || reservation.owner.userId !== ownerUserId) {
      return { ok: false, reason: 'room_code_invalid' };
    }
    this.deleteReservation(reservation);
    return { ok: true, reservation };
  }

  rebindOwnerSocket(userId: string, socketId: string): void {
    const code = this.ownerCodes.get(userId);
    const reservation = code ? this.reservations.get(code) : undefined;
    if (reservation) reservation.owner.socketId = socketId;
  }

  disconnectOwner(
    userId: string,
    socketId: string,
  ): PrivateReservation | undefined {
    const code = this.ownerCodes.get(userId);
    const reservation = code ? this.reservations.get(code) : undefined;
    if (!reservation || reservation.owner.socketId !== socketId) {
      return undefined;
    }
    this.deleteReservation(reservation);
    return reservation;
  }

  private hasMatchmakingConflict(userId: string): boolean {
    return (
      this.ownerCodes.has(userId) ||
      this.rooms.isQueued(userId) ||
      this.rooms.getRoomForUser(userId)?.status === 'active'
    );
  }

  private getUsableReservation(code: string): ReservationRecord | undefined {
    const reservation = this.reservations.get(code);
    if (!reservation) return undefined;
    if (reservation.expiresAt.getTime() <= Date.now()) {
      this.expire(code);
      return undefined;
    }
    return reservation;
  }

  private expire(code: string): void {
    const reservation = this.reservations.get(code);
    if (!reservation) return;
    this.deleteReservation(reservation);
    this.expiryCallback?.(reservation);
  }

  private deleteReservation(reservation: ReservationRecord): void {
    clearTimeout(reservation.timer);
    this.reservations.delete(reservation.code);
    this.ownerCodes.delete(reservation.owner.userId);
  }

  private generateUniqueCode(): string | undefined {
    for (
      let attempt = 0;
      attempt < MAX_CODE_GENERATION_ATTEMPTS;
      attempt += 1
    ) {
      const code = this.generateCode();
      if (!this.reservations.has(code)) return code;
    }
    return undefined;
  }

  private generateCode(): string {
    let code = '';
    for (let index = 0; index < PRIVATE_CODE_LENGTH; index += 1) {
      code += PRIVATE_CODE_ALPHABET[randomInt(PRIVATE_CODE_ALPHABET.length)];
    }
    return code;
  }
}
