export function asNumber(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function wibBusinessDate(at = new Date()): string {
  const wib = new Date(at.getTime() + 7 * 60 * 60 * 1000);
  return wib.toISOString().slice(0, 10);
}
