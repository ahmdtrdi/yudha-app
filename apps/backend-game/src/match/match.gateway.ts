import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { CLIENT_MATCH_EVENTS } from '../../../../contracts/match.events';
import type {
  JoinQueuePayload,
  OpenCardPayload,
  PlayCardPayload,
  SurrenderPayload,
} from '../../../../contracts/match.payloads';
import { SupabaseService } from '../supabase/supabase.service';
import { MatchService, type MatchServiceResult } from './match.service';

@WebSocketGateway({ namespace: '/match', cors: true })
export class MatchGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly matchService: MatchService,
  ) {}

  afterInit(): void {
    this.matchService.setEmitServer(({ emits }) => {
      for (const emit of emits) {
        this.server.to(emit.socketId).emit(emit.event, emit.payload);
      }
    });
  }

  async handleConnection(client: Socket) {
    try {
      let token = client.handshake.auth?.token;
      if (!token && client.handshake.headers.authorization) {
        token = client.handshake.headers.authorization.split(' ')[1];
      }
      if (!token) throw new Error('No token provided');

      const supabase = this.supabaseService.getClient();
      const {
        data: { user },
        error,
      } = await supabase.auth.getUser(token);

      if (error || !user) throw new Error('Invalid token');

      this.matchService.registerSocket(client.id, user.id);
      client.emit('connection_success', { message: 'Welcome to the Arena!' });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Connection rejected';
      client.emit('error', { message });
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    this.emitAll(this.matchService.handleDisconnect(client.id));
  }

  @SubscribeMessage('ping_server')
  handlePing(@ConnectedSocket() client: Socket, @MessageBody() payload: unknown) {
    const playerId = this.matchService.getUserIdForSocket(client.id);
    client.emit('pong_client', {
      message: `Hello player ${playerId}, I received your data!`,
      yourData: payload,
    });
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.joinQueue)
  handleJoinQueue(@ConnectedSocket() client: Socket, @MessageBody() payload?: JoinQueuePayload) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.emitAll(this.matchService.handleJoinQueue(userId, client.id, payload));
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.cancelQueue)
  handleCancelQueue(@ConnectedSocket() client: Socket) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.emitAll(this.matchService.handleCancelQueue(userId, client.id));
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.openCard)
  handleOpenCard(@ConnectedSocket() client: Socket, @MessageBody() payload: OpenCardPayload) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.emitAll(this.matchService.handleOpenCard(userId, client.id, payload));
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.playCard)
  async handlePlayCard(@ConnectedSocket() client: Socket, @MessageBody() payload: PlayCardPayload) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.emitAll(await this.matchService.handlePlayCard(userId, client.id, payload));
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.surrender)
  async handleSurrender(@ConnectedSocket() client: Socket, @MessageBody() payload: SurrenderPayload) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.emitAll(await this.matchService.handleSurrender(userId, client.id, payload));
  }

  private emitAll(result: MatchServiceResult): void {
    for (const emit of result.emits) {
      this.server.to(emit.socketId).emit(emit.event, emit.payload);
    }
  }

  private requireUser(client: Socket): string | undefined {
    const userId = this.matchService.getUserIdForSocket(client.id);
    if (!userId) {
      client.emit('error', { message: 'Socket is not authenticated.' });
      return undefined;
    }
    return userId;
  }
}
