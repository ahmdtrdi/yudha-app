import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AnalyticsController } from '../src/analytics/analytics.controller';
import { AnalyticsService } from '../src/analytics/analytics.service';
import { SupabaseAuthGuard } from '../src/auth/guards/supabase-auth.guard';
import { LeaderboardController } from '../src/leaderboard/leaderboard.controller';
import { LeaderboardService } from '../src/leaderboard/leaderboard.service';
import { LobbyController } from '../src/lobby/lobby.controller';
import { LobbyService } from '../src/lobby/lobby.service';
import { PracticeController } from '../src/practice/practice.controller';
import { PracticeService } from '../src/practice/practice.service';
import { ProfileController } from '../src/profile/profile.controller';
import { ProfileService } from '../src/profile/profile.service';

describe('Gate 1 REST contracts (e2e)', () => {
  let app: INestApplication;
  const lobby = {
    profile: { id: 'user-1', username: 'player', target: 'cpns' },
    tier: 'rookie',
    rankPoints: 50,
    yCoins: 0,
    dailyMissions: [{ key: 'daily_practice' }, { key: 'daily_pvp' }],
    streak: { current: 1, best: 1 },
    hiredPassSummary: { passPoints: 0 },
    recommendation: { type: 'practice', target: 'cpns' },
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [
        LobbyController,
        AnalyticsController,
        LeaderboardController,
        PracticeController,
        ProfileController,
      ],
      providers: [
        {
          provide: LobbyService,
          useValue: {
            getSummary: jest.fn().mockResolvedValue({ data: lobby }),
          },
        },
        {
          provide: AnalyticsService,
          useValue: {
            getPerformanceAnalytics: jest
              .fn()
              .mockResolvedValue({
                data: { recommendation: lobby.recommendation },
              }),
          },
        },
        {
          provide: LeaderboardService,
          useValue: {
            list: jest
              .fn()
              .mockResolvedValue({
                data: { items: [], limit: 20, offset: 0, total: 0 },
              }),
            getMyRank: jest
              .fn()
              .mockResolvedValue({ data: { rank: 1, userId: 'user-1' } }),
          },
        },
        {
          provide: PracticeService,
          useValue: {
            createSession: jest
              .fn()
              .mockResolvedValue({
                data: {
                  sessionId: 'session-1',
                  totalQuestions: 5,
                  questions: [],
                },
              }),
          },
        },
        {
          provide: ProfileService,
          useValue: {
            getProfile: jest.fn().mockResolvedValue({ data: lobby.profile }),
          },
        },
      ],
    })
      .overrideGuard(SupabaseAuthGuard)
      .useValue({
        canActivate: (context: any) => {
          context.switchToHttp().getRequest().user = { id: 'user-1' };
          return true;
        },
      })
      .compile();

    app = module.createNestApplication();
    await app.init();
  });

  afterAll(async () => app.close());

  it('serves Lobby, analytics, profile, leaderboard, and optional-category Practice', async () => {
    await request(app.getHttpServer())
      .get('/lobby/summary')
      .expect(200, { data: lobby });
    await request(app.getHttpServer())
      .get('/analytics')
      .expect(200, {
        data: { recommendation: lobby.recommendation },
      });
    await request(app.getHttpServer())
      .get('/profile')
      .expect(200, { data: lobby.profile });
    await request(app.getHttpServer())
      .get('/leaderboard')
      .expect(200, {
        data: { items: [], limit: 20, offset: 0, total: 0 },
      });
    await request(app.getHttpServer())
      .post('/practice/sessions')
      .send({})
      .expect(201, {
        data: { sessionId: 'session-1', totalQuestions: 5, questions: [] },
      });
  });
});
