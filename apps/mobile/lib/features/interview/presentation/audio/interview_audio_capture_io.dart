import 'dart:io';

import 'package:record/record.dart';
import 'package:yudha_mobile/features/interview/presentation/audio/interview_audio_capture.dart';

InterviewAudioCapture createInterviewAudioCapture() =>
    _IoInterviewAudioCapture();

class _IoInterviewAudioCapture implements InterviewAudioCapture {
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final String path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'interview_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _recordingPath = path;
  }

  @override
  Future<CapturedInterviewAudio?> stop({bool cancel = false}) async {
    final String? configuredPath = _recordingPath;
    _recordingPath = null;

    if (cancel) {
      await _recorder.cancel();
      if (configuredPath != null) {
        await _deleteIfPresent(configuredPath);
      }
      return null;
    }

    final String? recordedPath = await _recorder.stop();
    final String? path = recordedPath?.isNotEmpty == true
        ? recordedPath
        : configuredPath;
    if (path == null) {
      return null;
    }

    final File file = File(path);
    try {
      if (!await file.exists()) {
        return null;
      }
      return CapturedInterviewAudio(
        bytes: await file.readAsBytes(),
        filename: 'recording.m4a',
      );
    } finally {
      await _deleteIfPresent(path);
    }
  }

  Future<void> _deleteIfPresent(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> dispose() async {
    final String? path = _recordingPath;
    _recordingPath = null;
    await _recorder.dispose();
    if (path != null) {
      await _deleteIfPresent(path);
    }
  }
}
