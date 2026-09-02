import { BadRequestException } from '@nestjs/common';
import { LeaderboardRepository } from './leaderboard.repository';
import { LeaderboardService } from './leaderboard.service';

describe('LeaderboardService Gate 1 contract', () => {
  let repository: jest.Mocked<LeaderboardRepository>;
  let service: LeaderboardService;

  beforeEach(() => {
    repository = {
      list: jest.fn(),
      getUserRank: jest.fn(),
    } as unknown as jest.Mocked<LeaderboardRepository>;
    service = new LeaderboardService(repository);
  });

  it('returns deterministic SQL-ranked pagination metadata', async () => {
    repository.list.mockResolvedValue({
      target: 'cpns',
      items: [entry()],
      total: 25,
    });
    await expect(service.list('user-1', { limit: '10', offset: '5' })).resolves.toEqual({
      data: {
        scope: { type: 'target', target: 'cpns' },
        algorithm: { id: 'elo-v1', initialRating: 1000, kFactor: 32 },
        items: [entry()],
        pagination: { limit: 10, offset: 5, total: 25 },
      },
    });
    expect(repository.list).toHaveBeenCalledWith('user-1', 10, 5);
  });

  it('returns my rank without loading the leaderboard page', async () => {
    repository.getUserRank.mockResolvedValue(entry());
    await expect(service.getMyRank('user-1')).resolves.toEqual({
      data: {
        scope: { type: 'target', target: 'cpns' },
        algorithm: { id: 'elo-v1', initialRating: 1000, kFactor: 32 },
        entry: entry(),
      },
    });
    expect(repository.list).not.toHaveBeenCalled();
  });

  it('rejects invalid pagination instead of silently changing it', async () => {
    await expect(service.list('user-1', { limit: '0' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(repository.list).not.toHaveBeenCalled();
  });
});

function entry() {
  return {
    rank: 6,
    userId: 'user-1',
    username: 'player',
    pvpRating: 1116,
    ratedMatches: 13,
    rankedWins: 8,
    rankedLosses: 4,
    rankedDraws: 1,
    rankedWinRate: 0.6154,
    status: 'rated' as const,
    target: 'cpns' as const,
  };
}
