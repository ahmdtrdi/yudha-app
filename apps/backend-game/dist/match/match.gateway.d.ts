import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { SupabaseService } from '../supabase/supabase.service';
export declare class MatchGateway implements OnGatewayConnection, OnGatewayDisconnect {
    private readonly supabaseService;
    server: Server;
    private connectedPlayers;
    constructor(supabaseService: SupabaseService);
    handleConnection(client: Socket): Promise<void>;
    handleDisconnect(client: Socket): void;
    handlePing(client: Socket, payload: any): void;
}
