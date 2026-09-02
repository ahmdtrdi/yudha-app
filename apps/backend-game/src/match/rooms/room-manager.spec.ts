import { GameEngine } from '../engine/game-engine';
import { QuestionDealer } from '../engine/question-dealer';
import type { InternalCard } from '../questions/question.types';
import type { GamePlayerProfile } from '../profiles/game-player-profile.service';
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

const profile = (userId: string): GamePlayerProfile => ({
  userId,
  displayName: `Display ${userId}`,
  target: 'cpns',
  loadout: {
    characterId: 'character-basic-squire',
    towerId: 'tower-garda-biru',
  },
});

describe('RoomManager process-local room state', () => {
  let manager: RoomManager;

  beforeEach(() => {
    manager = new RoomManager(new GameEngine(), new QuestionDealer());
  });

  it('registers socket ownership without creating queue state', () => {
    expect(manager.registerSocket('socket-a', 'user-a')).toEqual({
      type: 'registered',
      userId: 'user-a',
    });
    expect(manager.getUserIdForSocket('socket-a')).toBe('user-a');
    expect(manager.disconnectSocket('socket-a')).toEqual({ type: 'none' });
  });

  it('creates a public room from an already coordinated pair', () => {
    const room = manager.createPublicRoom(
      { ...profile('user-a'), socketId: 'socket-a' },
      { ...profile('user-b'), socketId: 'socket-b' },
      'ranked',
      cards,
    );

    expect(room.mode).toBe('ranked');
    expect(room.target).toBe('cpns');
    expect(room.players.playerA.displayName).toBe('Display user-a');
    expect(room.players.playerB.socketId).toBe('socket-b');
    expect(manager.getRoomForUser('user-a')).toBe(room);
    expect(manager.getRoom(room.roomId)).toBe(room);
  });

  it('creates Private and Bot rooms with their expected roles', () => {
    const privateRoom = manager.createPrivateRoom(
      { ...profile('owner'), socketId: 'socket-owner' },
      { ...profile('friend'), socketId: 'socket-friend' },
      cards,
    );
    const botRoom = manager.createBotRoom(
      profile('solo'),
      { ...profile('bot'), displayName: 'BOT YUDHA' },
      'socket-solo',
      cards,
    );

    expect(privateRoom.mode).toBe('private');
    expect(privateRoom.players.playerA.userId).toBe('owner');
    expect(botRoom.mode).toBe('bot');
    expect(botRoom.players.playerB.userId).toBe('bot');
    expect(botRoom.players.playerB.socketId).toBeNull();
  });

  it('rebinds an active player and ignores the stale socket disconnect', () => {
    const room = manager.createPublicRoom(
      { ...profile('user-a'), socketId: 'socket-old' },
      { ...profile('user-b'), socketId: 'socket-b' },
      'casual',
      cards,
    );
    manager.registerSocket('socket-old', 'user-a');
    manager.registerSocket('socket-b', 'user-b');

    expect(manager.registerSocket('socket-new', 'user-a').type).toBe(
      'active_reconnect',
    );
    expect(manager.disconnectSocket('socket-old').type).toBe('none');
    expect(room.players.playerA.connected).toBe(true);
    expect(room.players.playerA.socketId).toBe('socket-new');
  });

  it('marks the current socket disconnected for presence handling', () => {
    const room = manager.createPublicRoom(
      { ...profile('user-a'), socketId: 'socket-a' },
      { ...profile('user-b'), socketId: 'socket-b' },
      'casual',
      cards,
    );
    manager.registerSocket('socket-a', 'user-a');

    expect(manager.disconnectSocket('socket-a')).toEqual({
      type: 'active_presence',
      room,
      userId: 'user-a',
    });
    expect(room.players.playerA.connected).toBe(false);
    expect(room.players.playerA.socketId).toBeNull();
  });

  it('destroys room and user routing after the cleanup delay', () => {
    jest.useFakeTimers();
    const room = manager.createPublicRoom(
      { ...profile('user-a'), socketId: 'socket-a' },
      { ...profile('user-b'), socketId: 'socket-b' },
      'casual',
      cards,
    );

    manager.scheduleCleanup(room.roomId, 2_000);
    jest.advanceTimersByTime(2_000);

    expect(manager.getRoom(room.roomId)).toBeUndefined();
    expect(manager.getRoomForUser('user-a')).toBeUndefined();
    expect(manager.getRoomForUser('user-b')).toBeUndefined();
    jest.useRealTimers();
  });
});
