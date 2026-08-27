import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_capture.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_player.dart';
import 'package:yudha_mobile/features/interview/data/repositories/live_interview_speech_client.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';

class LiveInterviewCoordinator {
  LiveInterviewCoordinator({
    required LiveInterviewSpeechClient client,
    required LiveInterviewAudioCapture capture,
    required LiveInterviewAudioPlayer player,
    required String? accessToken,
    required String Function(String turnId) questionAudioUrl,
    required void Function(
      LiveInterviewPhase phase, {
      String? errorMessage,
      bool clearError,
    })
    onPhase,
    required void Function(Duration duration) onRecordingDuration,
    required void Function(String answerId, String text) onTranscript,
    required void Function(String answerId, InterviewEvaluation evaluation)
    onEvaluation,
    required void Function(String turnId, String text) onQuestion,
    required void Function(InterviewFinalSummary summary) onCompleted,
    required void Function() onTextFallback,
    this.minimumRecordingDuration = const Duration(milliseconds: 500),
    this.maximumRecordingDuration = const Duration(seconds: 90),
    DateTime Function()? now,
  }) : _client = client,
       _capture = capture,
       _player = player,
       _accessToken = accessToken,
       _questionAudioUrl = questionAudioUrl,
       _onPhase = onPhase,
       _onRecordingDuration = onRecordingDuration,
       _onTranscript = onTranscript,
       _onEvaluation = onEvaluation,
       _onQuestion = onQuestion,
       _onCompleted = onCompleted,
       _onTextFallback = onTextFallback,
       _now = now ?? DateTime.now;

  final LiveInterviewSpeechClient _client;
  final LiveInterviewAudioCapture _capture;
  final LiveInterviewAudioPlayer _player;
  final String? _accessToken;
  final String Function(String turnId) _questionAudioUrl;
  final void Function(
    LiveInterviewPhase phase, {
    String? errorMessage,
    bool clearError,
  })
  _onPhase;
  final void Function(Duration duration) _onRecordingDuration;
  final void Function(String answerId, String text) _onTranscript;
  final void Function(String answerId, InterviewEvaluation evaluation)
  _onEvaluation;
  final void Function(String turnId, String text) _onQuestion;
  final void Function(InterviewFinalSummary summary) _onCompleted;
  final void Function() _onTextFallback;
  final DateTime Function() _now;
  final Duration minimumRecordingDuration;
  final Duration maximumRecordingDuration;

  StreamSubscription<LiveSpeechEvent>? _eventSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  String? _sessionId;
  String? _answerId;
  int _nextSequence = 0;
  bool _readyToAnswer = false;
  bool _pushHeld = false;
  bool _capturing = false;
  bool _finishing = false;
  bool _stopping = false;
  bool _disposed = false;
  bool _reconnecting = false;
  Future<void>? _captureStartOperation;
  DateTime? _recordingStartedAt;
  Timer? _durationTimer;
  Timer? _maximumTimer;
  final List<Uint8List> _answerChunks = <Uint8List>[];
  Future<void> _sendChain = Future<void>.value();
  Object? _sendFailure;
  final List<Uint8List> _questionAudioChunks = <Uint8List>[];
  String _questionAudioExtension = 'mp3';
  int _nextQuestionAudioSequence = 0;
  Future<void>? _questionPlayback;

