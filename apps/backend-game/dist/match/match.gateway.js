"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MatchGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
const supabase_service_1 = require("../supabase/supabase.service");
let MatchGateway = class MatchGateway {
    supabaseService;
    server;
    connectedPlayers = new Map();
    constructor(supabaseService) {
        this.supabaseService = supabaseService;
    }
    async handleConnection(client) {
        try {
            let token = client.handshake.auth?.token;
            if (!token && client.handshake.headers.authorization) {
                token = client.handshake.headers.authorization.split(' ')[1];
            }
            if (!token)
                throw new Error('No token provided');
            const supabase = this.supabaseService.getClient();
            const { data: { user }, error } = await supabase.auth.getUser(token);
            if (error || !user)
                throw new Error('Invalid token');
            this.connectedPlayers.set(client.id, user.id);
            console.log(`🟢 Player Connected: ${user.id} (Socket: ${client.id})`);
            client.emit('connection_success', { message: 'Welcome to the Arena!' });
        }
        catch (error) {
            console.log(`🔴 Connection Rejected: ${error.message}`);
            client.disconnect();
        }
    }
    handleDisconnect(client) {
        const playerId = this.connectedPlayers.get(client.id);
        if (playerId) {
            console.log(`🔴 Player Disconnected: ${playerId}`);
            this.connectedPlayers.delete(client.id);
        }
    }
    handlePing(client, payload) {
        const playerId = this.connectedPlayers.get(client.id);
        client.emit('pong_client', {
            message: `Hello player ${playerId}, I received your data!`,
            yourData: payload
        });
    }
};
exports.MatchGateway = MatchGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], MatchGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('ping_server'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], MatchGateway.prototype, "handlePing", null);
exports.MatchGateway = MatchGateway = __decorate([
    (0, websockets_1.WebSocketGateway)({ namespace: '/match', cors: true }),
    __metadata("design:paramtypes", [supabase_service_1.SupabaseService])
], MatchGateway);
//# sourceMappingURL=match.gateway.js.map