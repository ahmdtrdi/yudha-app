import {
  BeforeApplicationShutdown,
  Injectable,
  Logger,
  OnApplicationBootstrap,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { GamePlayerProfile } from '../match/profiles/game-player-profile.service';
import type { PublicMatchmakingMode } from '../match/rooms/room.types';
import {
  REDIS_COMMAND_TTL_SECONDS,
  REDIS_INSTANCE_HEARTBEAT_MS,
  REDIS_INSTANCE_STALE_MS,
  REDIS_PRIVATE_ROOM_TTL_SECONDS,
  REDIS_QUEUE_LEASE_MS,
  REDIS_ROOM_TTL_SECONDS,
} from './redis.constants';
import { RedisService } from './redis.service';
import type {
  CommandClaim,
  PublicQueueResult,
  RedisPrivateReservation,
  RedisQueueEntry,
  RoomRoute,
} from './game-coordination.types';

const JOIN_QUEUE_SCRIPT = `
local now = tonumber(ARGV[1])
local lease = tonumber(ARGV[2])
local stale = tonumber(ARGV[3])
local userId = ARGV[4]
local entryJson = ARGV[5]
local matchId = ARGV[6]
local ownerInstanceId = ARGV[7]
local staleRemoved = 0
local stateJson = redis.call('HGET', KEYS[3], userId)
if stateJson then
  local state = cjson.decode(stateJson)
  if tonumber(state.expiresAt or 0) > now and state.kind ~= 'queue' then
    return cjson.encode({type='conflict'})
  end
  if tonumber(state.expiresAt or 0) > now and state.kind == 'queue' and state.bucket ~= KEYS[1] then
    return cjson.encode({type='conflict'})
  end
end
for i = 1, 50 do
  local candidates = redis.call('ZRANGE', KEYS[1], 0, 0)
  if #candidates == 0 then break end
  local opponentId = candidates[1]
  if opponentId == userId then break end
  local opponentJson = redis.call('HGET', KEYS[2], opponentId)
  local valid = false
  if opponentJson then
    local opponent = cjson.decode(opponentJson)
    local beat = tonumber(redis.call('HGET', KEYS[4], opponent.instanceId) or '0')
    valid = tonumber(opponent.expiresAt or 0) > now and now - beat <= stale
  end
  if valid then
    redis.call('ZREM', KEYS[1], opponentId)
    redis.call('HDEL', KEYS[2], opponentId)
    local matching = cjson.encode({kind='matching', matchId=matchId, instanceId=ownerInstanceId, expiresAt=now + 15000})
    redis.call('HSET', KEYS[3], opponentId, matching, userId, matching)
    return cjson.encode({type='matched', opponent=opponentJson, matchId=matchId, staleRemoved=staleRemoved})
  end
  redis.call('ZREM', KEYS[1], opponentId)
  redis.call('HDEL', KEYS[2], opponentId)
  redis.call('HDEL', KEYS[3], opponentId)
  staleRemoved = staleRemoved + 1
end
local entry = cjson.decode(entryJson)
entry.expiresAt = now + lease
entryJson = cjson.encode(entry)
redis.call('ZADD', KEYS[1], 'NX', entry.joinedAt, userId)
redis.call('HSET', KEYS[2], userId, entryJson)
redis.call('HSET', KEYS[3], userId, cjson.encode({kind='queue', bucket=KEYS[1], expiresAt=now + lease}))
local rank = redis.call('ZRANK', KEYS[1], userId)
return cjson.encode({type='queued', entry=entryJson, position=(rank or 0)+1, depth=redis.call('ZCARD', KEYS[1]), staleRemoved=staleRemoved})
`;

const CANCEL_QUEUE_SCRIPT = `
local userId = ARGV[1]
local removed = 0
for i = 2, #KEYS, 2 do
  removed = removed + redis.call('ZREM', KEYS[i], userId)
  redis.call('HDEL', KEYS[i + 1], userId)
end
local state = redis.call('HGET', KEYS[1], userId)
if state then
  local decoded = cjson.decode(state)
  if decoded.kind == 'queue' or decoded.kind == 'matching' then redis.call('HDEL', KEYS[1], userId) end
end
return removed
`;

const CREATE_PRIVATE_SCRIPT = `
local now = tonumber(ARGV[1])
local userId = ARGV[2]
local reservation = ARGV[3]
local code = ARGV[4]
local stateJson = redis.call('HGET', KEYS[3], userId)
if stateJson then
  local state = cjson.decode(stateJson)
  if tonumber(state.expiresAt or 0) > now then return 'conflict' end
end
if redis.call('SET', KEYS[1], reservation, 'NX', 'EX', ARGV[5]) == false then return 'collision' end
redis.call('SET', KEYS[2], code, 'EX', ARGV[5])
redis.call('HSET', KEYS[3], userId, cjson.encode({kind='private', code=code, expiresAt=now + tonumber(ARGV[5]) * 1000}))
redis.call('SADD', KEYS[4], code)
redis.call('EXPIRE', KEYS[4], ARGV[5])
return 'created'
`;

const JOIN_PRIVATE_SCRIPT = `
local now = tonumber(ARGV[1])
local joinerId = ARGV[2]
local joinerTarget = ARGV[3]
local matchId = ARGV[4]
local ownerInstance = ARGV[5]
local reservationJson = redis.call('GET', KEYS[1])
if not reservationJson then return cjson.encode({type='invalid'}) end
local reservation = cjson.decode(reservationJson)
if reservation.owner.userId == joinerId or reservation.target ~= joinerTarget then return cjson.encode({type='invalid'}) end
local joinerStateJson = redis.call('HGET', KEYS[3], joinerId)
if joinerStateJson then
  local joinerState = cjson.decode(joinerStateJson)
  if tonumber(joinerState.expiresAt or 0) > now then return cjson.encode({type='conflict'}) end
end
redis.call('DEL', KEYS[1], KEYS[2])
redis.call('SREM', KEYS[4], ARGV[6])
local matching = cjson.encode({kind='matching', matchId=matchId, instanceId=ownerInstance, expiresAt=now + 15000})
redis.call('HSET', KEYS[3], reservation.owner.userId, matching, joinerId, matching)
return cjson.encode({type='joined', reservation=reservationJson})
`;

const CANCEL_PRIVATE_SCRIPT = `
local reservationJson = redis.call('GET', KEYS[1])
if not reservationJson then return false end
local reservation = cjson.decode(reservationJson)
if reservation.owner.userId ~= ARGV[1] then return false end
redis.call('DEL', KEYS[1], KEYS[2])
redis.call('HDEL', KEYS[3], ARGV[1])
redis.call('SREM', KEYS[4], reservation.code)
return reservationJson
`;

const CLAIM_COMMAND_SCRIPT = `
local existing = redis.call('GET', KEYS[1])
if existing then
  local decoded = cjson.decode(existing)
  if decoded.fingerprint ~= ARGV[1] then return cjson.encode({type='conflict', requestId=decoded.requestId}) end
  if decoded.status == 'done' then return cjson.encode({type='replay', requestId=decoded.requestId, acknowledgement=decoded.acknowledgement}) end
  return cjson.encode({type='pending', requestId=decoded.requestId})
end
redis.call('SET', KEYS[1], cjson.encode({status='pending', fingerprint=ARGV[1], requestId=ARGV[2]}), 'EX', ARGV[3])
return cjson.encode({type='claimed', requestId=ARGV[2]})
`;

@Injectable()
export class GameCoordinationService
  implements OnApplicationBootstrap, BeforeApplicationShutdown
{
  private readonly logger = new Logger(GameCoordinationService.name);
  private heartbeatTimer?: ReturnType<typeof setInterval>;
  private draining = false;

  constructor(private readonly redis: RedisService) {}

  get available(): boolean {
    return !this.draining && this.redis.isReady();
  }

  async onApplicationBootstrap(): Promise<void> {
    if (!this.redis.enabled) return;
    await this.heartbeat();
    this.heartbeatTimer = setInterval(
      () => void this.heartbeat(),
      REDIS_INSTANCE_HEARTBEAT_MS,
    );
    this.heartbeatTimer.unref?.();
  }

  async beforeApplicationShutdown(): Promise<void> {
    this.draining = true;
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
    const command = this.redis.command;
    if (!command || command.status !== 'ready') return;
    await Promise.allSettled([
      command.hdel(this.instancesKey, this.redis.instanceId),
      this.removeInstanceQueueEntries(),
      this.removeInstancePrivateReservations(),
      this.removeInstanceRoomRoutes(),
    ]);
  }

  async joinPublicQueue(
    profile: GamePlayerProfile,
    socketId: string,
    mode: PublicMatchmakingMode,
  ): Promise<PublicQueueResult> {
    const command = this.redis.command;
    if (!this.available || !command) return { type: 'unavailable' };
    const now = Date.now();
    const entry: RedisQueueEntry = {
      ...profile,
      socketId,
      instanceId: this.redis.instanceId,
      mode,
      joinedAt: now,
      expiresAt: now + REDIS_QUEUE_LEASE_MS,
    };
    const matchId = randomUUID();
    try {
      const raw = await command.eval(
        JOIN_QUEUE_SCRIPT,
        4,
        this.queueKey(profile.target, mode),
        this.queueDataKey(profile.target, mode),
        this.statesKey,
        this.instancesKey,
        now,
        REDIS_QUEUE_LEASE_MS,
        REDIS_INSTANCE_STALE_MS,
        profile.userId,
        JSON.stringify(entry),
        matchId,
        this.redis.instanceId,
      );
      const result = this.parseJson<{
        type: 'queued' | 'matched' | 'conflict';
        entry?: string;
        opponent?: string;
        position?: number;
        depth?: number;
        matchId?: string;
        staleRemoved?: number;
      }>(raw);
      if (result.staleRemoved) {
        this.logger.warn(
          `Removed ${result.staleRemoved} stale matchmaking entr${result.staleRemoved === 1 ? 'y' : 'ies'} from target=${profile.target} mode=${mode}.`,
        );
      }
      if (result.type === 'conflict') return { type: 'conflict' };
      if (result.type === 'matched' && result.opponent) {
        return {
          type: 'matched',
          entry,
          opponent: JSON.parse(result.opponent) as RedisQueueEntry,
          matchId: result.matchId || matchId,
        };
      }
      const queuedEntry = result.entry
        ? (JSON.parse(result.entry) as RedisQueueEntry)
        : entry;
      return {
        type: 'queued',
        entry: queuedEntry,
        position: result.position || 1,
        depth: result.depth || 1,
      };
    } catch (error) {
      this.logFailure('join public queue', error);
      return { type: 'unavailable' };
    }
  }

  async refreshQueue(entry: RedisQueueEntry): Promise<boolean> {
    const command = this.redis.command;
    if (!this.available || !command) return false;
    const refreshed = {
      ...entry,
      expiresAt: Date.now() + REDIS_QUEUE_LEASE_MS,
    };
    const result = await command.eval(
      `
      if not redis.call('ZSCORE', KEYS[1], ARGV[1]) then return 0 end
      redis.call('HSET', KEYS[2], ARGV[1], ARGV[2])
      redis.call('HSET', KEYS[3], ARGV[1], ARGV[3])
      return 1
      `,
      3,
      this.queueKey(entry.target, entry.mode),
      this.queueDataKey(entry.target, entry.mode),
      this.statesKey,
      entry.userId,
      JSON.stringify(refreshed),
      JSON.stringify({
        kind: 'queue',
        bucket: this.queueKey(entry.target, entry.mode),
        expiresAt: refreshed.expiresAt,
      }),
    );
    return Number(result) === 1;
  }

  async cancelPublicQueue(
    userId: string,
    allowWhileDraining = false,
  ): Promise<boolean> {
    const command = this.redis.command;
    if ((!allowWhileDraining && !this.available) || !command) return false;
    try {
      const keys: string[] = [this.statesKey];
      for (const target of ['cpns', 'bumn'] as const) {
        for (const mode of ['casual', 'ranked'] as const) {
          keys.push(
            this.queueKey(target, mode),
            this.queueDataKey(target, mode),
          );
        }
      }
      const result = await command.eval(
        CANCEL_QUEUE_SCRIPT,
        keys.length,
        ...keys,
        userId,
      );
      return Number(result) > 0;
    } catch (error) {
      this.logFailure('cancel public queue', error);
      return false;
    }
  }

  async restorePublicPair(entries: RedisQueueEntry[]): Promise<void> {
    const command = this.redis.command;
    if (!this.available || !command) return;
    const now = Date.now();
    for (const entry of entries) {
      const restored = { ...entry, expiresAt: now + REDIS_QUEUE_LEASE_MS };
      await command
        .pipeline()
        .zadd(
          this.queueKey(entry.target, entry.mode),
          entry.joinedAt,
          entry.userId,
        )
        .hset(
          this.queueDataKey(entry.target, entry.mode),
          entry.userId,
          JSON.stringify(restored),
        )
        .hset(
          this.statesKey,
          entry.userId,
          JSON.stringify({
            kind: 'queue',
            bucket: this.queueKey(entry.target, entry.mode),
            expiresAt: restored.expiresAt,
          }),
        )
        .exec();
    }
  }

  async createPrivateReservation(
    profile: GamePlayerProfile,
    socketId: string,
    code: string,
  ): Promise<'created' | 'collision' | 'conflict' | 'unavailable'> {
    const command = this.redis.command;
    if (!this.available || !command) return 'unavailable';
    const now = Date.now();
    const reservation: RedisPrivateReservation = {
      code,
      owner: {
        ...profile,
        socketId,
        instanceId: this.redis.instanceId,
      },
      target: profile.target,
      createdAt: now,
      expiresAt: now + REDIS_PRIVATE_ROOM_TTL_SECONDS * 1000,
    };
    try {
      return String(
        await command.eval(
          CREATE_PRIVATE_SCRIPT,
          4,
          this.privateKey(code),
          this.privateOwnerKey(profile.userId),
          this.statesKey,
          this.instancePrivateKey(this.redis.instanceId),
          now,
          profile.userId,
          JSON.stringify(reservation),
          code,
          REDIS_PRIVATE_ROOM_TTL_SECONDS,
        ),
      ) as 'created' | 'collision' | 'conflict';
    } catch (error) {
      this.logFailure('create private reservation', error);
      return 'unavailable';
    }
  }

  async getPrivateReservation(
    code: string,
  ): Promise<RedisPrivateReservation | undefined> {
    const command = this.redis.command;
    if (!this.available || !command) return undefined;
    try {
      const raw = await command.eval(
        `return redis.call('GET', KEYS[1])`,
        1,
        this.privateKey(code),
      );
      return raw ? this.parseJson<RedisPrivateReservation>(raw) : undefined;
    } catch (error) {
      this.logFailure('read private reservation', error);
      return undefined;
    }
  }

  async getPrivateReservationForOwner(
    userId: string,
  ): Promise<RedisPrivateReservation | undefined> {
    const command = this.redis.command;
    if (!this.available || !command) return undefined;
    try {
      const code = await command.eval(
        `return redis.call('GET', KEYS[1])`,
        1,
        this.privateOwnerKey(userId),
      );
      return typeof code === 'string'
        ? await this.getPrivateReservation(code)
        : undefined;
    } catch (error) {
      this.logFailure('read owner private reservation', error);
      return undefined;
    }
  }

  async updatePrivateOwnerSocket(
    reservation: RedisPrivateReservation,
    socketId: string,
  ): Promise<void> {
    const command = this.redis.command;
    if (!this.available || !command) return;
    const ttl = await command.ttl(this.privateKey(reservation.code));
    if (ttl <= 0) return;
    await command.set(
      this.privateKey(reservation.code),
      JSON.stringify({
        ...reservation,
        owner: { ...reservation.owner, socketId },
      }),
      'EX',
      ttl,
    );
  }

  async consumePrivateReservation(
    joiner: GamePlayerProfile,
    code: string,
    matchId: string,
    ownerUserId: string,
    ownerInstanceId?: string,
  ): Promise<
    | { type: 'joined'; reservation: RedisPrivateReservation }
    | { type: 'invalid' | 'conflict' | 'unavailable' }
  > {
    const command = this.redis.command;
    if (!this.available || !command) return { type: 'unavailable' };
    try {
      const raw = await command.eval(
        JOIN_PRIVATE_SCRIPT,
        4,
        this.privateKey(code),
        this.privateOwnerKey(ownerUserId),
        this.statesKey,
        this.instancePrivateKey(ownerInstanceId || this.redis.instanceId),
        Date.now(),
        joiner.userId,
        joiner.target,
        matchId,
        ownerInstanceId || this.redis.instanceId,
        code,
      );
      const result = this.parseJson<{
        type: 'joined' | 'invalid' | 'conflict';
        reservation?: string;
      }>(raw);
      if (result.type !== 'joined') return { type: result.type };
      if (!result.reservation) return { type: 'invalid' };
      return {
        type: 'joined',
        reservation: JSON.parse(result.reservation) as RedisPrivateReservation,
      };
    } catch (error) {
      this.logFailure('consume private reservation', error);
      return { type: 'unavailable' };
    }
  }

  async cancelPrivateReservation(
    userId: string,
    code: string,
  ): Promise<RedisPrivateReservation | undefined> {
    const command = this.redis.command;
    if (!this.available || !command) return undefined;
    const reservation = await this.getPrivateReservation(code);
    if (!reservation) return undefined;
    try {
      const raw = await command.eval(
        CANCEL_PRIVATE_SCRIPT,
        4,
        this.privateKey(code),
        this.privateOwnerKey(reservation.owner.userId),
        this.statesKey,
        this.instancePrivateKey(reservation.owner.instanceId),
        userId,
      );
      return raw ? this.parseJson<RedisPrivateReservation>(raw) : undefined;
    } catch (error) {
      this.logFailure('cancel private reservation', error);
      return undefined;
    }
  }

  async registerRoom(route: RoomRoute): Promise<boolean> {
    const command = this.redis.command;
    if (!this.available || !command) return false;
    const pipeline = command.pipeline();
    pipeline.set(
      this.roomKey(route.roomId),
      JSON.stringify(route),
      'EX',
      REDIS_ROOM_TTL_SECONDS,
    );
    for (const userId of route.userIds) {
      pipeline.set(
        this.userRoomKey(userId),
        JSON.stringify(route),
        'EX',
        REDIS_ROOM_TTL_SECONDS,
      );
      pipeline.hset(
        this.statesKey,
        userId,
        JSON.stringify({
          kind: 'room',
          roomId: route.roomId,
          instanceId: route.instanceId,
          expiresAt: Date.now() + REDIS_ROOM_TTL_SECONDS * 1000,
        }),
      );
    }
    pipeline
      .sadd(this.instanceRoomsKey(route.instanceId), route.roomId)
      .expire(this.instanceRoomsKey(route.instanceId), REDIS_ROOM_TTL_SECONDS);
    try {
      await pipeline.exec();
      return true;
    } catch (error) {
      this.logFailure('register room route', error);
      return false;
    }
  }

  async getRoomRoute(roomId: string): Promise<RoomRoute | undefined> {
    return this.readRoute(this.roomKey(roomId));
  }

  async getUserRoomRoute(userId: string): Promise<RoomRoute | undefined> {
    return this.readRoute(this.userRoomKey(userId));
  }

  async removeRoom(route: RoomRoute): Promise<void> {
    const command = this.redis.command;
    if (!command || command.status !== 'ready') return;
    const pipeline = command.pipeline().del(this.roomKey(route.roomId));
    for (const userId of route.userIds) {
      pipeline.del(this.userRoomKey(userId)).hdel(this.statesKey, userId);
    }
    pipeline.srem(this.instanceRoomsKey(route.instanceId), route.roomId);
    await pipeline.exec();
  }

  async claimCommand(
    userId: string,
    commandId: string,
    fingerprint: string,
  ): Promise<CommandClaim> {
    const requestId = randomUUID();
    const command = this.redis.command;
    if (!this.available || !command) return { type: 'unavailable', requestId };
    try {
      const raw = await command.eval(
        CLAIM_COMMAND_SCRIPT,
        1,
        this.commandKey(userId, commandId),
        fingerprint,
        requestId,
        REDIS_COMMAND_TTL_SECONDS,
      );
      return this.parseJson<CommandClaim>(raw);
    } catch (error) {
      this.logFailure('claim command', error);
      return { type: 'unavailable', requestId };
    }
  }

  async completeCommand(
    userId: string,
    commandId: string,
    fingerprint: string,
    requestId: string,
    acknowledgement: unknown,
  ): Promise<void> {
    const command = this.redis.command;
    if (!command || command.status !== 'ready') return;
    await command.set(
      this.commandKey(userId, commandId),
      JSON.stringify({
        status: 'done',
        fingerprint,
        requestId,
        acknowledgement,
      }),
      'EX',
      REDIS_COMMAND_TTL_SECONDS,
    );
  }

  private async heartbeat(): Promise<void> {
    const command = this.redis.command;
    if (!command || command.status !== 'ready') return;
    try {
      await command.hset(this.instancesKey, this.redis.instanceId, Date.now());
    } catch (error) {
      this.logFailure('write heartbeat', error);
    }
  }

  private async readRoute(key: string): Promise<RoomRoute | undefined> {
    const command = this.redis.command;
    if (!this.available || !command) return undefined;
    try {
      const raw = await command.eval(
        `return redis.call('GET', KEYS[1])`,
        1,
        key,
      );
      return raw ? this.parseJson<RoomRoute>(raw) : undefined;
    } catch (error) {
      this.logFailure('read room route', error);
      return undefined;
    }
  }

  private async removeInstanceQueueEntries(): Promise<void> {
    const command = this.redis.command;
    if (!command || command.status !== 'ready') return;
    for (const target of ['cpns', 'bumn'] as const) {
      for (const mode of ['casual', 'ranked'] as const) {
        const data = await command.hgetall(this.queueDataKey(target, mode));
        for (const [userId, json] of Object.entries(data)) {
          const entry = JSON.parse(json) as RedisQueueEntry;
          if (entry.instanceId === this.redis.instanceId) {
            await this.cancelPublicQueue(userId, true);
          }
        }
      }
    }
  }

  private async removeInstancePrivateReservations(): Promise<void> {
    const command = this.redis.command;
    if (!command || command.status !== 'ready') return;
    const registryKey = this.instancePrivateKey(this.redis.instanceId);
    const codes = await command.smembers(registryKey);
    for (const code of codes) {
      const raw = await command.get(this.privateKey(code));
      if (!raw) continue;
      const reservation = JSON.parse(raw) as RedisPrivateReservation;
      if (reservation.owner.instanceId !== this.redis.instanceId) continue;
      await command.eval(
        CANCEL_PRIVATE_SCRIPT,
        4,
        this.privateKey(code),
        this.privateOwnerKey(reservation.owner.userId),
        this.statesKey,
        registryKey,
        reservation.owner.userId,
      );
    }
    await command.del(registryKey);
  }

  private async removeInstanceRoomRoutes(): Promise<void> {
    const command = this.redis.command;
    if (!command || command.status !== 'ready') return;
    const registryKey = this.instanceRoomsKey(this.redis.instanceId);
    const roomIds = await command.smembers(registryKey);
    for (const roomId of roomIds) {
      const raw = await command.get(this.roomKey(roomId));
      if (!raw) continue;
      const route = JSON.parse(raw) as RoomRoute;
      if (route.instanceId !== this.redis.instanceId) continue;
      const pipeline = command.pipeline().del(this.roomKey(roomId));
      for (const userId of route.userIds) {
        pipeline.del(this.userRoomKey(userId)).hdel(this.statesKey, userId);
      }
      await pipeline.exec();
    }
    await command.del(registryKey);
  }

  private queueKey(target: string, mode: string): string {
    return this.redis.key('queue', target, mode);
  }

  private queueDataKey(target: string, mode: string): string {
    return this.redis.key('queue-data', target, mode);
  }

  private privateKey(code: string): string {
    return this.redis.key('private', code);
  }

  private privateOwnerKey(userId: string): string {
    return this.redis.key('private-owner', userId);
  }

  private instancePrivateKey(instanceId: string): string {
    return this.redis.key('instance-private', instanceId);
  }

  private instanceRoomsKey(instanceId: string): string {
    return this.redis.key('instance-rooms', instanceId);
  }

  private roomKey(roomId: string): string {
    return this.redis.key('room', roomId);
  }

  private userRoomKey(userId: string): string {
    return this.redis.key('user-room', userId);
  }

  private commandKey(userId: string, commandId: string): string {
    return this.redis.key('command', userId, commandId);
  }

  private get instancesKey(): string {
    return this.redis.key('instances');
  }

  private get statesKey(): string {
    return this.redis.key('user-states');
  }

  private logFailure(operation: string, error: unknown): void {
    this.logger.error(
      `Redis ${operation} failed: ${error instanceof Error ? error.message : String(error)}`,
    );
  }

  private parseJson<T>(value: unknown): T {
    if (typeof value !== 'string') {
      throw new Error('Redis returned an unexpected non-string response.');
    }
    return JSON.parse(value) as T;
  }
}
