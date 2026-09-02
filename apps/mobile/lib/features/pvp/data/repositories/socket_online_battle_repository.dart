import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/core/errors/user_facing_error.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/online_battle_repository.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/socket_command_acknowledger.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_session_seed.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/online_battle_update.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/private_room_reservation.dart';

class SocketOnlineBattleRepository extends OnlineBattleRepository {
  SocketOnlineBattleRepository({
    required String? accessToken,
    SocketCommandAcknowledger? commandAcknowledger,
  }) : _accessToken = accessToken,
       _commandAcknowledger =
           commandAcknowledger ?? SocketCommandAcknowledger();

  static const String _joinQueueEvent = 'join_queue';
  static const String _cancelQueueEvent = 'cancel_queue';
  static const String _createPrivateRoomEvent = 'create_private_room';
  static const String _joinPrivateRoomEvent = 'join_private_room';
  static const String _cancelPrivateRoomEvent = 'cancel_private_room';
  static const String _openCardEvent = 'open_card';
  static const String _playCardEvent = 'play_card';
  static const String _surrenderEvent = 'surrender';

  static const String _queueJoinedEvent = 'queue_joined';
  static const String _queueCancelledEvent = 'queue_cancelled';
  static const String _matchFoundEvent = 'match_found';
  static const String _privateRoomCreatedEvent = 'private_room_created';
  static const String _privateRoomJoinedEvent = 'private_room_joined';
  static const String _privateRoomCancelledEvent = 'private_room_cancelled';
  static const String _gameStateUpdateEvent = 'game_state_update';
  static const String _openCardAcceptedEvent = 'open_card_accepted';
  static const String _cardActionRejectedEvent = 'card_action_rejected';
  static const String _playCardResultEvent = 'play_card_result';
  static const String _matchResultEvent = 'match_result';
  static const String _presenceUpdateEvent = 'presence_update';
  static const String _errorEvent = 'error';
  static const String _connectionSuccessEvent = 'connection_success';

  final String? _accessToken;
  final SocketCommandAcknowledger _commandAcknowledger;
  final StreamController<OnlineBattleUpdate> _updatesController =
      StreamController<OnlineBattleUpdate>.broadcast();

  io.Socket? _socket;
  Future<void>? _connectionFuture;
  Completer<BattleSessionSeed>? _sessionCompleter;
  Completer<void>? _openCardCompleter;
  Completer<void>? _surrenderCompleter;
  String? _pendingOpenCardId;
  final Set<String> _submittedCardIds = <String>{};
  String? _roomId;
  String? _selfUserId;
  String? _opponentUserId;
  String _opponentName = 'Player Match';
  OnlineMatchmakingMode _currentMatchmakingMode = OnlineMatchmakingMode.casual;
  bool _disposed = false;

  @override
  Stream<OnlineBattleUpdate> get updates => _updatesController.stream;

  @override
  Future<void> reconnectIfActive() async {
    if (_accessToken == null || _accessToken.trim().isEmpty || _disposed) {
      return;
    }
    await _ensureConnected();
  }

  @override
  Future<BattleSessionSeed> createSession({
    OnlineMatchmakingMode matchmakingMode = OnlineMatchmakingMode.casual,
  }) async {
    if (_accessToken == null || _accessToken.trim().isEmpty) {
      throw StateError('Sesi login sudah berakhir. Silakan masuk ulang.');
    }

    if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
      throw StateError('Matchmaking masih berlangsung.');
    }

    final Completer<BattleSessionSeed> sessionCompleter =
        Completer<BattleSessionSeed>();
    _sessionCompleter = sessionCompleter;
    _currentMatchmakingMode = matchmakingMode;
    if (_roomId == null) {
      _selfUserId = null;
      _opponentUserId = null;
      _opponentName = 'Player Match';
      _submittedCardIds.clear();
    }

