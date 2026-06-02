import { Test, TestingModule } from '@nestjs/testing';
import { SupabaseService } from '../supabase/supabase.service';
import { MatchGateway } from './match.gateway';
import { MatchService } from './match.service';

describe('MatchGateway', () => {
  let gateway: MatchGateway;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MatchGateway,
        {
          provide: SupabaseService,
          useValue: {
            getClient: jest.fn(),
          },
        },
        {
          provide: MatchService,
          useValue: {
            registerSocket: jest.fn(),
            getUserIdForSocket: jest.fn(),
            handleDisconnect: jest.fn(() => ({ emits: [] })),
            handleJoinQueue: jest.fn(() => ({ emits: [] })),
            handleCancelQueue: jest.fn(() => ({ emits: [] })),
            handleOpenCard: jest.fn(() => ({ emits: [] })),
            handlePlayCard: jest.fn(() => ({ emits: [] })),
            handleSurrender: jest.fn(() => ({ emits: [] })),
          },
        },
      ],
    }).compile();

    gateway = module.get<MatchGateway>(MatchGateway);
  });

  it('should be defined', () => {
    expect(gateway).toBeDefined();
  });
});
