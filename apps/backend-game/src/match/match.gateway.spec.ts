import { Test, TestingModule } from '@nestjs/testing';
import { SupabaseService } from '../supabase/supabase.service';
import { MatchGateway } from './match.gateway';
import { MatchService } from './match.service';

describe('MatchGateway', () => {
  let gateway: MatchGateway;
  const matchService = {
    setEmitServer: jest.fn(),
    registerSocket: jest.fn(),
    getUserIdForSocket: jest.fn(),
    handleDisconnect: jest.fn(() => ({ emits: [] })),
    handleJoinQueue: jest.fn(() => ({ emits: [] })),
    handleCancelQueue: jest.fn(() => ({ emits: [] })),
    handleCreatePrivateRoom: jest.fn(),
    handleJoinPrivateRoom: jest.fn(),
    handleCancelPrivateRoom: jest.fn(),
    handleOpenCard: jest.fn(() => ({ emits: [] })),
    handlePlayCard: jest.fn(() => ({ emits: [] })),
    handleSurrender: jest.fn(() => ({ emits: [] })),
  };

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
          useValue: matchService,
        },
      ],
    }).compile();

    gateway = module.get<MatchGateway>(MatchGateway);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(gateway).toBeDefined();
  });

  it('acknowledges a Private command before emitting its domain event', async () => {
    const emit = jest.fn();
    const acknowledgement = jest.fn();
    gateway.server = {
      to: jest.fn(() => ({ emit })),
    } as never;
    matchService.getUserIdForSocket.mockReturnValue('player-a');
    matchService.handleCreatePrivateRoom.mockResolvedValue({
      ack: {
        data: {
          code: 'ABC234',
          target: 'cpns',
          expiresAt: '2026-08-18T01:15:00.000Z',
        },
        requestId: 'request-1',
      },
      emits: [
        {
          socketId: 'socket-a',
          event: 'private_room_created',
          payload: { code: 'ABC234' },
        },
      ],
    });

    await gateway.handleCreatePrivateRoom(
      { id: 'socket-a', emit: jest.fn() } as never,
      { commandId: 'create-1' },
      acknowledgement,
    );

    expect(acknowledgement).toHaveBeenCalledTimes(1);
    expect(emit).toHaveBeenCalledTimes(1);
    expect(acknowledgement.mock.invocationCallOrder[0]).toBeLessThan(
      emit.mock.invocationCallOrder[0],
    );
  });
});
