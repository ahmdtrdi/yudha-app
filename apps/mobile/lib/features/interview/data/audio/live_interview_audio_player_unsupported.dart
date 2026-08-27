import 'dart:typed_data';

import 'package:yudha_mobile/features/interview/data/audio/live_interview_audio_player.dart';

LiveInterviewAudioPlayer createLiveInterviewAudioPlayer() =>
    _UnsupportedLiveInterviewAudioPlayer();

class _UnsupportedLiveInterviewAudioPlayer implements LiveInterviewAudioPlayer {
  @override
  Future<void> playBytes(Uint8List bytes, {required String fileExtension}) =>
      throw UnsupportedError('Live interview audio is Android-only.');

  @override
  Future<void> playUrl(String url, {String? accessToken}) =>
      throw UnsupportedError('Live interview audio is Android-only.');

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
