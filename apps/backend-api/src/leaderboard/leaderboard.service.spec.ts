import { BadRequestException, NotFoundException } from '@nestjs/common';
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
      items: [entry()],
      total: 25,
    });
    await expect(service.list({ limit: '10', offset: '5' })).resolves.toEqual({
      data: { items: [entry()], limit: 10, offset: 5, total: 25 },
    });
    expect(repository.list).toHaveBeenCalledWith(10, 5);
  });

  it('returns my rank without loading the leaderboard page', async () => {
    repository.getUserRank.mockResolvedValue(entry());
    await expect(service.getMyRank('user-1')).resolves.toEqual({
      data: entry(),
    });
    expect(repository.list).not.toHaveBeenCalled();
  });

  it('maps a missing profile to not found', async () => {
    repository.getUserRank.mockResolvedValue(null);
    await expect(service.getMyRank('missing')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('rejects invalid pagination instead of silently changing it', async () => {
    await expect(service.list({ limit: '0' })).rejects.toBeInstanceOf(
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
    rankPoints: 500,
    tier: 'warrior',
    rankedWins: 8,
    totalMatches: 13,
    rankedWinRate: 61.54,
  };
}
