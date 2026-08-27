import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:socket_io_client/socket_io_client.dart' as io;

enum LiveSpeechEventType {
  disconnected,
  sessionReady,
  audioChunkAck,
  transcriptFinal,
  evaluation,
  questionText,
  questionAudioStart,
  questionAudioChunk,
  questionAudioEnd,
  turnCompleted,
  sessionCompleted,
  error,
}

class LiveSpeechEvent {
  const LiveSpeechEvent(this.type, this.data);

  final LiveSpeechEventType type;
  final Map<String, dynamic> data;
}

class LiveInterviewSpeechClient {
  LiveInterviewSpeechClient({
    required this.baseUrl,
    required this.accessToken,
    this.connectionTimeout = const Duration(seconds: 12),
  });

  final String baseUrl;
  final String? accessToken;
  final Duration connectionTimeout;
  final StreamController<LiveSpeechEvent> _events =
      StreamController<LiveSpeechEvent>.broadcast();
  final Map<int, Completer<void>> _chunkAcknowledgements =
      <int, Completer<void>>{};

  io.Socket? _socket;
  String? _sessionId;
  bool _disposed = false;
  bool _suppressDisconnectEvent = false;
  int _commandCounter = 0;

  Stream<LiveSpeechEvent> get events => _events.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String sessionId) async {
    if (_disposed) {
      throw StateError('Live speech client is disposed.');
    }
    final String token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Sesi login sudah berakhir. Silakan masuk ulang.');
    }

    await disconnect();
    _sessionId = sessionId;
    final Completer<void> ready = Completer<void>();
    final io.Socket socket = io.io(
      '${_normalizeBaseUrl(baseUrl)}/interview-speech',
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          .disableReconnection()
          .setAuth(<String, String>{'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      socket.emit('start_session', <String, dynamic>{
        'commandId': _newCommandId('start'),
        'sessionId': sessionId,
      });
    });
    socket.on('session_ready', (dynamic payload) {
      _emit(LiveSpeechEventType.sessionReady, payload);
      if (!ready.isCompleted) {
        ready.complete();
      }
    });
    socket.on('audio_chunk_ack', (dynamic payload) {
      final Map<String, dynamic> data = _asMap(payload);
      final int? sequence = _asInt(data['sequence']);
      if (sequence != null) {
        _chunkAcknowledgements.remove(sequence)?.complete();
      }
      _events.add(LiveSpeechEvent(LiveSpeechEventType.audioChunkAck, data));
    });
    _listen(socket, 'transcript_final', LiveSpeechEventType.transcriptFinal);
    _listen(socket, 'evaluation', LiveSpeechEventType.evaluation);
    _listen(socket, 'question_text', LiveSpeechEventType.questionText);
    _listen(
      socket,
      'question_audio_start',
      LiveSpeechEventType.questionAudioStart,
    );
    _listen(
      socket,
      'question_audio_chunk',
      LiveSpeechEventType.questionAudioChunk,
    );
    _listen(socket, 'question_audio_end', LiveSpeechEventType.questionAudioEnd);
    _listen(socket, 'turn_completed', LiveSpeechEventType.turnCompleted);
    _listen(socket, 'session_completed', LiveSpeechEventType.sessionCompleted);
    _listen(socket, 'error', LiveSpeechEventType.error);
    socket.onConnectError((dynamic error) {
      if (!ready.isCompleted) {
        ready.completeError(
          StateError('Koneksi live interview belum dapat dibuka.'),
        );
      }
      _events.add(
        LiveSpeechEvent(LiveSpeechEventType.error, <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'CONNECTION_FAILED',
            'message': error?.toString() ?? 'Connection failed',
            'details': <String, dynamic>{'recoverable': true},
          },
        }),
      );
    });
    socket.onDisconnect((dynamic reason) {
      _failPendingAcks('Koneksi terputus sebelum audio diterima.');
      if (!_disposed &&
          !_suppressDisconnectEvent &&
          identical(_socket, socket)) {
        _events.add(
          LiveSpeechEvent(LiveSpeechEventType.disconnected, <String, dynamic>{
            'reason': reason?.toString(),
          }),
        );
      }
    });

    socket.connect();
    await ready.future.timeout(
      connectionTimeout,
      onTimeout: () => throw StateError(
        'Koneksi live interview membutuhkan waktu terlalu lama.',
      ),
    );
  }

  Future<void> sendChunk({
    required String answerId,
    required int sequence,
    required Uint8List audio,
  }) async {
    final io.Socket socket = _requireConnectedSocket();
    final String sessionId = _requireSessionId();
    final Completer<void> acknowledged = Completer<void>();
    _chunkAcknowledgements[sequence] = acknowledged;
    socket.emit('audio_chunk', <String, dynamic>{
      'commandId': _newCommandId('chunk'),
      'sessionId': sessionId,
      'answerId': answerId,
      'sequence': sequence,
      'audio': base64Encode(audio),
      'encoding': 'pcm_s16le',
      'sampleRateHz': 16000,
      'channels': 1,
    });
    await acknowledged.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _chunkAcknowledgements.remove(sequence);
        throw StateError('Server belum mengakui potongan audio.');
      },
    );
  }

  void finishAnswer({required String answerId, required int finalSequence}) {
    _requireConnectedSocket().emit('finish_answer', <String, dynamic>{
      'commandId': _newCommandId('finish'),
      'sessionId': _requireSessionId(),
      'answerId': answerId,
      'finalSequence': finalSequence,
    });
  }

  void cancel({String? answerId}) {
    final io.Socket? socket = _socket;
    final String? sessionId = _sessionId;
    if (socket == null || !socket.connected || sessionId == null) {
      return;
    }
    socket.emit('cancel', <String, dynamic>{
      'commandId': _newCommandId('cancel'),
      'sessionId': sessionId,
      'answerId': ?answerId,
    });
  }

  Future<void> disconnect() async {
    _failPendingAcks('Live interview disconnected.');
    final io.Socket? socket = _socket;
    _socket = null;
    _sessionId = null;
    if (socket != null) {
      _suppressDisconnectEvent = true;
      socket.dispose();
      _suppressDisconnectEvent = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await disconnect();
    await _events.close();
  }

  void _listen(io.Socket socket, String event, LiveSpeechEventType type) {
    socket.on(event, (dynamic payload) => _emit(type, payload));
  }

  void _emit(LiveSpeechEventType type, dynamic payload) {
    if (!_events.isClosed) {
      _events.add(LiveSpeechEvent(type, _asMap(payload)));
    }
  }

  io.Socket _requireConnectedSocket() {
    final io.Socket? socket = _socket;
    if (socket == null || !socket.connected) {
      throw StateError('Koneksi live interview terputus.');
    }
    return socket;
  }

  String _requireSessionId() {
    final String? sessionId = _sessionId;
    if (sessionId == null) {
      throw StateError('Live interview session is not ready.');
    }
    return sessionId;
  }

  void _failPendingAcks(String message) {
    for (final Completer<void> completer in _chunkAcknowledgements.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(message));
      }
    }
    _chunkAcknowledgements.clear();
  }

  String _newCommandId(String prefix) {
    _commandCounter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_commandCounter';
  }

  String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
    }
    return const <String, dynamic>{};
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
