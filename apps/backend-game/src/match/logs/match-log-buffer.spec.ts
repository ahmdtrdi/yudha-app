import { MatchLogBuffer } from './match-log-buffer';

describe('MatchLogBuffer', () => {
  let buffer: MatchLogBuffer;

  beforeEach(() => {
    buffer = new MatchLogBuffer();
  });

  describe('record', () => {
    it('appends an entry to the room buffer', () => {
      buffer.record('room_1', 'user_a', 'open_card', { cardId: 'card_1' });

      expect(buffer.has('room_1')).toBe(true);
    });

    it('creates separate buffers for different rooms', () => {
      buffer.record('room_1', 'user_a', 'open_card', { cardId: 'card_1' });
      buffer.record('room_2', 'user_b', 'play_card', { cardId: 'card_2' });

      expect(buffer.has('room_1')).toBe(true);
      expect(buffer.has('room_2')).toBe(true);
    });

    it('appends multiple entries for the same room', () => {
      buffer.record('room_1', 'user_a', 'open_card', { cardId: 'card_1' });
      buffer.record('room_1', 'user_b', 'play_card', { cardId: 'card_2' });
      buffer.record('room_1', 'user_a', 'surrender', { atHpSelf: 50, atHpOpponent: 80 });

      const entries = buffer.drain('room_1');
      expect(entries).toHaveLength(3);
    });
  });

  describe('drain', () => {
    it('returns all entries for a room and clears the buffer', () => {
      buffer.record('room_1', 'user_a', 'open_card', { cardId: 'card_1' });
      buffer.record('room_1', 'user_b', 'play_card', { cardId: 'card_2' });

      const entries = buffer.drain('room_1');

      expect(entries).toHaveLength(2);
      expect(entries[0].userId).toBe('user_a');
      expect(entries[0].action).toBe('open_card');
      expect(entries[1].userId).toBe('user_b');
      expect(entries[1].action).toBe('play_card');

      // Buffer should be cleared
      expect(buffer.has('room_1')).toBe(false);
      expect(buffer.drain('room_1')).toHaveLength(0);
    });

    it('returns empty array for a room with no entries', () => {
      const entries = buffer.drain('nonexistent_room');
      expect(entries).toEqual([]);
    });

    it('does not affect other rooms', () => {
      buffer.record('room_1', 'user_a', 'open_card', { cardId: 'card_1' });
      buffer.record('room_2', 'user_b', 'play_card', { cardId: 'card_2' });

      buffer.drain('room_1');

      expect(buffer.has('room_1')).toBe(false);
      expect(buffer.has('room_2')).toBe(true);
    });
  });

  describe('toRpcEntries', () => {
    it('converts entries to snake_case with ISO timestamps', () => {
      buffer.record('room_1', 'user_a', 'open_card', { cardId: 'card_1' });
      const entries = buffer.drain('room_1');
      const rpcEntries = buffer.toRpcEntries(entries);

      expect(rpcEntries).toHaveLength(1);
      expect(rpcEntries[0]).toEqual({
        user_id: 'user_a',
        action: 'open_card',
        payload: { cardId: 'card_1' },
        created_at: expect.any(String),
      });

      // Verify it's a valid ISO string
      expect(() => new Date(rpcEntries[0].created_at)).not.toThrow();
    });

    it('maps all action types correctly', () => {
      buffer.record('room_1', 'u1', 'open_card', {});
      buffer.record('room_1', 'u2', 'play_card', {});
      buffer.record('room_1', 'u1', 'surrender', {});
      buffer.record('room_1', 'u2', 'timeout', {});

      const entries = buffer.drain('room_1');
      const rpcEntries = buffer.toRpcEntries(entries);

      expect(rpcEntries.map((e) => e.action)).toEqual([
        'open_card',
        'play_card',
        'surrender',
        'timeout',
      ]);
    });

    it('returns empty array for empty input', () => {
      expect(buffer.toRpcEntries([])).toEqual([]);
    });
  });

  describe('clear', () => {
    it('removes buffer without returning entries', () => {
      buffer.record('room_1', 'user_a', 'open_card', { cardId: 'card_1' });

      buffer.clear('room_1');

      expect(buffer.has('room_1')).toBe(false);
    });

    it('is safe to call on nonexistent room', () => {
      expect(() => buffer.clear('nonexistent')).not.toThrow();
    });
  });

  describe('has', () => {
    it('returns true when room has entries', () => {
      buffer.record('room_1', 'user_a', 'open_card', {});
      expect(buffer.has('room_1')).toBe(true);
    });

    it('returns false when room has no entries', () => {
      expect(buffer.has('room_1')).toBe(false);
    });

    it('returns false after drain', () => {
      buffer.record('room_1', 'user_a', 'open_card', {});
      buffer.drain('room_1');
      expect(buffer.has('room_1')).toBe(false);
    });
  });
});
