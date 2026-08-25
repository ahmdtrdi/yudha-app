import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Owns the short-lived audio resources used by one PvP arena session.
///
/// BGM and every SFX deliberately run on [AudioPlayer] instances of ONE
/// package only. Mixing separate audio engines (e.g. audioplayers for SFX)
/// makes them fight over the platform audio session, pausing the looping
/// BGM on each effect. One package = one session = uninterrupted BGM.
///
/// Each SFX asset gets a dedicated pre-loaded player so replaying is a
/// cheap seek-to-zero + play, keeping effects snappy and overlap-friendly.
///
/// Audio failures are deliberately non-fatal: an unavailable audio device
/// or platform plugin must never interrupt the battle loop.
class ArenaAudioController {
  ArenaAudioController({
    required bool enabled,
    double musicLevel = defaultMusicLevel,
  }) : this._(enabled: enabled, musicLevel: musicLevel);

  /// Sound-effects-only variant for surfaces outside the live battle loop
  /// (question sheet, result screen). No music is ever prepared or played.
  ArenaAudioController.sfxOnly({required bool enabled})
    : this._(enabled: enabled, musicLevel: 0);

  ArenaAudioController._({required bool enabled, required double musicLevel})
    : _enabled = enabled,
      _musicLevel = musicLevel.clamp(0.0, 1.0);

  /// Normalized music slider default (kept intentionally low; the actual
  /// playback gain is a fraction of this so SFX stay dominant).
  static const double defaultMusicLevel = 0.3;
  static const double _maxMusicGain = 0.45;

  static const String _musicAsset = 'assets/audio/arena_loop.wav';

  /// Per-asset output gain keeps BGM dominant over effects.
  static const Map<String, double> _sfxVolumes = <String, double>{
    'audio/countdown.wav': 0.32,
    'audio/card_pick.wav': 0.34,
    'audio/cast.wav': 0.34,
    'audio/projectile.wav': 0.28,
    'audio/impact.wav': 0.38,
    'audio/heal.wav': 0.34,
    'audio/answer_correct.wav': 0.36,
    'audio/answer_wrong.wav': 0.34,
    'audio/tick.wav': 0.26,
    'audio/victory_stinger.wav': 0.44,
    'audio/defeat_stinger.wav': 0.4,
  };

  final AudioPlayer _musicPlayer = AudioPlayer();
  final Map<String, AudioPlayer> _sfxPlayers = <String, AudioPlayer>{};
  final Set<String> _sfxLoaded = <String>{};

  bool _enabled;
  double _musicLevel;
  bool _disposed = false;
  bool _musicPrepared = false;
  bool _musicPaused = false;
  Future<void>? _startOperation;
  StreamSubscription<PlayerState>? _musicStateSub;

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

  /// Updates the arena music level (normalized 0..1) live.
  Future<void> setMusicLevel(double level) async {
    if (_disposed) {
      return;
    }
    final double next = level.clamp(0.0, 1.0);
    if (next == _musicLevel) {
      return;
    }
    _musicLevel = next;
    if (!_musicPrepared) {
      return;
    }
    await _safely(() => _musicPlayer.setVolume(_gain));
  }

  /// Recovers playback when something external paused the BGM (focus theft,
  /// OEM audio effects, codec hiccups). Safe to call repeatedly.
  Future<void> ensureMusic() => _recoverPlayback();

  double get _gain => (_musicLevel * _maxMusicGain).clamp(0.0, 1.0);

  Future<void> _recoverPlayback() async {
    if (_disposed || !_enabled || _musicPaused) {
      return;
    }
    if (_musicPrepared && !_musicPlayer.playing) {
      await _safely(() => _musicPlayer.setVolume(_gain));
      await _safely(_musicPlayer.play);
      return;
    }
    if (!_musicPrepared) {
      _startOperation = null;
      await start();
    }
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
    await _recoverPlayback();
  }

  void playCountdown() => _playEffect('audio/countdown.wav');

  void playCardPick() => _playEffect('audio/card_pick.wav');

