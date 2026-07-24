import 'dart:typed_data';

import 'interview_audio_capture_io.dart'
    if (dart.library.js_interop) 'interview_audio_capture_web.dart'
    as platform;

class CapturedInterviewAudio {
  const CapturedInterviewAudio({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

abstract interface class InterviewAudioCapture {
  Future<bool> hasPermission();

  Future<void> start();

  Future<CapturedInterviewAudio?> stop({bool cancel = false});

  Future<void> dispose();
}

InterviewAudioCapture createInterviewAudioCapture() =>
    platform.createInterviewAudioCapture();
