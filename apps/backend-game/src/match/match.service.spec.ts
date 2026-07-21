import { Test, TestingModule } from '@nestjs/testing';
import { MatchService } from './match.service';
import { GameEngine } from './engine/game-engine';
import { QuestionDealer } from './engine/question-dealer';
import { QuestionService } from './questions/question.service';
import { MatchResultService } from './results/match-result.service';
import { RoomManager } from './rooms/room-manager';
import { MatchLogBuffer } from './logs/match-log-buffer';
import { BotBattleService } from './bot/bot-battle.service';
import { SupabaseService } from '../supabase/supabase.service';
import type { InternalCard } from './questions/question.types';

/** Stub cards for testing — mimics DB-sourced values */
const STUB_CARDS: InternalCard[] = Array.from({ length: 12 }, (_, i) => ({
  id: `card_${i + 1}`,
  prompt: `Question ${i + 1}`,
  options: ['A', 'B', 'C', 'D'],
  correctOptionIndex: 0,
  weight: 1,
  effect: i % 3 === 0 ? 'heal' as const : 'damage' as const,
  damageValue: i % 3 === 0 ? 0 : 14,
  healValue: i % 3 === 0 ? 14 : 0,
  timeLimitSeconds: 30,
}));

const mockMatchResultService = {
  finalizeMatch: jest.fn().mockResolvedValue(null),
};

const mockQuestionService = {
  getMatchQuestionPool: jest.fn().mockResolvedValue(STUB_CARDS),
};

const mockBotBattleService = {
  createBotMatch: jest.fn(),
  cancelBotSchedule: jest.fn(),
  isBotMatch: jest.fn().mockReturnValue(false),
  setEmitCallback: jest.fn(),
};

const mockSupabaseService = {
  getClient: jest.fn(),
  getAdminClient: jest.fn(),
};

describe('MatchService', () => {
  let service: MatchService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MatchService,
        GameEngine,
        QuestionDealer,
        RoomManager,
        MatchLogBuffer,
        { provide: QuestionService, useValue: mockQuestionService },
        { provide: MatchResultService, useValue: mockMatchResultService },
        { provide: BotBattleService, useValue: mockBotBattleService },
        { provide: SupabaseService, useValue: mockSupabaseService },
      ],
    }).compile();

    service = module.get<MatchService>(MatchService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('pairs two queued players and emits initial player-relative state', async () => {
    service.registerSocket('socket-a', 'player-a');
    service.registerSocket('socket-b', 'player-b');

    await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
    const result = await service.handleJoinQueue('player-b', 'socket-b', { mode: 'casual' });

    expect(result.emits.some((emit) => emit.event === 'match_found')).toBe(true);
    const stateEmits = result.emits.filter((emit) => emit.event === 'game_state_update');
    expect(stateEmits).toHaveLength(2);
    expect(stateEmits[0].payload).toHaveProperty('self');
    expect(stateEmits[0].payload).toHaveProperty('opponent');
  });

  it('rejects active-room user joining queue again', async () => {
    service.registerSocket('socket-a', 'player-a');
    service.registerSocket('socket-b', 'player-b');
    await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
    await service.handleJoinQueue('player-b', 'socket-b', { mode: 'casual' });

    const result = await service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });

    expect(result.emits[0].event).toBe('error');
  });
});