    try {
      await _ensureConnected();
      if (_roomId == null && !sessionCompleter.isCompleted) {
        await _emitAcknowledgedCommand(_joinQueueEvent, <String, Object?>{
          'mode': matchmakingMode.name,
        });
      }
      return await sessionCompleter.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      await _emitCancelQueue();
      throw TimeoutException('Matchmaking online sedang sibuk. Coba lagi.');
    } finally {
      if (identical(_sessionCompleter, sessionCompleter)) {
        _sessionCompleter = null;
      }
    }
  }

  @override
  Future<void> openCard({required String cardId}) async {
    final String roomId = _requireRoomId();
    await _ensureConnected();

    final Completer<void> completer = Completer<void>();
    _openCardCompleter = completer;
    _pendingOpenCardId = cardId;
    try {
      await _emitAcknowledgedCommand(_openCardEvent, <String, Object?>{
        'roomId': roomId,
        'cardId': cardId,
      });
      await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw TimeoutException('Kartu arena tidak merespons. Coba lagi.');
    } finally {
      if (identical(_openCardCompleter, completer)) {
        _openCardCompleter = null;
        _pendingOpenCardId = null;
      }
    }
  }

  @override
  Future<void> submitAnswer({
    required String cardId,
    required int selectedOptionIndex,
  }) async {
    final String roomId = _requireRoomId();
    await _ensureConnected();
    _submittedCardIds.add(cardId);
    try {
      await _emitAcknowledgedCommand(_playCardEvent, <String, Object?>{
        'roomId': roomId,
        'cardId': cardId,
        'selectedOptionIndex': selectedOptionIndex,
      });
    } catch (_) {
      _submittedCardIds.remove(cardId);
      rethrow;
    }
  }

  @override
  Future<void> cancelQueue() async {
    final Completer<BattleSessionSeed>? completer = _sessionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError('Matchmaking dibatalkan.'));
    }
    await _emitCancelQueue();
  }

  @override
  Future<PrivateRoomReservation> createPrivateRoom() async {
    final String? accessToken = _accessToken;
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw StateError('Sesi login sudah berakhir. Silakan masuk ulang.');
    }
    await _ensureConnected();
    final Map<String, dynamic> ack = await _emitAcknowledgedCommand(
      _createPrivateRoomEvent,
      <String, Object?>{},
    );
    final Map<String, dynamic> data = _asMap(ack['data']);
    final String code = (data['code'] as String? ?? '').trim();
    if (code.isEmpty) {
      throw StateError('Gagal membuat room privat. Coba lagi.');
    }
    return PrivateRoomReservation(
      code: code,
      target: _parseTarget(data['target']),
      expiresAt:
          DateTime.tryParse(data['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<void> joinPrivateRoom({required String code}) async {
    final String? accessToken = _accessToken;
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw StateError('Sesi login sudah berakhir. Silakan masuk ulang.');
    }
    await _ensureConnected();
    await _emitAcknowledgedCommand(_joinPrivateRoomEvent, <String, Object?>{
      'code': code.trim().toUpperCase(),
    });
  }

  @override
  Future<void> cancelPrivateRoom({required String code}) async {
    if (_socket == null || !_socket!.connected) {
      return;
    }
    try {
      await _emitAcknowledgedCommand(_cancelPrivateRoomEvent, <String, Object?>{
        'code': code.trim().toUpperCase(),
      });
    } catch (_) {
      // The room expires server-side anyway; cancellation is best-effort.
    }
  }

  @override
  Future<void> surrender() async {
    if (_socket == null || !_socket!.connected || _roomId == null) {
      return;
    }
    final Completer<void> completer = Completer<void>();
    _surrenderCompleter = completer;
    try {
      await _emitAcknowledgedCommand(_surrenderEvent, <String, Object?>{
        'roomId': _roomId,
      });
      await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // The server may still finish the surrender after a transient reconnect.
      // Let the UI leave the arena after the bounded acknowledgement window.
    } finally {
      if (identical(_surrenderCompleter, completer)) {
        _surrenderCompleter = null;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _submittedCardIds.clear();
    if (_openCardCompleter != null && !_openCardCompleter!.isCompleted) {
      _openCardCompleter!.completeError(StateError('Battle ditutup.'));
    }
    if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
      _sessionCompleter!.completeError(StateError('Battle ditutup.'));
    }
    if (_surrenderCompleter != null && !_surrenderCompleter!.isCompleted) {
      _surrenderCompleter!.completeError(StateError('Battle ditutup.'));
    }
    _socket?.dispose();
    _updatesController.close();
  }

  Future<void> _ensureConnected() async {
    if (_socket != null && _socket!.connected) {
      return;
    }
    final Future<void>? connecting = _connectionFuture;
    if (connecting != null) {
      return connecting;
    }
    final Future<void> connection = _connectSocket();
    _connectionFuture = connection;
    try {
      await connection;
    } finally {
      if (identical(_connectionFuture, connection)) {
        _connectionFuture = null;
      }
    }
  }

  Future<void> _connectSocket() async {
    _socket?.dispose();
    final Completer<void> completer = Completer<void>();
    final io.Socket socket = io.io(
      '${AppConfig.gameBaseUrl}/match',
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuth(<String, String>{'token': _accessToken!})
          .build(),
    );

    socket.on(_connectionSuccessEvent, (_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    socket.onConnectError((_) {
      const String message = UserFacingError.offlineMessage;
      if (!completer.isCompleted) {
        completer.completeError(StateError(message));
      }
      _emitError(message);
    });
    socket.onError((dynamic error) {
      if (error != null && UserFacingError.isNetworkFailure(error)) {
        _emitError(UserFacingError.offlineMessage);
        return;
      }
      _emitError(_extractMessage(error) ?? 'Arena online mengalami gangguan.');
    });
    socket.onDisconnect((_) {
      if (_disposed) {
        return;
      }
      _emitError('Koneksi arena terputus.');
      if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
        _sessionCompleter!.completeError(
          StateError('Koneksi terputus sebelum match ditemukan.'),
        );
      }
    });

    socket.on(_queueJoinedEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      _updatesController.add(
        QueueJoinedUpdate(
          position: _asInt(data['position']),
          queueDepth: _asInt(data['queueDepth']),
          matchmakingMode: _parseMatchmakingMode(data['mode']),
          target: _parseTarget(data['target']),
        ),
      );
    });

    socket.on(_queueCancelledEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      _updatesController.add(
        QueueCancelledUpdate(reason: data['reason'] as String? ?? 'cancelled'),
      );
    });

    socket.on(_matchFoundEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      _roomId = data['roomId'] as String?;
      _opponentUserId = data['opponentUserId'] as String?;
      _opponentName = _displayName(
        data['opponentDisplayName'],
        fallbackUserId: _opponentUserId,
      );
      final Map<String, dynamic> loadout = _asMap(data['opponentLoadout']);
      _currentMatchmakingMode = _parseMatchmakingMode(data['mode']);
      _updatesController.add(
        MatchFoundUpdate(
          roomId: _roomId ?? '',
          opponentUserId: _opponentUserId ?? '',
          opponentDisplayName: _opponentName,
          opponentCharacterId: loadout['characterId'] as String?,
          opponentTowerId: loadout['towerId'] as String?,
          matchmakingMode: _currentMatchmakingMode,
          target: _parseTarget(data['target']),
        ),
      );
    });

    socket.on(_privateRoomCreatedEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      _updatesController.add(
        PrivateRoomCreatedUpdate(
          code: data['code'] as String? ?? '',
          target: _parseTarget(data['target']),
          expiresAt:
              DateTime.tryParse(data['expiresAt']?.toString() ?? '') ??
              DateTime.now().add(const Duration(minutes: 15)),
        ),
      );
    });

    socket.on(_privateRoomJoinedEvent, (_) {
      // The follow-up match_found + game_state_update events drive the UI;
      // this acknowledgement only confirms the room consumed its code.
    });

    socket.on(_privateRoomCancelledEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      _updatesController.add(
        PrivateRoomCancelledUpdate(
          code: data['code'] as String? ?? '',
          reason: data['reason'] as String? ?? 'cancelled',
        ),
      );
    });

    socket.on(_gameStateUpdateEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      final Map<String, dynamic> self = _asMap(data['self']);
      final Map<String, dynamic> opponent = _asMap(data['opponent']);
      _roomId = data['roomId'] as String? ?? _roomId;
      _selfUserId = self['userId'] as String? ?? _selfUserId;
      _opponentUserId = opponent['userId'] as String? ?? _opponentUserId;
      _opponentName = _displayName(
        opponent['displayName'],
        fallbackUserId: _opponentUserId,
      );
      final Map<String, dynamic> selfLoadout = _asMap(self['loadout']);
      final Map<String, dynamic> opponentLoadout = _asMap(opponent['loadout']);
      _currentMatchmakingMode = _parseMatchmakingMode(data['mode']);

      final List<BattleQuestion> questions = (_asList(
        self['hand'],
      )).map(_mapQuestion).toList(growable: false);
      final GameStateUpdated update = GameStateUpdated(
        roomId: _roomId ?? '',
        phase: data['phase'] as String? ?? 'active',
        playerHp: _asInt(self['hp']),
        opponentHp: _asInt(opponent['hp']),
        playerPoints: _asInt(self['points']),
        opponentPoints: _asInt(opponent['points']),
        playerComboLevel: _asInt(self['comboLevel']).clamp(1, 3),
        currentRound: _asInt(data['currentRound']).clamp(1, 3),
        roundSecondsRemaining: _asInt(data['roundSecondsRemaining']),
        playerRoundWins: _asInt(data['selfRoundWins']),
        opponentRoundWins: _asInt(data['opponentRoundWins']),
        lastRoundOutcome: _parseRoundOutcome(
          data['lastRoundOutcome'] as String?,
        ),
        availableQuestions: questions,
        answeredQuestionIds: _asStringList(self['answeredCardIds']),
        playerDisplayName: _displayName(
          self['displayName'],
          fallbackUserId: _selfUserId,
        ),
        opponentDisplayName: _opponentName,
        playerCharacterId: selfLoadout['characterId'] as String?,
        playerTowerId: selfLoadout['towerId'] as String?,
        opponentCharacterId: opponentLoadout['characterId'] as String?,
        opponentTowerId: opponentLoadout['towerId'] as String?,
        matchmakingMode: _currentMatchmakingMode,
        target: _parseTarget(data['target']),
        opponentConnected: opponent['connected'] as bool? ?? true,
      );

      if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
        _sessionCompleter!.complete(
          BattleSessionSeed(opponentName: _opponentName, questions: questions),
        );
      }

      _updatesController.add(update);
    });

    socket.on(_openCardAcceptedEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      final String? cardId = data['cardId'] as String?;
      if (_pendingOpenCardId != null &&
          cardId == _pendingOpenCardId &&
          _openCardCompleter != null &&
          !_openCardCompleter!.isCompleted) {
        _openCardCompleter!.complete();
        _openCardCompleter = null;
        _pendingOpenCardId = null;
      }
    });

    socket.on(_cardActionRejectedEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      final String message =
          data['message'] as String? ?? 'Aksi arena ditolak server.';
      if (_openCardCompleter != null && !_openCardCompleter!.isCompleted) {
        _openCardCompleter!.completeError(StateError(message));
        _openCardCompleter = null;
        _pendingOpenCardId = null;
      }
      _emitError(message);
    });

    socket.on(_playCardResultEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      final String cardId = data['cardId'] as String? ?? '';
      final bool submittedBySelf = _submittedCardIds.remove(cardId);
      _updatesController.add(
        CardPlayedUpdate(
          cardId: cardId,
          category: data['category'] as String?,
          correct: data['correct'] as bool? ?? false,
          effect: _parseEffect(data['effect'] as String?),
          effectValue: _asInt(data['effectValue']),
          projectileLevel: _asInt(data['projectileLevel']).clamp(1, 3),
          isSelfAction: data['actorUserId'] == _selfUserId || submittedBySelf,
        ),
      );
    });

    socket.on(_matchResultEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      final String? winnerUserId = data['winnerUserId'] as String?;
      final String? loserUserId = data['loserUserId'] as String?;
      final String reason = data['reason'] as String? ?? 'draw';
      final BattleOutcome outcome = _parseOutcome(
        rawOutcome: data['outcome'] as String?,
        winnerUserId: winnerUserId,
        loserUserId: loserUserId,
      );
      final Map<String, dynamic> finalState = _asMap(data['finalState']);
      final Map<String, dynamic> playerA = _asMap(finalState['playerA']);
      final Map<String, dynamic> playerB = _asMap(finalState['playerB']);
      final Map<String, dynamic> selfResult = playerA['userId'] == _selfUserId
          ? playerA
          : playerB;
      _roomId = null;
      _submittedCardIds.clear();
      if (_surrenderCompleter != null && !_surrenderCompleter!.isCompleted) {
        _surrenderCompleter!.complete();
      }
      _updatesController.add(
        MatchResultUpdate(
          outcome: outcome,
          reason: reason,
          ratingDelta: _asInt(selfResult['pvpRatingDelta']),
          coinsDelta: _asInt(selfResult['coinsDelta']),
          progressionPersisted: data['progressionPersisted'] as bool? ?? false,
          matchmakingMode: _parseMatchmakingMode(data['mode']),
          target: _parseTarget(data['target']),
        ),
      );
    });

    socket.on(_presenceUpdateEvent, (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      final Map<String, dynamic> players = _asMap(data['players']);
      bool opponentConnected = true;
      DateTime? reconnectDeadline;
      for (final MapEntry<String, dynamic> entry in players.entries) {
        if (entry.key == _selfUserId) {
          continue;
        }
        final Map<String, dynamic> presence = _asMap(entry.value);
        opponentConnected = presence['connected'] as bool? ?? opponentConnected;
        reconnectDeadline = DateTime.tryParse(
          presence['reconnectDeadline']?.toString() ?? '',
        );
      }
      _updatesController.add(
        PresenceUpdated(
          opponentConnected: opponentConnected,
          opponentReconnectDeadline: reconnectDeadline,
        ),
      );
    });

    socket.on(_errorEvent, (dynamic payload) {
      final String message =
          _extractMessage(payload) ?? 'Arena online mengalami gangguan.';
      if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
        _sessionCompleter!.completeError(StateError(message));
      }
      if (_openCardCompleter != null && !_openCardCompleter!.isCompleted) {
        _openCardCompleter!.completeError(StateError(message));
        _openCardCompleter = null;
        _pendingOpenCardId = null;
      }
      if (_surrenderCompleter != null && !_surrenderCompleter!.isCompleted) {
        _surrenderCompleter!.completeError(StateError(message));
      }
      _emitError(message);
    });

    _socket = socket;
    socket.connect();
    await completer.future;
  }

  String _requireRoomId() {
    final String? roomId = _roomId;
    if (roomId == null || roomId.isEmpty) {
      throw StateError('Room battle online belum siap.');
    }
    return roomId;
  }

  void _emitError(String message) {
    if (_disposed || _updatesController.isClosed) {
      return;
    }
    _updatesController.add(BattleErrorUpdate(message: message));
  }

  BattleQuestion _mapQuestion(dynamic item) {
    final Map<String, dynamic> data = _asMap(item);
    final QuestionEffect effect =
        _parseEffect(data['effect'] as String?) ?? QuestionEffect.damage;
    return BattleQuestion(
      id: data['id'] as String? ?? '',
      prompt: data['prompt'] as String? ?? '',
      options: _asStringList(data['options']),
      weight: _asInt(data['weight']),
      effect: effect,
      category: data['category'] as String? ?? 'numerik',
      subcategory: data['subcategory'] as String?,
      timeLimitSeconds: _positiveInt(data['timeLimitSeconds'], fallback: 10),
      isExhausted: data['isExhausted'] as bool? ?? false,
    );
  }

  BattleOutcome _parseOutcome({
    required String? rawOutcome,
    required String? winnerUserId,
    required String? loserUserId,
  }) {
    if (winnerUserId != null && winnerUserId == _selfUserId) {
      return BattleOutcome.win;
    }
    if (loserUserId != null && loserUserId == _selfUserId) {
      return BattleOutcome.lose;
    }
    return switch (rawOutcome) {
      'win' => BattleOutcome.win,
      'lose' || 'surrender' => BattleOutcome.lose,
      _ => BattleOutcome.draw,
    };
  }

  BattleOutcome? _parseRoundOutcome(String? outcome) {
    return switch (outcome) {
      'win' => BattleOutcome.win,
      'lose' => BattleOutcome.lose,
      'draw' => BattleOutcome.draw,
      _ => null,
    };
  }

  QuestionEffect? _parseEffect(String? effect) {
    return switch (effect) {
      'damage' => QuestionEffect.damage,
      'heal' => QuestionEffect.heal,
      _ => null,
    };
  }

  String _displayName(dynamic value, {required String? fallbackUserId}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim().split(RegExp(r'\s+')).first;
    }
    return _labelForOpponent(fallbackUserId);
  }

  String _labelForOpponent(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return 'Player Match';
    }
    final String compact = userId.replaceAll('-', '');
    final String suffix = compact.length > 6
        ? compact.substring(compact.length - 6).toUpperCase()
        : compact.toUpperCase();
    return 'Player $suffix';
  }

  String? _extractMessage(dynamic payload) {
    if (payload is Map<Object?, Object?>) {
      final Object? message = payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    if (payload is String && payload.trim().isNotEmpty) {
      return payload;
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map<Object?, Object?>) {
      return payload.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic payload) {
    if (payload is List<dynamic>) {
      return payload;
    }
    return const <dynamic>[];
  }

  List<String> _asStringList(dynamic payload) {
    return _asList(
      payload,
    ).map((dynamic item) => item.toString()).toList(growable: false);
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _positiveInt(dynamic value, {required int fallback}) {
    final int parsed = _asInt(value);
    return parsed > 0 ? parsed : fallback;
  }

  OnlineMatchmakingMode _parseMatchmakingMode(dynamic value) {
    return switch (value?.toString().toLowerCase()) {
      'ranked' => OnlineMatchmakingMode.ranked,
      'bot' => OnlineMatchmakingMode.bot,
      'private' || 'privateroom' => OnlineMatchmakingMode.privateRoom,
      _ => OnlineMatchmakingMode.casual,
    };
  }

  BattleTarget _parseTarget(dynamic value) {
    return value == 'bumn' ? BattleTarget.bumn : BattleTarget.cpns;
  }

  Future<void> _emitCancelQueue() async {
    if (_socket == null || !_socket!.connected) {
      return;
    }
    await _emitAcknowledgedCommand(_cancelQueueEvent, <String, Object?>{});
  }

  Future<Map<String, dynamic>> _emitAcknowledgedCommand(
    String event,
    Map<String, Object?> payload,
  ) {
    return _commandAcknowledger.send(
      event: event,
      payload: payload,
      emit:
          (
            String name,
            Map<String, Object?> command,
            void Function(dynamic) ack,
          ) {
            _socket!.emitWithAck(name, command, ack: ack);
          },
      reconnect: _ensureConnected,
    );
  }
}
