import type { RedisPrivateReservation } from '../../redis/game-coordination.types';
import { GameEngine } from '../engine/game-engine';
import { QuestionDealer } from '../engine/question-dealer';
import type { InternalCard } from '../questions/question.types';
import type { GamePlayerProfile } from '../profiles/game-player-profile.service';
import { MatchmakingService } from './matchmaking.service';
import { RoomManager } from './room-manager';

const cards: InternalCard[] = Array.from({ length: 12 }, (_, index) => ({
  id: `card_${index + 1}`,
  sourceQuestionId: `question_${index + 1}`,
  prompt: `Question ${index + 1}`,
  options: ['A', 'B', 'C', 'D'],
  correctOptionIndex: 0,
  weight: 1,
  effect: 'damage' as const,
  damageValue: 10,
  healValue: 0,
  timeLimitSeconds: 30,
  category: ['twk', 'tiu', 'tkp'][index % 3],
  subcategory: ['pancasila_dan_ideologi', 'verbal', 'pelayanan_dan_integritas'][
    index % 3
  ],
}));

const profile = (
  userId: string,
  target: 'cpns' | 'bumn' = 'cpns',
): GamePlayerProfile => ({
  userId,
  displayName: `Display ${userId}`,
  target,
  loadout: {
    characterId: 'character-basic-squire',
    towerId: 'tower-garda-biru',
  },
});

class FakePrivateCoordination {
  available = true;
  private readonly byCode = new Map<string, RedisPrivateReservation>();
  private readonly byOwner = new Map<string, string>();

  async createPrivateReservation(
    owner: GamePlayerProfile,
    socketId: string,
    code: string,
  ) {
    this.purgeExpired();
    if (!this.available) return 'unavailable' as const;
    if (this.byOwner.has(owner.userId)) return 'conflict' as const;
    if (this.byCode.has(code)) return 'collision' as const;
    const now = Date.now();
    const reservation: RedisPrivateReservation = {
      code,
      owner: { ...owner, socketId, instanceId: 'instance-a' },
      target: owner.target,
      createdAt: now,
      expiresAt: now + MatchmakingService.PRIVATE_ROOM_TTL_MS,
    };
    this.byCode.set(code, reservation);
    this.byOwner.set(owner.userId, code);
    return 'created' as const;
  }

  async getPrivateReservation(code: string) {
    this.purgeExpired();
    return this.byCode.get(code);
  }

  async getPrivateReservationForOwner(userId: string) {
    this.purgeExpired();
    const code = this.byOwner.get(userId);
    return code ? this.byCode.get(code) : undefined;
  }

  async consumePrivateReservation(joining: GamePlayerProfile, code: string) {
    if (!this.available) return { type: 'unavailable' as const };
    const reservation = await this.getPrivateReservation(code);
    if (
      !reservation ||
      reservation.owner.userId === joining.userId ||
      reservation.target !== joining.target
    ) {
      return { type: 'invalid' as const };
    }
    this.byCode.delete(code);
    this.byOwner.delete(reservation.owner.userId);
    return { type: 'joined' as const, reservation };
  }

  async cancelPrivateReservation(ownerUserId: string, code: string) {
    if (!this.available) return undefined;
    const reservation = await this.getPrivateReservation(code);
    if (!reservation || reservation.owner.userId !== ownerUserId) {
      return undefined;
    }
    this.byCode.delete(code);
    this.byOwner.delete(ownerUserId);
    return reservation;
  }

  async updatePrivateOwnerSocket(
    reservation: RedisPrivateReservation,
    socketId: string,
  ) {
    const updated = {
      ...reservation,
      owner: { ...reservation.owner, socketId },
    };
    this.byCode.set(reservation.code, updated);
    return true;
  }

  private purgeExpired(): void {
    for (const [code, reservation] of this.byCode) {
      if (reservation.expiresAt <= Date.now()) {
        this.byCode.delete(code);
        this.byOwner.delete(reservation.owner.userId);
      }
    }
  }
}

