import 'dart:typed_data';

import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_capture.dart';

LiveInterviewAudioCapture createLiveInterviewAudioCapture() =>
    _UnsupportedLiveInterviewAudioCapture();

class _UnsupportedLiveInterviewAudioCapture
    implements LiveInterviewAudioCapture {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<Stream<Uint8List>> start() {
    throw UnsupportedError('Live interview audio is Android-only.');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
