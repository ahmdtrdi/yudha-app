import 'dart:typed_data';

import 'live_interview_audio_player_io.dart'
    if (dart.library.js_interop) 'live_interview_audio_player_unsupported.dart'
    as platform;

abstract interface class LiveInterviewAudioPlayer {
  Future<void> playUrl(String url, {String? accessToken});

  Future<void> playBytes(Uint8List bytes, {required String fileExtension});

  Future<void> stop();

  Future<void> dispose();
}

LiveInterviewAudioPlayer createLiveInterviewAudioPlayer() =>
    platform.createLiveInterviewAudioPlayer();
