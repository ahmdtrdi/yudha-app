import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/interview/application/interview_state.dart';
import 'package:yudha_mobile/features/interview/application/live_interview_coordinator.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_capture.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_player.dart';
import 'package:yudha_mobile/features/interview/data/repositories/live_interview_speech_client.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_message.dart';

void main() {
  test('keeps the microphone off until push and finishes on release', () async {
    final _Harness harness = _Harness();
    await harness.start();

    expect(harness.capture.startCount, 0);
    expect(harness.phases.last, LiveInterviewPhase.readyToAnswer);

    await harness.coordinator.beginPushToTalk();
    await harness.coordinator.beginPushToTalk();
    harness.capture.add(<int>[1, 0, 2, 0]);
    harness.capture.add(<int>[3, 0, 4, 0]);
    harness.clock = harness.clock.add(const Duration(milliseconds: 600));
    await harness.coordinator.endPushToTalk();

    expect(harness.capture.startCount, 1);
    expect(harness.client.sentChunks.map((e) => e.sequence), <int>[0, 1]);
    expect(harness.client.finished, hasLength(1));
    expect(harness.client.finished.single.finalSequence, 1);
    expect(harness.phases.last, LiveInterviewPhase.transcribing);
    await harness.dispose();
  });

  test(
    'permission denial degrades without opening capture or socket',
    () async {
      final _Harness harness = _Harness(hasPermission: false);

      await harness.start();

      expect(harness.capture.startCount, 0);
      expect(harness.client.connectCount, 0);
      expect(harness.phases.last, LiveInterviewPhase.degraded);
      expect(harness.errors.last, contains('Izin mikrofon'));
      await harness.dispose();
    },
  );

  test('discards a short press and returns to ready state', () async {
    final _Harness harness = _Harness();
    await harness.start();

    await harness.coordinator.beginPushToTalk();
    harness.capture.add(<int>[1, 0]);
    harness.clock = harness.clock.add(const Duration(milliseconds: 100));
    await harness.coordinator.endPushToTalk();

    expect(harness.client.finished, isEmpty);
    expect(harness.client.cancelledAnswerIds, hasLength(1));
    expect(harness.phases.last, LiveInterviewPhase.readyToAnswer);
    expect(harness.errors.last, contains('sedikit lebih lama'));
    await harness.dispose();
  });

  test('automatically submits at the configured recording maximum', () async {
    final _Harness harness = _Harness(
      minimumRecordingDuration: Duration.zero,
      maximumRecordingDuration: const Duration(milliseconds: 25),
      useRealClock: true,
    );
    await harness.start();

    await harness.coordinator.beginPushToTalk();
    harness.capture.add(<int>[1, 0, 2, 0]);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(harness.client.finished, hasLength(1));
    expect(harness.phases.last, LiveInterviewPhase.transcribing);
    await harness.dispose();
  });

  test(
    'cancels capture without submitting when interaction is interrupted',
    () async {
      final _Harness harness = _Harness();
      await harness.start();

      await harness.coordinator.beginPushToTalk();
      harness.capture.add(<int>[1, 0, 2, 0]);
      await harness.coordinator.cancelPushToTalk();

      expect(harness.client.finished, isEmpty);
      expect(harness.client.cancelledAnswerIds, hasLength(1));
      expect(harness.capture.isRecording, isFalse);
      expect(harness.phases.last, LiveInterviewPhase.readyToAnswer);
      await harness.dispose();
    },
  );

  test(
    'replays buffered audio with the same answer id after disconnect',
    () async {
      final _Harness harness = _Harness();
      await harness.start();

      await harness.coordinator.beginPushToTalk();
      harness.capture.add(<int>[1, 0, 2, 0]);
      await Future<void>.delayed(Duration.zero);
      final String firstAnswerId = harness.client.sentChunks.single.answerId;

      harness.client.emit(
        const LiveSpeechEvent(
          LiveSpeechEventType.disconnected,
          <String, dynamic>{'reason': 'network'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(harness.client.connectCount, 2);
      expect(harness.client.sentChunks, hasLength(2));
      expect(harness.client.sentChunks.last.answerId, firstAnswerId);
      expect(harness.client.finished.single.answerId, firstAnswerId);
      await harness.dispose();
    },
  );
}

class _Harness {
  _Harness({
    this.minimumRecordingDuration = const Duration(milliseconds: 500),
    this.maximumRecordingDuration = const Duration(seconds: 90),
    this.useRealClock = false,
    this.hasPermission = true,
  }) {
    capture.permissionGranted = hasPermission;
    coordinator = LiveInterviewCoordinator(
      client: client,
      capture: capture,
      player: player,
      accessToken: 'token',
      questionAudioUrl: (_) => 'https://example.invalid/question.mp3',
      onPhase:
          (
            LiveInterviewPhase phase, {
            String? errorMessage,
            bool clearError = false,
          }) {
            phases.add(phase);
            if (errorMessage != null) {
              errors.add(errorMessage);
            }
          },
      onRecordingDuration: durations.add,
      onTranscript: (_, _) {},
      onEvaluation: (_, InterviewEvaluation _) {},
      onQuestion: (_, _) {},
      onCompleted: (_) {},
      onTextFallback: () {},
      minimumRecordingDuration: minimumRecordingDuration,
      maximumRecordingDuration: maximumRecordingDuration,
      now: useRealClock ? DateTime.now : () => clock,
    );
  }

  final Duration minimumRecordingDuration;
  final Duration maximumRecordingDuration;
  final bool useRealClock;
  final bool hasPermission;
  final _FakeSpeechClient client = _FakeSpeechClient();
  final _FakeCapture capture = _FakeCapture();
  final _FakePlayer player = _FakePlayer();
  final List<LiveInterviewPhase> phases = <LiveInterviewPhase>[];
  final List<String> errors = <String>[];
  final List<Duration> durations = <Duration>[];
  DateTime clock = DateTime(2026, 8, 27, 12);
  late final LiveInterviewCoordinator coordinator;

  Future<void> start() => coordinator.start(
    sessionId: 'session-1',
    currentQuestionId: 'question-1',
  );

  Future<void> dispose() => coordinator.dispose();
}

class _SentChunk {
  const _SentChunk(this.answerId, this.sequence, this.audio);

  final String answerId;
  final int sequence;
  final Uint8List audio;
}

class _FinishedAnswer {
  const _FinishedAnswer(this.answerId, this.finalSequence);

  final String answerId;
  final int finalSequence;
}

class _FakeSpeechClient extends LiveInterviewSpeechClient {
  _FakeSpeechClient() : super(baseUrl: 'http://test', accessToken: 'token');

  final StreamController<LiveSpeechEvent> controller =
      StreamController<LiveSpeechEvent>.broadcast(sync: true);
  final List<_SentChunk> sentChunks = <_SentChunk>[];
  final List<_FinishedAnswer> finished = <_FinishedAnswer>[];
  final List<String?> cancelledAnswerIds = <String?>[];
  bool connected = false;
  int connectCount = 0;

  @override
  Stream<LiveSpeechEvent> get events => controller.stream;

  @override
  bool get isConnected => connected;

  @override
  Future<void> connect(String sessionId) async {
    connectCount += 1;
    connected = true;
  }

  @override
  Future<void> sendChunk({
    required String answerId,
    required int sequence,
    required Uint8List audio,
  }) async {
    sentChunks.add(_SentChunk(answerId, sequence, audio));
  }

  @override
  void finishAnswer({required String answerId, required int finalSequence}) {
    finished.add(_FinishedAnswer(answerId, finalSequence));
  }

  @override
  void cancel({String? answerId}) {
    cancelledAnswerIds.add(answerId);
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<void> dispose() async {
    connected = false;
    await controller.close();
  }

  void emit(LiveSpeechEvent event) => controller.add(event);
}

class _FakeCapture implements LiveInterviewAudioCapture {
  StreamController<Uint8List>? _controller;
  int startCount = 0;
  bool isRecording = false;
  bool permissionGranted = true;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<Stream<Uint8List>> start() async {
    startCount += 1;
    isRecording = true;
    _controller = StreamController<Uint8List>.broadcast(sync: true);
    return _controller!.stream;
  }

  void add(List<int> bytes) => _controller?.add(Uint8List.fromList(bytes));

  @override
  Future<void> stop() async {
    isRecording = false;
  }

  @override
  Future<void> dispose() async {
    await _controller?.close();
  }
}

class _FakePlayer implements LiveInterviewAudioPlayer {
  @override
  Future<void> playUrl(String url, {String? accessToken}) async {}

  @override
  Future<void> playBytes(
    Uint8List bytes, {
    required String fileExtension,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
