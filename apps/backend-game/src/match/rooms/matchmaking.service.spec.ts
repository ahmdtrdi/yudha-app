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

describe('MatchmakingService Private rooms', () => {
  let rooms: RoomManager;
  let matchmaking: MatchmakingService;

  beforeEach(() => {
    jest.useFakeTimers();
    rooms = new RoomManager(new GameEngine(), new QuestionDealer());
    matchmaking = new MatchmakingService(rooms);
  });

  afterEach(() => {
    jest.clearAllTimers();
    jest.useRealTimers();
  });

  it('creates a secure-alphabet code with an exact fifteen-minute expiry', () => {
    const result = matchmaking.createPrivateRoom(
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

  it('retries a generated-code collision before reserving the next code', () => {
    const codeSource = matchmaking as unknown as {
      generateCode: () => string;
    };
    jest
      .spyOn(codeSource, 'generateCode')
      .mockReturnValueOnce('ABC234')
      .mockReturnValueOnce('ABC234')
      .mockReturnValueOnce('DEF567');

    const first = matchmaking.createPrivateRoom(profile('owner-a'), 'socket-a');
    const second = matchmaking.createPrivateRoom(
      profile('owner-b'),
      'socket-b',
    );

    expect(first.ok && first.reservation.code).toBe('ABC234');
    expect(second.ok && second.reservation.code).toBe('DEF567');
  });

  it('expires an unused code and notifies the coordinator callback', () => {
    const onExpiry = jest.fn();
    matchmaking.setExpiryCallback(onExpiry);
    const created = matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-owner',
    );
    if (!created.ok) throw new Error('Expected room creation');

    jest.advanceTimersByTime(MatchmakingService.PRIVATE_ROOM_TTL_MS);

    expect(onExpiry).toHaveBeenCalledWith(
      expect.objectContaining({ code: created.reservation.code }),
    );
    expect(matchmaking.hasPendingPrivateRoom('owner')).toBe(false);
  });

  it('consumes a code once and creates a Private battle with fixed roles', () => {
    const created = matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-owner',
    );
    if (!created.ok) throw new Error('Expected room creation');

    const joined = matchmaking.joinPrivateRoom(
      profile('friend'),
      'socket-friend',
      created.reservation.code,
      cards,
    );

    expect(joined.ok).toBe(true);
    if (!joined.ok) return;
    expect(joined.match.room.mode).toBe('private');
    expect(joined.match.room.players.playerA.userId).toBe('owner');
    expect(joined.match.room.players.playerB.userId).toBe('friend');
    expect(
      matchmaking.joinPrivateRoom(
        profile('other'),
        'socket-other',
        created.reservation.code,
        cards,
      ),
    ).toEqual({ ok: false, reason: 'room_code_invalid' });
  });

  it('hides self-join and cross-target failures behind room_code_invalid', () => {
    const created = matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-owner',
    );
    if (!created.ok) throw new Error('Expected room creation');

    expect(
      matchmaking.validateJoin(profile('owner'), created.reservation.code),
    ).toEqual({ ok: false, reason: 'room_code_invalid' });
    expect(
      matchmaking.validateJoin(
        profile('bumn-friend', 'bumn'),
        created.reservation.code,
      ),
    ).toEqual({ ok: false, reason: 'room_code_invalid' });
  });

  it('rejects creation while queued or already owning a code', () => {
    rooms.joinQueue(profile('queued'), 'socket-queued', 'casual', cards);
    expect(
      matchmaking.createPrivateRoom(profile('queued'), 'socket-queued'),
    ).toEqual({ ok: false, reason: 'matchmaking_conflict' });

    expect(
      matchmaking.createPrivateRoom(profile('owner'), 'socket-owner').ok,
    ).toBe(true);
    expect(
      matchmaking.createPrivateRoom(profile('owner'), 'socket-owner'),
    ).toEqual({ ok: false, reason: 'matchmaking_conflict' });

    rooms.joinQueue(profile('active-a'), 'socket-active-a', 'ranked', cards);
    rooms.joinQueue(profile('active-b'), 'socket-active-b', 'ranked', cards);
    expect(
      matchmaking.createPrivateRoom(profile('active-a'), 'socket-active-a'),
    ).toEqual({ ok: false, reason: 'matchmaking_conflict' });
  });

  it('allows only the owner to cancel an unused code', () => {
    const created = matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-owner',
    );
    if (!created.ok) throw new Error('Expected room creation');

    expect(
      matchmaking.cancelPrivateRoom('other', created.reservation.code),
    ).toEqual({ ok: false, reason: 'room_code_invalid' });
    expect(
      matchmaking.cancelPrivateRoom('owner', created.reservation.code).ok,
    ).toBe(true);
    expect(matchmaking.hasPendingPrivateRoom('owner')).toBe(false);
  });

  it('invalidates on the current owner socket disconnect but ignores a stale socket', () => {
    const created = matchmaking.createPrivateRoom(
      profile('owner'),
      'socket-old',
    );
    if (!created.ok) throw new Error('Expected room creation');
    matchmaking.rebindOwnerSocket('owner', 'socket-current');

    expect(matchmaking.disconnectOwner('owner', 'socket-old')).toBeUndefined();
    expect(matchmaking.hasPendingPrivateRoom('owner')).toBe(true);
    expect(matchmaking.disconnectOwner('owner', 'socket-current')).toEqual(
      expect.objectContaining({ code: created.reservation.code }),
    );
    expect(matchmaking.hasPendingPrivateRoom('owner')).toBe(false);
  });
});
