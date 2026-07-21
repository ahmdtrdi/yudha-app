import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Owns the short-lived audio resources used by one PvP arena session.
///
/// Audio failures are deliberately non-fatal: an unavailable audio device or
/// platform plugin must never interrupt the battle loop.
class ArenaAudioController {
  ArenaAudioController({required bool enabled}) : _enabled = enabled;

  static const String _musicAsset = 'audio/arena_loop.wav';
  static const List<String> _preloadAssets = <String>[
    _musicAsset,
    'audio/countdown.wav',
    'audio/card_pick.wav',
    'audio/cast.wav',
    'audio/projectile.wav',
    'audio/impact.wav',
    'audio/heal.wav',
  ];

  final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'pvp_arena_music');
  final List<AudioPlayer> _effectPlayers = List<AudioPlayer>.generate(
    3,
    (int index) => AudioPlayer(playerId: 'pvp_arena_sfx_$index'),
  );

  bool _enabled;
  bool _disposed = false;
  bool _musicPrepared = false;
  bool _musicPaused = false;
  int _effectPlayerIndex = 0;
  Future<void>? _startOperation;

  Future<void> start() {
    if (!_enabled || _disposed) {
      return Future<void>.value();
    }
    return _startOperation ??= _prepareAndPlayMusic();
  }

  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) {
      return;
    }
    _enabled = enabled;
    if (!enabled) {
      await _safely(_musicPlayer.pause);
      return;
    }
    await resumeMusic();
  }

  Future<void> pauseMusic() async {
    if (_disposed) {
      return;
    }
    _musicPaused = true;
    if (!_musicPrepared) {
      return;
    }
    await _safely(_musicPlayer.pause);
  }

  Future<void> resumeMusic() async {
    if (_disposed || !_enabled) {
      return;
    }
    _musicPaused = false;
    if (!_musicPrepared) {
      await start();
      if (!_musicPrepared && !_musicPaused && !_disposed) {
        _startOperation = null;
        await start();
      }
      return;
    }
    await _safely(_musicPlayer.resume);
  }

  void playCountdown() => _playEffect('audio/countdown.wav', volume: 0.32);

  void playCardPick() => _playEffect('audio/card_pick.wav', volume: 0.34);

  void playCast() => _playEffect('audio/cast.wav', volume: 0.34);

  void playProjectile() => _playEffect('audio/projectile.wav', volume: 0.28);

  void playImpact() => _playEffect('audio/impact.wav', volume: 0.38);

  void playHeal() => _playEffect('audio/heal.wav', volume: 0.34);

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _safely(_musicPlayer.stop);
    await _safely(_musicPlayer.dispose);
    await Future.wait<void>(
      _effectPlayers.map((AudioPlayer player) => _safely(player.dispose)),
    );
  }

  Future<void> _prepareAndPlayMusic() async {
    try {
      await AudioCache.instance.loadAll(_preloadAssets);
      if (_disposed || !_enabled || _musicPaused) {
        return;
      }
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(
        AssetSource(_musicAsset),
        volume: 0.18,
        mode: PlayerMode.mediaPlayer,
      );
      _musicPrepared = true;
      _musicPaused = false;
    } catch (_) {
      // Battle remains fully playable when a device cannot initialize audio.
    }
  }

  void _playEffect(String asset, {required double volume}) {
    if (!_enabled || _disposed || _musicPaused) {
      return;
    }
    final AudioPlayer player = _effectPlayers[_effectPlayerIndex];
    _effectPlayerIndex = (_effectPlayerIndex + 1) % _effectPlayers.length;
    unawaited(_playOn(player, asset, volume));
  }

  Future<void> _playOn(AudioPlayer player, String asset, double volume) async {
    try {
      await player.stop();
      if (_disposed || !_enabled || _musicPaused) {
        return;
      }
      await player.play(
        AssetSource(asset),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // SFX is decorative and must not affect input or animation timing.
    }
  }

  Future<void> _safely(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Audio resources can already be unavailable during app shutdown.
    }
  }
}
