import { CardTimeoutService } from './card-timeout.service';

describe('CardTimeoutService', () => {
  let service: CardTimeoutService;

  beforeEach(() => {
    jest.useFakeTimers();
    service = new CardTimeoutService();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  describe('scheduleTimeout', () => {
    it('fires callback after the specified time limit', () => {
      const callback = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', 15, callback);

      // Should not fire before 15 seconds
      jest.advanceTimersByTime(14_999);
      expect(callback).not.toHaveBeenCalled();

      // Should fire at 15 seconds
      jest.advanceTimersByTime(1);
      expect(callback).toHaveBeenCalledWith('room_1', 'user_a', 'card_1');
      expect(callback).toHaveBeenCalledTimes(1);
    });

    it('uses DEFAULT_TIMEOUT_SECONDS (10s) when timeLimitSeconds is undefined', () => {
      const callback = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', undefined, callback);

      jest.advanceTimersByTime(9_999);
      expect(callback).not.toHaveBeenCalled();

      jest.advanceTimersByTime(1);
      expect(callback).toHaveBeenCalledTimes(1);
    });

    it('uses DEFAULT_TIMEOUT_SECONDS when timeLimitSeconds is 0', () => {
      const callback = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', 0, callback);

      jest.advanceTimersByTime(10_000);
      expect(callback).toHaveBeenCalledTimes(1);
    });

    it('replaces an existing timer for the same room+user', () => {
      const callback1 = jest.fn();
      const callback2 = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', 10, callback1);
      service.scheduleTimeout('room_1', 'user_a', 'card_2', 20, callback2);

      // Original timer at 10s should NOT fire
      jest.advanceTimersByTime(10_000);
      expect(callback1).not.toHaveBeenCalled();

      // Replacement timer at 20s should fire
      jest.advanceTimersByTime(10_000);
      expect(callback2).toHaveBeenCalledWith('room_1', 'user_a', 'card_2');
    });
  });

  describe('clearTimeout', () => {
    it('prevents the scheduled callback from firing', () => {
      const callback = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', 10, callback);
      service.clearTimeout('room_1', 'user_a');

      jest.advanceTimersByTime(20_000);
      expect(callback).not.toHaveBeenCalled();
    });

    it('is safe to call when no timer exists', () => {
      expect(() => service.clearTimeout('room_1', 'user_a')).not.toThrow();
    });

    it('does not affect other users in the same room', () => {
      const callbackA = jest.fn();
      const callbackB = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', 10, callbackA);
      service.scheduleTimeout('room_1', 'user_b', 'card_2', 10, callbackB);

      service.clearTimeout('room_1', 'user_a');

      jest.advanceTimersByTime(10_000);
      expect(callbackA).not.toHaveBeenCalled();
      expect(callbackB).toHaveBeenCalledTimes(1);
    });
  });

  describe('cancelAllTimersForRoom', () => {
    it('cancels all timers for a specific room', () => {
      const callbackA = jest.fn();
      const callbackB = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', 10, callbackA);
      service.scheduleTimeout('room_1', 'user_b', 'card_2', 10, callbackB);

      service.cancelAllTimersForRoom('room_1');

      jest.advanceTimersByTime(20_000);
      expect(callbackA).not.toHaveBeenCalled();
      expect(callbackB).not.toHaveBeenCalled();
    });

    it('does not affect timers in other rooms', () => {
      const callback1 = jest.fn();
      const callback2 = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', 10, callback1);
      service.scheduleTimeout('room_2', 'user_b', 'card_2', 10, callback2);

      service.cancelAllTimersForRoom('room_1');

      jest.advanceTimersByTime(10_000);
      expect(callback1).not.toHaveBeenCalled();
      expect(callback2).toHaveBeenCalledTimes(1);
    });

    it('is safe to call on a room with no timers', () => {
      expect(() => service.cancelAllTimersForRoom('nonexistent')).not.toThrow();
    });
  });

  describe('concurrent timers', () => {
    it('supports multiple timers across different rooms simultaneously', () => {
      const cb1 = jest.fn();
      const cb2 = jest.fn();
      const cb3 = jest.fn();

      service.scheduleTimeout('room_1', 'user_a', 'card_1', 5, cb1);
      service.scheduleTimeout('room_2', 'user_b', 'card_2', 10, cb2);
      service.scheduleTimeout('room_3', 'user_c', 'card_3', 15, cb3);

      jest.advanceTimersByTime(5_000);
      expect(cb1).toHaveBeenCalledTimes(1);
      expect(cb2).not.toHaveBeenCalled();
      expect(cb3).not.toHaveBeenCalled();

      jest.advanceTimersByTime(5_000);
      expect(cb2).toHaveBeenCalledTimes(1);
      expect(cb3).not.toHaveBeenCalled();

      jest.advanceTimersByTime(5_000);
      expect(cb3).toHaveBeenCalledTimes(1);
    });
  });
});
