export function asNumber(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

export type RankTier = 'rookie' | 'warrior' | 'elite' | 'legend';

export function rankTier(rankPoints: number): RankTier {
  if (rankPoints >= 1200) return 'legend';
  if (rankPoints >= 800) return 'elite';
  if (rankPoints >= 400) return 'warrior';
  return 'rookie';
}

export function wibBusinessDate(at = new Date()): string {
  const wib = new Date(at.getTime() + 7 * 60 * 60 * 1000);
  return wib.toISOString().slice(0, 10);
}
