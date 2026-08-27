import 'dart:typed_data';

import 'live_interview_audio_capture_io.dart'
    if (dart.library.js_interop) 'live_interview_audio_capture_unsupported.dart'
    as platform;

abstract interface class LiveInterviewAudioCapture {
  Future<bool> hasPermission();

  Future<Stream<Uint8List>> start();

  Future<void> stop();

  Future<void> dispose();
}

LiveInterviewAudioCapture createLiveInterviewAudioCapture() =>
    platform.createLiveInterviewAudioCapture();
