import 'dart:js_interop';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web/web.dart' as web;
import 'package:yudha_mobile/features/interview/presentation/audio/interview_audio_capture.dart';

InterviewAudioCapture createInterviewAudioCapture() =>
    _WebInterviewAudioCapture();

class _WebInterviewAudioCapture implements InterviewAudioCapture {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() {
    return _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: '',
    );
  }

  @override
  Future<CapturedInterviewAudio?> stop({bool cancel = false}) async {
    if (cancel) {
      await _recorder.cancel();
      return null;
    }

    final String? objectUrl = await _recorder.stop();
    if (objectUrl == null || objectUrl.isEmpty) {
      return null;
    }

    try {
      final web.Response response = await web.window
          .fetch(objectUrl.toJS)
          .toDart;
      if (!response.ok) {
        throw StateError('Browser could not read the recorded audio.');
      }
      final ByteBuffer buffer = (await response.arrayBuffer().toDart).toDart;
      return CapturedInterviewAudio(
        bytes: buffer.asUint8List(),
        filename: 'recording.wav',
      );
    } finally {
      web.URL.revokeObjectURL(objectUrl);
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
