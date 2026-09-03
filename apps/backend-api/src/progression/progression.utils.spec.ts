import { rankTier } from './progression.utils';

describe('rankTier', () => {
  it.each([
    [0, 'rookie'],
    [399, 'rookie'],
    [400, 'warrior'],
    [799, 'warrior'],
    [800, 'elite'],
    [1199, 'elite'],
    [1200, 'legend'],
  ])('maps %i rank points to %s', (points, tier) => {
    expect(rankTier(points)).toBe(tier);
  });
});
