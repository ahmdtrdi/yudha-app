export interface StoreItemsQuery {
  type?: string;
}

export interface PurchaseStoreItemPayload {
  itemId?: unknown;
  idempotencyKey?: unknown;
}

export interface GrantBetaCreditPayload {
  idempotencyKey?: unknown;
}