describe('MatchmakingService Redis-backed Private rooms', () => {
  let rooms: RoomManager;
  let coordination: FakePrivateCoordination;
  let matchmaking: MatchmakingService;

  beforeEach(() => {
    jest.useFakeTimers();
    rooms = new RoomManager(new GameEngine(), new QuestionDealer());
    coordination = new FakePrivateCoordination();
    matchmaking = new MatchmakingService(rooms, coordination as never);
  });

  afterEach(() => {
    jest.clearAllTimers();
    jest.useRealTimers();
  });

  it('reserves an exact six-character code for exactly fifteen minutes', async () => {
    const result = await matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-owner',
    );

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.reservation.code).toMatch(
      /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/,
    );
    expect(
      result.reservation.expiresAt.getTime() -
        result.reservation.createdAt.getTime(),
    ).toBe(MatchmakingService.PRIVATE_ROOM_TTL_MS);
  });

  it('retries a code collision and prevents duplicate ownership', async () => {
    const codeSource = matchmaking as unknown as { generateCode: () => string };
    jest
      .spyOn(codeSource, 'generateCode')
      .mockReturnValueOnce('ABC234')
      .mockReturnValueOnce('ABC234')
      .mockReturnValueOnce('DEF567');

    const first = await matchmaking.createPrivateRoom(
      profile('owner-a'),
      'socket-a',
    );
    const second = await matchmaking.createPrivateRoom(
      profile('owner-b'),
      'socket-b',
    );
    const duplicate = await matchmaking.createPrivateRoom(
      profile('owner-a'),
      'socket-a',
    );

    expect(first.ok && first.reservation.code).toBe('ABC234');
    expect(second.ok && second.reservation.code).toBe('DEF567');
    expect(duplicate).toEqual({ ok: false, reason: 'matchmaking_conflict' });
  });

  it('expires an unused reservation and emits the local owner notification', async () => {
    const onExpiry = jest.fn();
    matchmaking.setExpiryCallback(onExpiry);
    const created = await matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-owner',
    );
    if (!created.ok) throw new Error('Expected room creation');

    jest.advanceTimersByTime(MatchmakingService.PRIVATE_ROOM_TTL_MS);

    expect(onExpiry).toHaveBeenCalledWith(
      expect.objectContaining({ code: created.reservation.code }),
    );
    await expect(matchmaking.hasPendingPrivateRoom('owner')).resolves.toBe(
      false,
    );
  });

  it('validates target and consumes a reservation only once', async () => {
    const created = await matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-owner',
    );
    if (!created.ok) throw new Error('Expected room creation');

    await expect(
      matchmaking.validateJoin(
        profile('wrong-target', 'bumn'),
        created.reservation.code,
      ),
    ).resolves.toEqual({ ok: false, reason: 'room_code_invalid' });

    const joined = await matchmaking.joinPrivateRoom(
      profile('friend'),
      'socket-friend',
      created.reservation.code,
      cards,
    );
    expect(joined.ok).toBe(true);
    if (joined.ok) {
      expect(joined.match.room.players.playerA.userId).toBe('owner');
      expect(joined.match.room.players.playerB.userId).toBe('friend');
    }
    await expect(
      matchmaking.joinPrivateRoom(
        profile('other'),
        'socket-other',
        created.reservation.code,
        cards,
      ),
    ).resolves.toEqual({ ok: false, reason: 'room_code_invalid' });
  });

  it('allows only the owner to cancel and cancels the current owner socket on disconnect', async () => {
    const created = await matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-old',
    );
    if (!created.ok) throw new Error('Expected room creation');

    await expect(
      matchmaking.cancelPrivateRoom('other', created.reservation.code),
    ).resolves.toEqual({ ok: false, reason: 'room_code_invalid' });
    await matchmaking.rebindOwnerSocket('owner', 'socket-current');
    await expect(
      matchmaking.disconnectOwner('owner', 'socket-old'),
    ).resolves.toBeUndefined();
    await expect(
      matchmaking.disconnectOwner('owner', 'socket-current'),
    ).resolves.toEqual(
      expect.objectContaining({ code: created.reservation.code }),
    );
  });

  it('returns queue_unavailable without creating a local fallback', async () => {
    coordination.available = false;
    await expect(
      matchmaking.createPrivateRoom(profile('owner'), 'socket-owner'),
    ).resolves.toEqual({ ok: false, reason: 'queue_unavailable' });
  });
});
