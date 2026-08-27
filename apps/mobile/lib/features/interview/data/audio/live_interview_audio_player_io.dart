import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_player.dart';

LiveInterviewAudioPlayer createLiveInterviewAudioPlayer() =>
    _AndroidLiveInterviewAudioPlayer();

class _AndroidLiveInterviewAudioPlayer implements LiveInterviewAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  File? _temporaryFile;

  @override
  Future<void> playUrl(String url, {String? accessToken}) async {
    await stop();
    await _player.setUrl(
      url,
      headers: accessToken?.trim().isNotEmpty == true
          ? <String, String>{'authorization': 'Bearer $accessToken'}
          : null,
    );
    await _playToCompletion();
  }

  @override
  Future<void> playBytes(
    Uint8List bytes, {
    required String fileExtension,
  }) async {
    await stop();
    final String safeExtension = fileExtension.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );
    final File file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'interview_question_${DateTime.now().microsecondsSinceEpoch}.'
      '${safeExtension.isEmpty ? 'mp3' : safeExtension}',
    );
    await file.writeAsBytes(bytes, flush: true);
    _temporaryFile = file;
    try {
      await _player.setFilePath(file.path);
      await _playToCompletion();
    } finally {
      await _deleteTemporaryFile();
    }
  }

  Future<void> _playToCompletion() async {
    await _player.play();
    if (_player.processingState != ProcessingState.completed) {
      await _player.processingStateStream.firstWhere(
        (ProcessingState state) => state == ProcessingState.completed,
      );
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _deleteTemporaryFile();
  }

  Future<void> _deleteTemporaryFile() async {
    final File? file = _temporaryFile;
    _temporaryFile = null;
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
