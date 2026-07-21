import { Test, TestingModule } from '@nestjs/testing';
import { MatchService } from './match.service';
import { GameEngine } from './engine/game-engine';
import { QuestionDealer } from './engine/question-dealer';
import { QuestionService } from './questions/question.service';
import { MatchResultService } from './results/match-result.service';
import { RoomManager } from './rooms/room-manager';
import { MatchLogBuffer } from './logs/match-log-buffer';

const mockMatchResultService = {
  finalizeMatch: jest.fn().mockResolvedValue(null),
};

describe('MatchService', () => {
  let service: MatchService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MatchService,
        GameEngine,
        QuestionDealer,
        QuestionService,
        RoomManager,
        MatchLogBuffer,
        { provide: MatchResultService, useValue: mockMatchResultService },
      ],
    }).compile();

    service = module.get<MatchService>(MatchService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('pairs two queued players and emits initial player-relative state', () => {
    service.registerSocket('socket-a', 'player-a');
    service.registerSocket('socket-b', 'player-b');

    service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
    const result = service.handleJoinQueue('player-b', 'socket-b', { mode: 'casual' });

    expect(result.emits.some((emit) => emit.event === 'match_found')).toBe(true);
    const stateEmits = result.emits.filter((emit) => emit.event === 'game_state_update');
    expect(stateEmits).toHaveLength(2);
    expect(stateEmits[0].payload).toHaveProperty('self');
    expect(stateEmits[0].payload).toHaveProperty('opponent');
  });

  it('rejects active-room user joining queue again', () => {
    service.registerSocket('socket-a', 'player-a');
    service.registerSocket('socket-b', 'player-b');
    service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });
    service.handleJoinQueue('player-b', 'socket-b', { mode: 'casual' });

    const result = service.handleJoinQueue('player-a', 'socket-a', { mode: 'casual' });

    expect(result.emits[0].event).toBe('error');
  });
});
