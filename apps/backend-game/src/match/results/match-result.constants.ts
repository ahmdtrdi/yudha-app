/** Rating delta applied to rank_points after a PvP match */
export const RATING_DELTA = {
  WIN: 20,
  LOSE: -12,
  DRAW: 0,
} as const;

/** Coin rewards applied after any match (including bot) */
export const COINS_DELTA = {
  WIN: 10,
  LOSE: 3,
  DRAW: 5,
} as const;
