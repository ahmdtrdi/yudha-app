import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { SupabaseService } from '../supabase/supabase.service'; // Assuming you share this module

// We open the socket server on a specific namespace, e.g., /match
@WebSocketGateway({ namespace: '/match', cors: true })
export class MatchGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  // Keep track of who is online: Map<SocketId, PlayerId>
  private connectedPlayers = new Map<string, string>();

  constructor(private readonly supabaseService: SupabaseService) {}

  // 1. A player tries to connect their Flutter app to the arena
  async handleConnection(client: Socket) {
    try {
      // 1. Try to get the token from Flutter's auth payload
      let token = client.handshake.auth?.token;

      // 2. Fallback for Postman: Try to get it from the standard Authorization header
      if (!token && client.handshake.headers.authorization) {
        token = client.handshake.headers.authorization.split(' ')[1];
      }

      // If STILL no token, kick them out
      if (!token) throw new Error('No token provided');

      const supabase = this.supabaseService.getClient();
      const { data: { user }, error } = await supabase.auth.getUser(token);

      if (error || !user) throw new Error('Invalid token');

      // Success! Let them in
      this.connectedPlayers.set(client.id, user.id);
      console.log(`🟢 Player Connected: ${user.id} (Socket: ${client.id})`);

      client.emit('connection_success', { message: 'Welcome to the Arena!' });

    } catch (error) {
      console.log(`🔴 Connection Rejected: ${error.message}`);
      client.disconnect(); 
    }
  }

  // 3. A player closes the app or loses internet
  handleDisconnect(client: Socket) {
    const playerId = this.connectedPlayers.get(client.id);
    if (playerId) {
      console.log(`🔴 Player Disconnected: ${playerId}`);
      this.connectedPlayers.delete(client.id);
      
      // TODO: If they are in a match, auto-forfeit them!
    }
  }

  // 4. A test event to make sure Flutter can talk to NestJS
  @SubscribeMessage('ping_server')
  handlePing(@ConnectedSocket() client: Socket, @MessageBody() payload: any) {
    const playerId = this.connectedPlayers.get(client.id);
    
    // Send a message back ONLY to the player who pinged
    client.emit('pong_client', { 
      message: `Hello player ${playerId}, I received your data!`,
      yourData: payload 
    });
  }
}