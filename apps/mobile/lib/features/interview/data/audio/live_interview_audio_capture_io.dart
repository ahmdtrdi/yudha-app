import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_capture.dart';

LiveInterviewAudioCapture createLiveInterviewAudioCapture() =>
    _AndroidLiveInterviewAudioCapture();

class _AndroidLiveInterviewAudioCapture implements LiveInterviewAudioCapture {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start() {
    return _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        streamBufferSize: 4096,
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
