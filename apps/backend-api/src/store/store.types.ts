export interface StoreItemsQuery {
  type?: string;
}

export interface PurchaseStoreItemPayload {
  itemId?: unknown;
  idempotencyKey?: unknown;
}

export interface SetStoreLoadoutPayload {
  characterId?: unknown;
  towerId?: unknown;
  arenaId?: unknown;
}
