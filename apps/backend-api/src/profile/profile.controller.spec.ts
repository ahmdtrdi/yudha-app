import { Test, TestingModule } from '@nestjs/testing';
import { SupabaseAuthGuard } from '../auth/guards/supabase-auth.guard';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';

describe('ProfileController', () => {
  let controller: ProfileController;
  const getProfile = jest.fn();
  const updateProfile = jest.fn();

  beforeEach(async () => {
    getProfile.mockReset();
    updateProfile.mockReset();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ProfileController],
      providers: [
        {
          provide: ProfileService,
          useValue: {
            getProfile,
            updateProfile,
          },
        },
      ],
    })
      .overrideGuard(SupabaseAuthGuard)
      .useValue({ canActivate: jest.fn(() => true) })
      .compile();

    controller = module.get<ProfileController>(ProfileController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('fetches the authenticated user profile', async () => {
    const profile = { id: 'user-1', username: 'player' };
    getProfile.mockResolvedValue(profile);

    await expect(controller.getMyProfile({ id: 'user-1' } as never)).resolves.toEqual(
      profile,
    );
    expect(getProfile).toHaveBeenCalledWith('user-1');
  });

  it('updates the authenticated user profile', async () => {
    const profile = { id: 'user-1', username: 'player-two' };
    const payload = { username: 'player-two', coins: 10 };
    updateProfile.mockResolvedValue(profile);

    await expect(
      controller.updateMyProfile({ id: 'user-1' } as never, payload),
    ).resolves.toEqual(profile);
    expect(updateProfile).toHaveBeenCalledWith('user-1', payload);
  });
});
