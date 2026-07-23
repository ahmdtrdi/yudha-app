import { RoomManager } from './room-manager';
import { GameEngine } from '../engine/game-engine';
import { QuestionDealer } from '../engine/question-dealer';
import type { InternalCard } from '../questions/question.types';
import type { GamePlayerProfile } from '../profiles/game-player-profile.service';

const makeCards = (count: number): InternalCard[] =>
  Array.from({ length: count }, (_, i) => ({
    id: `card_${i + 1}`,
    sourceQuestionId: `question_${i + 1}`,
    prompt: `Question ${i + 1}`,
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
  characterId = 'character-basic-squire',
  towerId = 'tower-garda-biru',
): GamePlayerProfile => ({
  userId,
  displayName: `Display ${userId}`,
  target,
  loadout: { characterId, towerId },
});

describe('RoomManager', () => {
  let manager: RoomManager;
  const cards = makeCards(12);

  beforeEach(() => {
    const engine = new GameEngine();
    const dealer = new QuestionDealer();
    manager = new RoomManager(engine, dealer);
  });

  // ─── registerSocket ───

  describe('registerSocket', () => {
    it('maps socket to user', () => {
      manager.registerSocket('socket-a', 'user-a');

      expect(manager.getUserIdForSocket('socket-a')).toBe('user-a');
    });

    it('updates player socketId and connected state on reconnect', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      // Simulate disconnect and reconnect
      manager.disconnectSocket('socket-a');
      manager.registerSocket('socket-a2', 'user-a');

      const room = manager.getRoomForUser('user-a');
      expect(room).toBeDefined();
      expect(room!.players.playerA.connected).toBe(true);
      expect(room!.players.playerA.socketId).toBe('socket-a2');
    });
  });

  // ─── disconnectSocket ───

  describe('disconnectSocket', () => {
    it('ignores a stale socket after the same user reconnects', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue(profile('user-a'), 'socket-a', 'casual', cards);
      manager.joinQueue(profile('user-b'), 'socket-b', 'casual', cards);

      manager.registerSocket('socket-a-new', 'user-a');
      const stale = manager.disconnectSocket('socket-a');
      const room = manager.getRoomForUser('user-a')!;

      expect(stale.type).toBe('none');
      expect(room.players.playerA.connected).toBe(true);
      expect(room.players.playerA.socketId).toBe('socket-a-new');
    });

    it('returns "none" for unknown socket', () => {
      const result = manager.disconnectSocket('unknown-socket');
      expect(result.type).toBe('none');
    });

    it('returns "queued_removed" when disconnecting a queued user', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);

      const result = manager.disconnectSocket('socket-a');
      expect(result.type).toBe('queued_removed');
    });

    it('returns "active_presence" when disconnecting a player in a match', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      const result = manager.disconnectSocket('socket-a');

      expect(result.type).toBe('active_presence');
      if (result.type === 'active_presence') {
        expect(result.userId).toBe('user-a');
        expect(result.room.players.playerA.connected).toBe(false);
        expect(result.room.players.playerA.socketId).toBeNull();
      }
    });
  });

  // ─── joinQueue ───

  describe('joinQueue', () => {
    it('isolates queues by exact target while preserving FIFO', () => {
      manager.registerSocket('socket-cpns-a', 'cpns-a');
      manager.registerSocket('socket-bumn-a', 'bumn-a');
      manager.registerSocket('socket-cpns-b', 'cpns-b');

      manager.joinQueue(
        profile('cpns-a', 'cpns'),
        'socket-cpns-a',
        'casual',
        cards,
      );
      manager.joinQueue(
        profile('bumn-a', 'bumn'),
        'socket-bumn-a',
        'casual',
        cards,
      );
      const result = manager.joinQueue(
        profile('cpns-b', 'cpns'),
        'socket-cpns-b',
        'casual',
        cards,
      );

      expect(result.match?.playerA.userId).toBe('cpns-a');
      expect(result.match?.playerB.userId).toBe('cpns-b');
      expect(result.match?.room.target).toBe('cpns');
      expect(manager.queuePositionFor('bumn-a', 'bumn', 'casual')).toBe(1);
    });

    it('isolates ranked and casual queues for the same target', () => {
      manager.registerSocket('socket-ranked-a', 'ranked-a');
      manager.registerSocket('socket-casual-a', 'casual-a');
      manager.registerSocket('socket-ranked-b', 'ranked-b');

      manager.joinQueue(
        profile('ranked-a'),
        'socket-ranked-a',
        'ranked',
        cards,
      );
      manager.joinQueue(
        profile('casual-a'),
        'socket-casual-a',
        'casual',
        cards,
      );
      const result = manager.joinQueue(
        profile('ranked-b'),
        'socket-ranked-b',
        'ranked',
        cards,
      );

      expect(result.match?.playerA.userId).toBe('ranked-a');
      expect(result.match?.room.mode).toBe('ranked');
      expect(manager.queuePositionFor('casual-a', 'cpns', 'casual')).toBe(1);
    });

    it('snapshots authoritative names and character/tower loadouts', () => {
      const playerA = profile(
        'user-a',
        'bumn',
        'character-rare-ignis',
        'tower-benteng-bara',
      );
      const playerB = profile(
        'user-b',
        'bumn',
        'character-basic-pip',
        'tower-garda-biru',
      );

      manager.joinQueue(playerA, 'socket-a', 'ranked', cards);
      const result = manager.joinQueue(
        playerB,
        'socket-b',
        'ranked',
        cards,
      );
      const room = result.match!.room;

      expect(room.players.playerA.displayName).toBe('Display user-a');
      expect(room.players.playerA.loadout).toEqual(playerA.loadout);
      expect(room.players.playerB.displayName).toBe('Display user-b');
      expect(room.players.playerB.loadout).toEqual(playerB.loadout);

      const publicState = new GameEngine().buildPublicState(room, 'user-a');
      expect(publicState.mode).toBe('ranked');
      expect(publicState.target).toBe('bumn');
      expect(publicState.self.displayName).toBe('Display user-a');
      expect(publicState.self.loadout).toEqual(playerA.loadout);
      expect(publicState.opponent.displayName).toBe('Display user-b');
      expect(publicState.opponent.loadout).toEqual(playerB.loadout);
    });

    it('queues a solo player without creating a match', () => {
      manager.registerSocket('socket-a', 'user-a');

      const result = manager.joinQueue('user-a', 'socket-a', 'casual', cards);

      expect(result.match).toBeUndefined();
      expect(result.queueDepth).toBe(1);
    });

    it('matches two queued players', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');

      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      const result = manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      expect(result.match).toBeDefined();
      expect(result.match!.playerA.userId).toBe('user-a');
      expect(result.match!.playerB.userId).toBe('user-b');
      expect(result.match!.room.status).toBe('active');
      expect(result.queueDepth).toBe(0);
    });

    it('rejects a user already in an active room', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      // user-a is now in an active match
      const result = manager.joinQueue('user-a', 'socket-a', 'casual', cards);

      expect(result.rejected).toBe('already_in_active_room');
    });

    it('updates socketId if user is already queued', () => {
      manager.registerSocket('socket-a', 'user-a');

      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      const result = manager.joinQueue('user-a', 'socket-a2', 'casual', cards);

      expect(result.match).toBeUndefined();
      expect(result.queued.socketId).toBe('socket-a2');
    });

    it('creates room with reserve cards when provided', () => {
      const reserve = makeCards(4).map((c, i) => ({ ...c, id: `reserve_${i}` }));
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');

      manager.joinQueue('user-a', 'socket-a', 'casual', cards, reserve);
      const result = manager.joinQueue('user-b', 'socket-b', 'casual', cards, reserve);

      expect(result.match).toBeDefined();
      expect(result.match!.room.sharedQueue.length).toBeGreaterThan(cards.length);
    });
  });

  // ─── cancelQueue ───

  describe('cancelQueue', () => {
    it('removes a user from the queue', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);

      const removed = manager.cancelQueue('user-a');

      expect(removed).toBe(true);
    });

    it('returns false when user is not in queue', () => {
      const removed = manager.cancelQueue('nonexistent');
      expect(removed).toBe(false);
    });
  });

  // ─── createBotRoom ───

  describe('createBotRoom', () => {
    it('creates a room with bot as playerB', () => {
      const room = manager.createBotRoom('user-a', 'socket-a', cards);

      expect(room.status).toBe('active');
      expect(room.players.playerA.userId).toBe('user-a');
      expect(room.players.playerA.socketId).toBe('socket-a');
      expect(room.players.playerB.userId).toBe('bot');
      expect(room.players.playerB.socketId).toBeNull();
      expect(room.players.playerB.connected).toBe(true);
      expect(room.roomId).toContain('bot');
    });

    it('registers room for the user', () => {
      const room = manager.createBotRoom('user-a', 'socket-a', cards);

      expect(manager.getRoomForUser('user-a')).toBe(room);
    });

    it('supports reserve cards', () => {
      const reserve = makeCards(4).map((c, i) => ({ ...c, id: `reserve_${i}` }));
      const room = manager.createBotRoom('user-a', 'socket-a', cards, reserve);

      expect(room.sharedQueue.length).toBeGreaterThan(cards.length);
    });
  });

  // ─── Lookups ───

  describe('room lookups', () => {
    it('getRoom returns the room by ID', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      const { match } = manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      expect(manager.getRoom(match!.room.roomId)).toBe(match!.room);
    });

    it('getRoom returns undefined for nonexistent room', () => {
      expect(manager.getRoom('nonexistent')).toBeUndefined();
    });

    it('getRoomForUser returns the room the user is in', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      const { match } = manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      expect(manager.getRoomForUser('user-a')).toBe(match!.room);
    });

    it('getRoomForUser returns undefined for non-matched user', () => {
      expect(manager.getRoomForUser('nonexistent')).toBeUndefined();
    });

    it('getSocketIdForUser returns socketId from room player', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      expect(manager.getSocketIdForUser('user-a')).toBe('socket-a');
    });

    it('getSocketIdForUser falls back to queue entry socketId', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);

      expect(manager.getSocketIdForUser('user-a')).toBe('socket-a');
    });

    it('listRoomUsers returns both player userIds', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      const { match } = manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      const users = manager.listRoomUsers(match!.room);
      expect(users).toEqual(['user-a', 'user-b']);
    });
  });

  // ─── Cleanup ───

  describe('scheduleCleanup / destroyRoom', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('destroyRoom removes room and user mappings', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      const { match } = manager.joinQueue('user-b', 'socket-b', 'casual', cards);

      manager.destroyRoom(match!.room.roomId);

      expect(manager.getRoom(match!.room.roomId)).toBeUndefined();
      expect(manager.getRoomForUser('user-a')).toBeUndefined();
      expect(manager.getRoomForUser('user-b')).toBeUndefined();
    });

    it('scheduleCleanup destroys the room after delay', () => {
      manager.registerSocket('socket-a', 'user-a');
      manager.registerSocket('socket-b', 'user-b');
      manager.joinQueue('user-a', 'socket-a', 'casual', cards);
      const { match } = manager.joinQueue('user-b', 'socket-b', 'casual', cards);
      const roomId = match!.room.roomId;

      manager.scheduleCleanup(roomId, 2000);

      // Room still exists before delay
      expect(manager.getRoom(roomId)).toBeDefined();

      jest.advanceTimersByTime(2000);

      // Room destroyed after delay
      expect(manager.getRoom(roomId)).toBeUndefined();
    });

    it('destroyRoom is safe to call on nonexistent room', () => {
      expect(() => manager.destroyRoom('nonexistent')).not.toThrow();
    });
  });
});
