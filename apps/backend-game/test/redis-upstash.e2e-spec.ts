import type { ConfigService } from '@nestjs/config';
import type Redis from 'ioredis';
import { GameCoordinationService } from '../src/redis/game-coordination.service';
import { RedisService } from '../src/redis/redis.service';

const enabled =
  process.env.REDIS_INTEGRATION_TEST === '1' &&
  Boolean(process.env.REDIS_URL?.startsWith('rediss://'));
const describeUpstash = enabled ? describe : describe.skip;

const profile = (userId: string, target: 'cpns' | 'bumn' = 'cpns') => ({
  userId,
  displayName: userId,
  target,
  loadout: {
    characterId: 'character-basic-squire',
    towerId: 'tower-garda-biru',
  },
});

describeUpstash('Upstash Redis coordination (opt-in)', () => {
  const prefix = `yudha:test:${Date.now()}:${Math.random().toString(36).slice(2)}`;
  let redisA: RedisService;
  let redisB: RedisService;
  let coordinationA: GameCoordinationService;
  let coordinationB: GameCoordinationService;

  beforeAll(async () => {
    redisA = createRedis('integration-a');
    redisB = createRedis('integration-b');
    expect(await Promise.all([redisA.connect(), redisB.connect()])).toEqual([
      true,
      true,
    ]);
    coordinationA = new GameCoordinationService(redisA);
    coordinationB = new GameCoordinationService(redisB);
    await Promise.all([
      coordinationA.onApplicationBootstrap(),
      coordinationB.onApplicationBootstrap(),
    ]);
  });

  afterAll(async () => {
    await Promise.allSettled([
      coordinationA?.beforeApplicationShutdown(),
      coordinationB?.beforeApplicationShutdown(),
    ]);
    const command = redisA?.command;
    if (command?.status === 'ready') await deleteOnlyTestPrefix(command);
    await Promise.allSettled([
      redisA?.onApplicationShutdown(),
      redisB?.onApplicationShutdown(),
    ]);
  });

  it('partitions exact queues, preserves FIFO, and matches only once', async () => {
    const first = await coordinationA.joinPublicQueue(
      profile('fifo-first'),
      'socket-first',
      'casual',
    );
    const isolated = await coordinationB.joinPublicQueue(
      profile('bumn-player', 'bumn'),
      'socket-bumn',
      'casual',
    );
    const [second, duplicate] = await Promise.all([
      coordinationA.joinPublicQueue(
        profile('fifo-second'),
        'socket-second',
        'casual',
      ),
      coordinationB.joinPublicQueue(
        profile('fifo-second'),
        'socket-second-duplicate',
        'casual',
      ),
    ]);

    expect(first.type).toBe('queued');
    expect(isolated.type).toBe('queued');
    const match = [second, duplicate].find(
      (result) => result.type === 'matched',
    );
    expect(match?.type).toBe('matched');
    if (match?.type === 'matched') {
      expect(match.opponent.userId).toBe('fifo-first');
    }
    expect(
      [second, duplicate].filter((result) => result.type === 'matched'),
    ).toHaveLength(1);
  });

  it('reserves Private codes atomically and consumes them once', async () => {
    const code = 'ABC234';
    await expect(
      coordinationA.createPrivateReservation(
        profile('private-owner'),
        'socket-owner',
        code,
      ),
    ).resolves.toBe('created');
    await expect(
      coordinationB.createPrivateReservation(
        profile('other-owner'),
        'socket-other',
        code,
      ),
    ).resolves.toBe('collision');

    const [one, two] = await Promise.all([
      coordinationA.consumePrivateReservation(
        profile('joiner-a'),
        code,
        'match-a',
        'private-owner',
        redisA.instanceId,
      ),
      coordinationB.consumePrivateReservation(
        profile('joiner-b'),
        code,
        'match-b',
        'private-owner',
        redisA.instanceId,
      ),
    ]);
    expect(
      [one, two].filter((result) => result.type === 'joined'),
    ).toHaveLength(1);
  });

  it('replays completed commands and rejects fingerprint conflicts', async () => {
    const claim = await coordinationA.claimCommand(
      'command-user',
      'command-id',
      'fingerprint-a',
    );
    expect(claim.type).toBe('claimed');
    await coordinationA.completeCommand(
      'command-user',
      'command-id',
      'fingerprint-a',
      claim.requestId,
      { data: { accepted: true }, requestId: claim.requestId },
    );

    await expect(
      coordinationB.claimCommand('command-user', 'command-id', 'fingerprint-a'),
    ).resolves.toEqual(expect.objectContaining({ type: 'replay' }));
    await expect(
      coordinationB.claimCommand('command-user', 'command-id', 'fingerprint-b'),
    ).resolves.toEqual(expect.objectContaining({ type: 'conflict' }));
  });

  function createRedis(instanceId: string): RedisService {
    const values: Record<string, string | undefined> = {
      REDIS_URL: process.env.REDIS_URL,
      REDIS_KEY_PREFIX: prefix,
      GAME_INSTANCE_ID: instanceId,
      NODE_ENV: 'test',
    };
    return new RedisService({
      get: (key: string) => values[key],
    } as ConfigService);
  }

  async function deleteOnlyTestPrefix(command: Redis): Promise<void> {
    let cursor = '0';
    do {
      const [nextCursor, keys] = await command.scan(
        cursor,
        'MATCH',
        `${prefix}:*`,
        'COUNT',
        100,
      );
      cursor = nextCursor;
      if (keys.length > 0) await command.del(...keys);
    } while (cursor !== '0');
  }
});
