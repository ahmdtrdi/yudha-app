import {
  BadRequestException,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { SupabaseService } from '../supabase/supabase.service';
import { ProfileService } from './profile.service';

describe('ProfileService', () => {
  let service: ProfileService;
  const from = jest.fn();
  const select = jest.fn();
  const eq = jest.fn();
  const single = jest.fn();
  const update = jest.fn();

  beforeEach(async () => {
    from.mockReset();
    select.mockReset();
    eq.mockReset();
    single.mockReset();
    update.mockReset();

    from.mockReturnValue({ select, update });
    select.mockReturnValue({ eq, single });
    update.mockReturnValue({ eq });
    eq.mockReturnValue({ select, single });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProfileService,
        {
          provide: SupabaseService,
          useValue: {
            getClient: () => ({ from }),
          },
        },
      ],
    }).compile();

    service = module.get<ProfileService>(ProfileService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('fetches every profile column for the authenticated user', async () => {
    const profile = {
      id: 'user-1',
      username: 'player',
      full_name: 'Player One',
      target: 'cpns',
      rank_points: 1000,
      total_matches: 0,
      wins: 0,
      losses: 0,
      winrate: 0,
      coins: 0,
      equipped_avatar_id: null,
      equipped_arena_id: null,
      created_at: '2026-06-04T00:00:00Z',
      updated_at: '2026-06-04T00:00:00Z',
    };
    single.mockResolvedValue({ data: profile, error: null });

    await expect(service.getProfile('user-1')).resolves.toEqual(profile);

    expect(from).toHaveBeenCalledWith('profiles');
    expect(select).toHaveBeenCalledWith('*');
    expect(eq).toHaveBeenCalledWith('id', 'user-1');
    expect(single).toHaveBeenCalled();
  });

  it('updates profile fields and returns the updated full profile', async () => {
    const updatedProfile = {
      id: 'user-1',
      username: 'player-two',
      full_name: null,
      target: 'bumn',
    };
    single.mockResolvedValue({ data: updatedProfile, error: null });

    await expect(
      service.updateProfile('user-1', {
        username: 'player-two',
        full_name: null,
        target: 'bumn',
        ignoredUndefined: undefined,
      }),
    ).resolves.toEqual(updatedProfile);

    expect(from).toHaveBeenCalledWith('profiles');
    expect(update).toHaveBeenCalledWith({
      username: 'player-two',
      full_name: null,
      target: 'bumn',
    });
    expect(eq).toHaveBeenCalledWith('id', 'user-1');
    expect(select).toHaveBeenCalledWith('*');
    expect(single).toHaveBeenCalled();
  });

  it('rejects empty update payloads', async () => {
    await expect(service.updateProfile('user-1', {})).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(from).not.toHaveBeenCalled();
  });

  it('maps missing profile rows to not found', async () => {
    single.mockResolvedValue({
      data: null,
      error: { code: 'PGRST116', message: 'No rows found' },
    });

    await expect(service.getProfile('missing-user')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('maps Supabase profile errors to internal server errors', async () => {
    single.mockResolvedValue({
      data: null,
      error: { message: 'database error' },
    });

    await expect(service.getProfile('user-1')).rejects.toBeInstanceOf(
      InternalServerErrorException,
    );
  });
});
