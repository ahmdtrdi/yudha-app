import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Json } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';
import type {
  GrantBetaCreditPayload,
  PurchaseStoreItemPayload,
  SetStoreLoadoutPayload,
  StoreItemsQuery,
} from './store.types';

const STORE_ITEM_TYPES = new Set(['character_skin', 'arena', 'tower']);

@Injectable()
export class StoreService {
  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly configService: ConfigService,
  ) {}

  async listItems(userId: string, query: StoreItemsQuery) {
    const type = this.optionalItemType(query.type);
    const client = this.supabaseService.getClient();
    let itemsQuery = client
      .from('store_items')
      .select('*')
      .eq('is_active', true)
      .order('type')
      .order('coin_price')
      .order('id');

    if (type) {
      itemsQuery = itemsQuery.eq('type', type);
    }

    const [itemsResult, inventoryResult, profileResult] = await Promise.all([
      itemsQuery,
      client
        .from('user_inventory')
        .select('item_id')
        .eq('user_id', userId)
        .order('item_id'),
      client
        .from('profiles')
        .select(
          'coins, equipped_avatar_id, equipped_tower_id, equipped_arena_id',
        )
        .eq('id', userId)
        .single(),
    ]);

    const error =
      itemsResult.error ?? inventoryResult.error ?? profileResult.error;
    if (error) {
      throw new InternalServerErrorException(error.message);
    }
    if (!profileResult.data) {
      throw new NotFoundException('Profile not found.');
    }

    return {
      data: {
        coins: profileResult.data.coins,
        items: (itemsResult.data ?? []).map((item) => ({
          id: item.id,
          type: item.type,
          name: item.name,
          description: item.description,
          rarity: item.rarity,
          coinPrice: item.coin_price,
          proExclusive: item.is_pro_exclusive,
        })),
        ownedItemIds: (inventoryResult.data ?? []).map(
          (inventory) => inventory.item_id,
        ),
        equipped: {
          characterId: profileResult.data.equipped_avatar_id,
          towerId: profileResult.data.equipped_tower_id,
          arenaId: profileResult.data.equipped_arena_id,
        },
      },
    };
  }

  async purchase(userId: string, payload: PurchaseStoreItemPayload) {
    const itemId = this.requiredText(payload.itemId, 'itemId', 120);
    const idempotencyKey = this.requiredText(
      payload.idempotencyKey,
      'idempotencyKey',
      160,
    );
    const { data, error } = await this.supabaseService
      .getClient()
      .rpc('purchase_store_item', {
        p_user_id: userId,
        p_item_id: itemId,
        p_idempotency_key: idempotencyKey,
      });

    if (error) {
      this.throwEconomyError(error.message);
    }

    return { data: this.requireObject(data, 'purchase_store_item') };
  }

  async setLoadout(userId: string, payload: SetStoreLoadoutPayload) {
    const characterId = this.optionalText(payload.characterId, 'characterId');
    const towerId = this.optionalText(payload.towerId, 'towerId');
    const arenaId = this.optionalText(payload.arenaId, 'arenaId');
    if (!characterId && !towerId && !arenaId) {
      throw new BadRequestException(
        'At least one of characterId, towerId, or arenaId is required.',
      );
    }

    const { data, error } = await this.supabaseService
      .getClient()
      .rpc('set_profile_loadout', {
        p_user_id: userId,
        p_avatar_id: characterId ?? null,
        p_tower_id: towerId ?? null,
        p_arena_id: arenaId ?? null,
      });

    if (error) {
      this.throwEconomyError(error.message);
    }

    return { data: this.requireObject(data, 'set_profile_loadout') };
  }

  async grantBetaCredit(userId: string, payload: GrantBetaCreditPayload) {
    if (!this.betaCreditEnabled()) {
      throw new ForbiddenException(
        'FEATURE_DISABLED: Beta Y-Coin credit is disabled.',
      );
    }

    const idempotencyKey = this.requiredText(
      payload.idempotencyKey,
      'idempotencyKey',
      160,
    );
    const requestedCoins = this.betaCreditAmount(payload.coins);
    const iterations = requestedCoins / 100;

    let lastResult: Json | null = null;
    for (let index = 0; index < iterations; index += 1) {
      const subKey =
        iterations === 1 ? idempotencyKey : `${idempotencyKey}-${index}`;
      const { data, error } = await this.supabaseService
        .getClient()
        .rpc('grant_beta_credit', {
          p_user_id: userId,
          p_idempotency_key: subKey,
        });

      if (error) {
        this.throwEconomyError(error.message);
      }
      lastResult = data;
    }

    return { data: this.requireObject(lastResult, 'grant_beta_credit') };
  }

  private optionalItemType(value: string | undefined): string | undefined {
    if (value === undefined || value.trim() === '') {
      return undefined;
    }
    const normalized = value.trim().toLowerCase();
    if (!STORE_ITEM_TYPES.has(normalized)) {
      throw new BadRequestException(
        'type must be character_skin, arena, or tower.',
      );
    }
    return normalized;
  }

  private requiredText(value: unknown, field: string, maxLength: number) {
    if (typeof value !== 'string' || value.trim() === '') {
      throw new BadRequestException(`${field} is required.`);
    }
    const normalized = value.trim();
    if (normalized.length > maxLength) {
      throw new BadRequestException(
        `${field} must not exceed ${maxLength} characters.`,
      );
    }
    return normalized;
  }

  private optionalText(value: unknown, field: string) {
    if (value === undefined || value === null) {
      return undefined;
    }
    return this.requiredText(value, field, 120);
  }

  private betaCreditEnabled() {
    return (
      this.configService
        .get<string>('ENABLE_BETA_ECONOMY_CREDIT', 'false')
        .trim()
        .toLowerCase() === 'true'
    );
  }

  private betaCreditAmount(value: unknown): number {
    if (value === undefined || value === null) {
      return 100;
    }
    const amount =
      typeof value === 'number'
        ? value
        : typeof value === 'string' && value.trim() !== ''
          ? Number(value)
          : Number.NaN;
    if (
      !Number.isInteger(amount) ||
      amount < 100 ||
      amount > 10_000 ||
      amount % 100 !== 0
    ) {
      throw new BadRequestException(
        'coins must be a multiple of 100 between 100 and 10000.',
      );
    }
    return amount;
  }

  private requireObject(value: Json, operation: string) {
    if (!value || Array.isArray(value) || typeof value !== 'object') {
      throw new InternalServerErrorException(
        `${operation} returned an invalid result.`,
      );
    }
    return value;
  }

  private throwEconomyError(message: string): never {
    const normalized = message.toLowerCase();
    if (message.includes('INSUFFICIENT_Y_COIN')) {
      throw new ConflictException(message);
    }
    if (normalized.includes('already owned')) {
      throw new ConflictException(message);
    }
    if (normalized.includes('idempotency key was already used')) {
      throw new ConflictException(message);
    }
    if (normalized.includes('not available')) {
      throw new NotFoundException(message);
    }
    if (
      normalized.includes('insufficient') ||
      normalized.includes('only available') ||
      normalized.includes('not owned')
    ) {
      throw new BadRequestException(message);
    }
    throw new InternalServerErrorException(message);
  }
}