  Future<void> start({
    required String sessionId,
    required String currentQuestionId,
  }) async {
    if (_disposed) {
      return;
    }
    _sessionId = sessionId;
    _eventSubscription ??= _client.events.listen(_handleEvent);
    _onPhase(LiveInterviewPhase.connecting, clearError: true);
    try {
      if (!await _capture.hasPermission()) {
        _onPhase(
          LiveInterviewPhase.degraded,
          errorMessage:
              'Izin mikrofon diperlukan. Aktifkan izin atau beralih ke jawaban teks.',
        );
        return;
      }
      await _client.connect(sessionId);
      _onPhase(LiveInterviewPhase.interviewerSpeaking, clearError: true);
      try {
        await _player.playUrl(
          _questionAudioUrl(currentQuestionId),
          accessToken: _accessToken,
        );
      } catch (_) {
        _onPhase(
          LiveInterviewPhase.interviewerSpeaking,
          errorMessage:
              'Audio pertanyaan belum dapat diputar. Pertanyaannya tetap tersedia sebagai teks.',
        );
      }
      _markReadyToAnswer();
    } catch (error) {
      _onPhase(
        LiveInterviewPhase.degraded,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<void> beginPushToTalk() async {
    if (_disposed ||
        !_readyToAnswer ||
        _pushHeld ||
        _finishing ||
        _reconnecting ||
        !_client.isConnected) {
      return;
    }
    _readyToAnswer = false;
    _pushHeld = true;
    _resetAnswer();
    _answerId = _newAnswerId();
    _recordingStartedAt = _now();
    if (!_disposed) {
      _onRecordingDuration(Duration.zero);
    }
    _onPhase(LiveInterviewPhase.candidateSpeaking, clearError: true);

    final Future<void> operation = _startPushCapture();
    _captureStartOperation = operation;
    await operation;
  }

  Future<void> endPushToTalk() async {
    if (!_pushHeld && !_capturing) {
      return;
    }
    _pushHeld = false;
    await _captureStartOperation;
    if (!_capturing || _answerId == null) {
      return;
    }
    await _finishCapture();
  }

  Future<void> cancelPushToTalk() async {
    if (!_pushHeld && !_capturing && _answerId == null) {
      return;
    }
    _pushHeld = false;
    await _captureStartOperation;
    await _stopRecorder();
    await _sendChain;
    _client.cancel(answerId: _answerId);
    _resetAnswer();
    if (_client.isConnected && !_disposed && !_stopping) {
      _markReadyToAnswer();
    }
  }

  Future<void> reconnect() async {
    if (_disposed || _sessionId == null || _reconnecting) {
      return;
    }
    await _recoverConnection(replayAnswer: _answerChunks.isNotEmpty);
  }

  Future<void> switchToText() async {
    _onTextFallback();
    await stop();
  }

  Future<void> stop() async {
    if (_stopping) {
      return;
    }
    _stopping = true;
    _readyToAnswer = false;
    _pushHeld = false;
    try {
      _client.cancel(answerId: _answerId);
      await _stopRecorder();
      await _player.stop();
      await _client.disconnect();
      _resetAnswer();
    } finally {
      _stopping = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await stop();
    await _eventSubscription?.cancel();
    await _capture.dispose();
    await _player.dispose();
    await _client.dispose();
  }

  Future<void> _startPushCapture() async {
    try {
      final Stream<Uint8List> stream = await _capture.start();
      if (!_pushHeld || _disposed || _stopping) {
        await _capture.stop();
        _client.cancel(answerId: _answerId);
        _resetAnswer();
        if (_client.isConnected && !_disposed && !_stopping) {
          _markReadyToAnswer();
        }
        return;
      }
      _capturing = true;
      _audioSubscription = stream.listen(
        _handleAudio,
        onError: (Object error) {
          unawaited(cancelPushToTalk());
          _onPhase(
            LiveInterviewPhase.degraded,
            errorMessage: 'Mikrofon terputus. Coba sambungkan lagi.',
          );
        },
      );
      _startRecordingTimers();
    } catch (error) {
      _pushHeld = false;
      _resetAnswer();
      _onPhase(
        LiveInterviewPhase.degraded,
        errorMessage: _friendlyError(error),
      );
    }
  }

  void _handleAudio(Uint8List chunk) {
    if (_disposed || !_capturing || _finishing || chunk.isEmpty) {
      return;
    }
    _queueChunk(chunk);
  }

  void _queueChunk(Uint8List audio) {
    final String? answerId = _answerId;
    if (answerId == null) {
      return;
    }
    final Uint8List retained = Uint8List.fromList(audio);
    final int sequence = _nextSequence++;
    _answerChunks.add(retained);
    _sendChain = _sendChain.then((_) async {
      if (_sendFailure != null) {
        return;
      }
      try {
        await _client.sendChunk(
          answerId: answerId,
          sequence: sequence,
          audio: retained,
        );
      } catch (error) {
        _sendFailure = error;
      }
    });
  }

  Future<void> _finishCapture() async {
    if (_finishing || _answerId == null) {
      return;
    }
    _finishing = true;
    await _stopRecorder();

    final Duration elapsed = _recordingStartedAt == null
        ? Duration.zero
        : _now().difference(_recordingStartedAt!);
    if (elapsed < minimumRecordingDuration || _answerChunks.isEmpty) {
      await _sendChain;
      _client.cancel(answerId: _answerId);
      _resetAnswer();
      _markReadyToAnswer(
        errorMessage: 'Tahan tombol sedikit lebih lama sebelum berbicara.',
      );
      return;
    }

    _onPhase(LiveInterviewPhase.transcribing, clearError: true);
    await _sendChain;
    if (_sendFailure != null || !_client.isConnected) {
      _finishing = false;
      await _recoverConnection(replayAnswer: true);
      return;
    }

    _client.finishAnswer(
      answerId: _answerId!,
      finalSequence: _answerChunks.length - 1,
    );
    _finishing = false;
  }

  void _startRecordingTimers() {
    _durationTimer?.cancel();
    _maximumTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final DateTime? startedAt = _recordingStartedAt;
      if (startedAt != null && _capturing) {
        _onRecordingDuration(_now().difference(startedAt));
      }
    });
    final DateTime? startedAt = _recordingStartedAt;
    final Duration elapsed = startedAt == null
        ? Duration.zero
        : _now().difference(startedAt);
    final Duration remaining = maximumRecordingDuration - elapsed;
    _maximumTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_capturing && !_finishing) {
        _pushHeld = false;
        unawaited(_finishCapture());
      }
    });
  }

  void _handleEvent(LiveSpeechEvent event) {
    switch (event.type) {
      case LiveSpeechEventType.transcriptFinal:
        final String answerId = event.data['answerId']?.toString() ?? '';
        final String text = event.data['text']?.toString().trim() ?? '';
        if (answerId.isNotEmpty && text.isNotEmpty) {
          _onTranscript(answerId, text);
        }
        _onPhase(LiveInterviewPhase.evaluating, clearError: true);
        break;
      case LiveSpeechEventType.evaluation:
        final Object? evaluation = event.data['evaluation'];
        if (evaluation is Map) {
          _onEvaluation(
            event.data['answerId']?.toString() ?? '',
            InterviewEvaluation.fromJson(_stringMap(evaluation)),
          );
        }
        break;
      case LiveSpeechEventType.questionText:
        _questionAudioChunks.clear();
        _nextQuestionAudioSequence = 0;
        _questionPlayback = null;
        _onQuestion(
          event.data['turnId']?.toString() ?? '',
          event.data['text']?.toString() ?? '',
        );
        break;
      case LiveSpeechEventType.questionAudioStart:
        _questionAudioChunks.clear();
        _nextQuestionAudioSequence = 0;
        _questionAudioExtension =
            event.data['fileExtension']?.toString() ?? 'mp3';
        break;
      case LiveSpeechEventType.questionAudioChunk:
        _acceptQuestionAudioChunk(event.data);
        break;
      case LiveSpeechEventType.questionAudioEnd:
        _questionPlayback = _playQuestionAudio();
        break;
      case LiveSpeechEventType.turnCompleted:
        unawaited(_finishTurn());
        break;
      case LiveSpeechEventType.sessionCompleted:
        final Object? summary = event.data['finalSummary'];
        if (summary is Map) {
          _onCompleted(InterviewFinalSummary.fromJson(_stringMap(summary)));
        }
        _onPhase(LiveInterviewPhase.completed, clearError: true);
        unawaited(stop());
        break;
      case LiveSpeechEventType.error:
        _handleServerError(event.data);
        break;
      case LiveSpeechEventType.disconnected:
        if (!_stopping && !_disposed) {
          unawaited(_handleUnexpectedDisconnect());
        }
        break;
      case LiveSpeechEventType.sessionReady:
      case LiveSpeechEventType.audioChunkAck:
        break;
    }
  }

  void _acceptQuestionAudioChunk(Map<String, dynamic> data) {
    final int? sequence = int.tryParse(data['sequence']?.toString() ?? '');
    final String encoded = data['audio']?.toString() ?? '';
    if (sequence != _nextQuestionAudioSequence || encoded.isEmpty) {
      return;
    }
    try {
      _questionAudioChunks.add(base64Decode(encoded));
      _nextQuestionAudioSequence += 1;
    } on FormatException {
      _onPhase(
        LiveInterviewPhase.interviewerSpeaking,
        errorMessage:
            'Audio pertanyaan tidak lengkap; gunakan teks yang tampil.',
      );
    }
  }

  Future<void> _playQuestionAudio() async {
    if (_questionAudioChunks.isEmpty) {
      return;
    }
    _onPhase(LiveInterviewPhase.interviewerSpeaking, clearError: true);
    final BytesBuilder builder = BytesBuilder(copy: false);
    for (final Uint8List chunk in _questionAudioChunks) {
      builder.add(chunk);
    }
    try {
      await _player.playBytes(
        builder.takeBytes(),
        fileExtension: _questionAudioExtension,
      );
    } catch (_) {
      _onPhase(
        LiveInterviewPhase.interviewerSpeaking,
        errorMessage:
            'Audio pertanyaan belum dapat diputar. Lanjutkan dari teks yang tampil.',
      );
    }
  }

  Future<void> _finishTurn() async {
    await _questionPlayback;
    _resetAnswer();
    _markReadyToAnswer();
  }

  void _handleServerError(Map<String, dynamic> data) {
    final Map<String, dynamic> error = _stringMap(data['error']);
    final String code = error['code']?.toString() ?? 'UNKNOWN';
    final String message =
        error['message']?.toString() ?? 'Live interview mengalami gangguan.';
    if (code == 'TTS_UNAVAILABLE') {
      _onPhase(LiveInterviewPhase.interviewerSpeaking, errorMessage: message);
      return;
    }
    const Set<String> nonReplayableErrors = <String>{
      'GUARDRAIL_VIOLATION',
      'INVALID_AUDIO_FORMAT',
      'INVALID_SEQUENCE',
      'CHUNK_TOO_LARGE',
      'ANSWER_TOO_LARGE',
      'ANSWER_TOO_LONG',
      'NO_AUDIO',
      'BAD_REQUEST',
      'CONFLICT',
    };
    _onPhase(LiveInterviewPhase.degraded, errorMessage: message);
    unawaited(_stopCapture(cancelAnswer: nonReplayableErrors.contains(code)));
  }

  Future<void> _handleUnexpectedDisconnect() async {
    if (_reconnecting) {
      return;
    }
    _pushHeld = false;
    final bool replay = _answerChunks.isNotEmpty;
    await _stopCapture(cancelAnswer: !replay);
    await _recoverConnection(replayAnswer: replay);
  }

  Future<void> _recoverConnection({required bool replayAnswer}) async {
    final String? sessionId = _sessionId;
    if (_disposed || sessionId == null || _reconnecting) {
      return;
    }
    _readyToAnswer = false;
    _reconnecting = true;
    _onPhase(LiveInterviewPhase.reconnecting);
    Object? lastError;
    for (int attempt = 0; attempt < 3 && !_disposed; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
      try {
        await _client.connect(sessionId);
        if (replayAnswer && _answerId != null && _answerChunks.isNotEmpty) {
          _sendFailure = null;
          for (int index = 0; index < _answerChunks.length; index += 1) {
            await _client.sendChunk(
              answerId: _answerId!,
              sequence: index,
              audio: _answerChunks[index],
            );
          }
          _client.finishAnswer(
            answerId: _answerId!,
            finalSequence: _answerChunks.length - 1,
          );
          _onPhase(LiveInterviewPhase.transcribing, clearError: true);
        } else {
          _resetAnswer();
        }
        _reconnecting = false;
        if (!replayAnswer) {
          _markReadyToAnswer();
        }
        return;
      } catch (error) {
        lastError = error;
      }
    }
    _reconnecting = false;
    _onPhase(
      LiveInterviewPhase.degraded,
      errorMessage: _friendlyError(lastError),
    );
  }

  Future<void> _stopCapture({required bool cancelAnswer}) async {
    _pushHeld = false;
    await _stopRecorder();
    if (cancelAnswer) {
      _resetAnswer();
    }
  }

  Future<void> _stopRecorder() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _maximumTimer?.cancel();
    _maximumTimer = null;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _capture.stop();
    _capturing = false;
  }

  void _markReadyToAnswer({String? errorMessage}) {
    if (_disposed || _stopping || _reconnecting) {
      return;
    }
    _readyToAnswer = true;
    _onRecordingDuration(Duration.zero);
    _onPhase(
      LiveInterviewPhase.readyToAnswer,
      errorMessage: errorMessage,
      clearError: errorMessage == null,
    );
  }

  void _resetAnswer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _maximumTimer?.cancel();
    _maximumTimer = null;
    _captureStartOperation = null;
    _recordingStartedAt = null;
    _answerId = null;
    _answerChunks.clear();
    _nextSequence = 0;
    _sendFailure = null;
    _sendChain = Future<void>.value();
    _capturing = false;
    _finishing = false;
    if (!_disposed) {
      _onRecordingDuration(Duration.zero);
    }
  }

  String _newAnswerId() =>
      'voice-answer-${DateTime.now().microsecondsSinceEpoch}';

  String _friendlyError(Object? error) {
    final String value = error?.toString() ?? '';
    if (value.contains('login')) {
      return 'Sesi login sudah berakhir. Silakan masuk ulang.';
    }
    return 'Live interview terputus. Coba sambungkan lagi atau beralih ke teks.';
  }

  Map<String, dynamic> _stringMap(Object? value) {
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
}
