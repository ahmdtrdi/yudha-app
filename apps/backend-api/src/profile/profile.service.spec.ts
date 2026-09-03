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
  const rpc = jest.fn();
  const deleteUser = jest.fn();

  beforeEach(async () => {
    from.mockReset();
    select.mockReset();
    eq.mockReset();
    single.mockReset();
    update.mockReset();
    rpc.mockReset();
    deleteUser.mockReset();

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
            getClient: () => ({
              from,
              rpc,
              auth: { admin: { deleteUser } },
            }),
          },
        },
      ],
    }).compile();

    service = module.get<ProfileService>(ProfileService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('returns the PRD camelCase profile projection', async () => {
    const profile = {
      id: 'user-1',
      username: 'player',
      full_name: 'Player One',
      target: 'cpns',
      rank_points: 1000,
      total_matches: 0,
      wins: 0,
      losses: 0,
      draws: 2,
      winrate: 0,
      coins: 0,
      equipped_avatar_id: null,
      equipped_arena_id: null,
      equipped_tower_id: 'tower-garda-biru',
      current_streak: 3,
      best_streak: 7,
      last_streak_date: '2026-08-17',
      created_at: '2026-06-04T00:00:00Z',
      updated_at: '2026-06-04T00:00:00Z',
    };
    single.mockResolvedValue({ data: profile, error: null });

    await expect(service.getProfile('user-1')).resolves.toEqual({
      data: {
        id: 'user-1',
        username: 'player',
        fullName: 'Player One',
        target: 'cpns',
        rankPoints: 1000,
        tier: 'elite',
        rankedStats: {
          wins: 0,
          losses: 0,
          draws: 2,
          winRate: 0,
        },
        yCoins: 0,
        energy: {
          balance: 0,
          refilledOn: null,
        },
        characterId: null,
        towerId: 'tower-garda-biru',
        streak: {
          current: 3,
          best: 7,
          lastDate: '2026-08-17',
        },
      },
    });

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
        fullName: null,
        target: 'bumn',
      }),
    ).resolves.toEqual({
      data: expect.objectContaining({
        id: 'user-1',
        username: 'player-two',
        fullName: null,
        target: 'bumn',
      }),
    });

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

  it('accepts the snake_case full_name field used by the mobile client', async () => {
    const updatedProfile = {
      id: 'user-1',
      username: 'player',
      full_name: 'Player Updated',
      target: 'cpns',
    };
    single.mockResolvedValue({ data: updatedProfile, error: null });

    await expect(
      service.updateProfile('user-1', { full_name: 'Player Updated' }),
    ).resolves.toEqual({
      data: expect.objectContaining({ fullName: 'Player Updated' }),
    });

    expect(update).toHaveBeenCalledWith({ full_name: 'Player Updated' });
  });

  it('rejects attempts to update protected progression fields', async () => {
    await expect(
      service.updateProfile('user-1', { coins: 999999, rank_points: 99999 }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(from).not.toHaveBeenCalled();
  });

  it('updates loadout through the ownership-validating RPC', async () => {
    rpc.mockResolvedValue({
      data: {
        characterId: 'character-basic-pip',
        towerId: 'tower-garda-biru',
      },
      error: null,
    });

    await expect(
      service.updateLoadout('user-1', {
        characterId: 'character-basic-pip',
      }),
    ).resolves.toEqual({
      data: {
        characterId: 'character-basic-pip',
        towerId: 'tower-garda-biru',
      },
    });
    expect(rpc).toHaveBeenCalledWith('set_profile_loadout', {
      p_user_id: 'user-1',
      p_avatar_id: 'character-basic-pip',
      p_tower_id: undefined,
      p_arena_id: undefined,
    });
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

  it('resets user-owned data and returns the fresh profile', async () => {
    rpc.mockResolvedValue({ data: null, error: null });
    single.mockResolvedValue({
      data: { id: 'user-1', username: 'player', target: 'cpns' },
      error: null,
    });

    await expect(service.deleteAccountData('user-1')).resolves.toEqual({
      data: expect.objectContaining({
        id: 'user-1',
        username: 'player',
      }),
      message: 'Account data deleted.',
    });
    expect(rpc).toHaveBeenCalledWith('reset_user_account_data', {
      p_user_id: 'user-1',
    });
  });

  it('deletes the Supabase auth user', async () => {
    deleteUser.mockResolvedValue({ data: null, error: null });

    await expect(service.deleteAccount('user-1')).resolves.toEqual({
      message: 'Account deleted.',
    });
    expect(deleteUser).toHaveBeenCalledWith('user-1');
  });
});