  void playCast() => _playEffect('audio/cast.wav');

  void playProjectile() => _playEffect('audio/projectile.wav');

  void playImpact() => _playEffect('audio/impact.wav');

  void playHeal() => _playEffect('audio/heal.wav');

  void playAnswerCorrect() => _playEffect('audio/answer_correct.wav');

  void playAnswerWrong() => _playEffect('audio/answer_wrong.wav');

  void playTickdown() => _playEffect('audio/tick.wav');

  void playVictoryStinger() => _playEffect('audio/victory_stinger.wav');

  void playDefeatStinger() => _playEffect('audio/defeat_stinger.wav');

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _musicStateSub?.cancel();
    await _safely(_musicPlayer.stop);
    await _safely(_musicPlayer.dispose);
    for (final AudioPlayer player in _sfxPlayers.values) {
      await _safely(player.stop);
      await _safely(player.dispose);
    }
    _sfxPlayers.clear();
    _sfxLoaded.clear();
  }

  Future<void> _prepareAndPlayMusic() async {
    // Android can transiently fail the first load when many players spin up
    // at once. Retry with backoff instead of leaving the arena silent.
    const int maxAttempts = 4;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_disposed || !_enabled || _musicPaused) {
        return;
      }
      try {
        if (attempt > 1) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
          if (_disposed || !_enabled || _musicPaused) {
            return;
          }
        }
        await _musicPlayer.setAsset(_musicAsset);
        await _musicPlayer.setLoopMode(LoopMode.one);
        await _musicPlayer.setVolume(_gain);
        _musicPrepared = true;
        _musicPaused = false;
        _startBgmWatchdog();
        unawaited(_warmUpSfx());
        // play()'s future stays pending while LoopMode.one loops, so it must
        // not be awaited here.
        unawaited(_musicPlayer.play().catchError((Object _) {}));
        return;
      } catch (_) {
        // Retry; battle remains fully playable when a device cannot
        // initialize audio.
      }
    }
  }

  /// Pre-decodes every effect right after the music starts so the first
  /// actual trigger plays instantly.
  Future<void> _warmUpSfx() async {
    for (final String asset in _sfxVolumes.keys) {
      if (_disposed || !_enabled) {
        return;
      }
      try {
        final AudioPlayer player = _sfxPlayers.putIfAbsent(
          asset,
          AudioPlayer.new,
        );
        if (_sfxLoaded.add(asset)) {
          await player.setAsset('assets/$asset');
          await player.setVolume(_sfxVolumes[asset] ?? 0.32);
        }
      } catch (_) {
        // A missing or unreadable effect must not break the rest.
      }
    }
  }

  /// Reclaims BGM playback whenever something external pauses it. Intentional
  /// pauses (pause menu, app background) are ignored via [_musicPaused].
  void _startBgmWatchdog() {
    _musicStateSub ??= _musicPlayer.playerStateStream.listen(
      (PlayerState state) {
        if (state.playing ||
            _disposed ||
            !_enabled ||
            _musicPaused ||
            !_musicPrepared) {
          return;
        }
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 120)).then((_) {
            if (_disposed ||
                !_enabled ||
                _musicPaused ||
                !_musicPrepared ||
                _musicPlayer.playing) {
              return;
            }
            unawaited(_musicPlayer.play().catchError((Object _) {}));
          }),
        );
      },
    );
  }

  Future<void> _playEffect(String asset) async {
    if (!_enabled || _disposed || _musicPaused) {
      return;
    }
    try {
      final AudioPlayer player = _sfxPlayers.putIfAbsent(
        asset,
        AudioPlayer.new,
      );
      if (_sfxLoaded.add(asset)) {
        await player.setAsset('assets/$asset');
        await player.setVolume(_sfxVolumes[asset] ?? 0.32);
      }
      if (_disposed || !_enabled || _musicPaused) {
        return;
      }
      await player.seek(Duration.zero);
      unawaited(player.play().catchError((Object _) {}));
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
