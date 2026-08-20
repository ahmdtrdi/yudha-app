import {
  Ack,
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
import { CLIENT_MATCH_EVENTS } from '../contracts/match.events';
import type {
  CancelPrivateRoomPayload,
  CancelQueuePayload,
  CreatePrivateRoomPayload,
  JoinQueuePayload,
  JoinPrivateRoomPayload,
  OpenCardPayload,
  PlayCardPayload,
  SurrenderPayload,
} from '../contracts/match.payloads';
import { SupabaseService } from '../supabase/supabase.service';
import {
  MatchService,
  type MatchServiceResult,
  type PrivateCommandResult,
} from './match.service';

@WebSocketGateway({ namespace: '/match', cors: true })
export class MatchGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
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
      const authToken: unknown = client.handshake.auth?.token;
      let token = typeof authToken === 'string' ? authToken : undefined;
      const authorization = client.handshake.headers.authorization;
      if (!token && typeof authorization === 'string') {
        token = authorization.split(' ')[1];
      }
      if (!token) throw new Error('No token provided');

      const supabase = this.supabaseService.getClient();
      const {
        data: { user },
        error,
      } = await supabase.auth.getUser(token);

      if (error || !user) throw new Error('Invalid token');

      this.emitAll(await this.matchService.registerSocket(client.id, user.id));
      client.emit('connection_success', { message: 'Welcome to the Arena!' });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Connection rejected';
      client.emit('error', { message });
      client.disconnect();
    }
  }

  async handleDisconnect(client: Socket) {
    this.emitAll(await this.matchService.handleDisconnect(client.id));
  }

  @SubscribeMessage('ping_server')
  handlePing(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: unknown,
  ) {
    const playerId = this.matchService.getUserIdForSocket(client.id);
    client.emit('pong_client', {
      message: `Hello player ${playerId}, I received your data!`,
      yourData: payload,
    });
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.joinQueue)
  async handleJoinQueue(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload?: JoinQueuePayload,
    @Ack() acknowledgement?: (payload: unknown) => void,
  ) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.deliverPrivateResult(
      await this.matchService.handleAcknowledgedCommand(
        userId,
        payload?.commandId,
        CLIENT_MATCH_EVENTS.joinQueue,
        payload,
        () => this.matchService.handleJoinQueue(userId, client.id, payload),
      ),
      acknowledgement,
    );
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.cancelQueue)
  async handleCancelQueue(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload?: CancelQueuePayload,
    @Ack() acknowledgement?: (payload: unknown) => void,
  ) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.deliverPrivateResult(
      await this.matchService.handleAcknowledgedCommand(
        userId,
        payload?.commandId,
        CLIENT_MATCH_EVENTS.cancelQueue,
        payload,
        () => this.matchService.handleCancelQueue(userId, client.id),
      ),
      acknowledgement,
    );
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.createPrivateRoom)
  async handleCreatePrivateRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: CreatePrivateRoomPayload,
    @Ack() acknowledgement?: (payload: unknown) => void,
  ) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.deliverPrivateResult(
      await this.matchService.handleCreatePrivateRoom(
        userId,
        client.id,
        payload,
      ),
      acknowledgement,
    );
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.joinPrivateRoom)
  async handleJoinPrivateRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinPrivateRoomPayload,
    @Ack() acknowledgement?: (payload: unknown) => void,
  ) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.deliverPrivateResult(
      await this.matchService.handleJoinPrivateRoom(userId, client.id, payload),
      acknowledgement,
    );
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.cancelPrivateRoom)
  async handleCancelPrivateRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: CancelPrivateRoomPayload,
    @Ack() acknowledgement?: (payload: unknown) => void,
  ) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.deliverPrivateResult(
      await this.matchService.handleCancelPrivateRoom(
        userId,
        client.id,
        payload,
      ),
      acknowledgement,
    );
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.openCard)
  async handleOpenCard(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: OpenCardPayload,
    @Ack() acknowledgement?: (payload: unknown) => void,
  ) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.deliverPrivateResult(
      await this.matchService.handleAcknowledgedCommand(
        userId,
        payload?.commandId,
        CLIENT_MATCH_EVENTS.openCard,
        payload,
        () => this.matchService.handleOpenCard(userId, client.id, payload),
      ),
      acknowledgement,
    );
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.playCard)
  async handlePlayCard(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: PlayCardPayload,
    @Ack() acknowledgement?: (payload: unknown) => void,
  ) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.deliverPrivateResult(
      await this.matchService.handleAcknowledgedCommand(
        userId,
        payload?.commandId,
        CLIENT_MATCH_EVENTS.playCard,
        payload,
        () => this.matchService.handlePlayCard(userId, client.id, payload),
      ),
      acknowledgement,
    );
  }

  @SubscribeMessage(CLIENT_MATCH_EVENTS.surrender)
  async handleSurrender(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: SurrenderPayload,
    @Ack() acknowledgement?: (payload: unknown) => void,
  ) {
    const userId = this.requireUser(client);
    if (!userId) return;
    this.deliverPrivateResult(
      await this.matchService.handleAcknowledgedCommand(
        userId,
        payload?.commandId,
        CLIENT_MATCH_EVENTS.surrender,
        payload,
        () => this.matchService.handleSurrender(userId, client.id, payload),
      ),
      acknowledgement,
    );
  }

  private emitAll(result: MatchServiceResult): void {
    for (const emit of result.emits) {
      this.server.to(emit.socketId).emit(emit.event, emit.payload);
    }
  }

  private deliverPrivateResult(
    result: PrivateCommandResult,
    acknowledgement?: (payload: unknown) => void,
  ): void {
    acknowledgement?.(result.ack);
    this.emitAll(result);
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
