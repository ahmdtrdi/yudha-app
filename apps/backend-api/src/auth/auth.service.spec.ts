import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { SupabaseService } from '../supabase/supabase.service';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;
  const signUp = jest.fn();
  const signInWithPassword = jest.fn();

  beforeEach(async () => {
    signUp.mockReset();
    signInWithPassword.mockReset();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: SupabaseService,
          useValue: {
            getClient: () => ({
              auth: {
                signUp,
                signInWithPassword,
              },
            }),
          },
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  it('registers a user through Supabase Auth', async () => {
    signUp.mockResolvedValue({
      data: { user: { id: 'user-1' }, session: { access_token: 'token' } },
      error: null,
    });

    const result = await service.register({
      email: 'Player@Example.com',
      password: 'secret123',
      username: 'player',
      fullName: 'Player One',
    });

    expect(signUp).toHaveBeenCalledWith({
      email: 'player@example.com',
      password: 'secret123',
      options: {
        data: {
          username: 'player',
          full_name: 'Player One',
        },
      },
    });
    expect(result.session?.access_token).toBe('token');
  });

  it('logs in a user and returns a session', async () => {
    signInWithPassword.mockResolvedValue({
      data: { user: { id: 'user-1' }, session: { access_token: 'token' } },
      error: null,
    });

    const result = await service.login({
      email: 'player@example.com',
      password: 'secret123',
    });

    expect(signInWithPassword).toHaveBeenCalledWith({
      email: 'player@example.com',
      password: 'secret123',
    });
    expect(result.session?.access_token).toBe('token');
  });

  it('rejects invalid register input', async () => {
    await expect(service.register({ email: 'bad', password: '123' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('maps Supabase login errors to unauthorized', async () => {
    signInWithPassword.mockResolvedValue({
      data: { user: null, session: null },
      error: { message: 'Invalid login credentials' },
    });

    await expect(
      service.login({ email: 'player@example.com', password: 'secret123' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
