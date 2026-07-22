import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _sampleRate = 16000;
const double _tau = pi * 2;

void main() {
  final Directory output = Directory('assets/audio')
    ..createSync(recursive: true);

  _writeWave(output, 'arena_loop.wav', 12, _musicSample);
  _writeWave(output, 'countdown.wav', 0.12, _countdownSample);
  _writeWave(output, 'card_pick.wav', 0.11, _cardSample);
  _writeWave(output, 'cast.wav', 0.32, _castSample);
  _writeWave(output, 'projectile.wav', 0.58, _projectileSample);
  _writeWave(output, 'impact.wav', 0.34, _impactSample);
  _writeWave(output, 'heal.wav', 0.62, _healSample);
}

typedef SampleBuilder = double Function(double time, int sample);

void _writeWave(
  Directory output,
  String name,
  double durationSeconds,
  SampleBuilder builder,
) {
  final int sampleCount = (_sampleRate * durationSeconds).round();
  final ByteData bytes = ByteData(44 + sampleCount * 2);
  _writeAscii(bytes, 0, 'RIFF');
  bytes.setUint32(4, 36 + sampleCount * 2, Endian.little);
  _writeAscii(bytes, 8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, _sampleRate, Endian.little);
  bytes.setUint32(28, _sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  bytes.setUint32(40, sampleCount * 2, Endian.little);

  for (int index = 0; index < sampleCount; index += 1) {
    final double time = index / _sampleRate;
    final double sample = builder(time, index).clamp(-0.95, 0.95);
    bytes.setInt16(44 + index * 2, (sample * 32767).round(), Endian.little);
  }
  File('${output.path}/$name').writeAsBytesSync(bytes.buffer.asUint8List());
}

void _writeAscii(ByteData bytes, int offset, String value) {
  for (int index = 0; index < value.length; index += 1) {
    bytes.setUint8(offset + index, value.codeUnitAt(index));
  }
}

double _musicSample(double time, int sample) {
  const double beat = 0.75;
  const List<List<double>> chords = <List<double>>[
    <double>[130.81, 155.56, 196.00],
    <double>[103.83, 130.81, 155.56],
    <double>[155.56, 196.00, 233.08],
    <double>[116.54, 146.83, 174.61],
  ];
  const List<double> melody = <double>[
    392.00,
    466.16,
    523.25,
    466.16,
    311.13,
    392.00,
    466.16,
    392.00,
  ];

  final int beatIndex = (time / beat).floor();
  final double withinBeat = (time % beat) / beat;
  final List<double> chord = chords[(beatIndex ~/ 4) % chords.length];
  final double noteEnvelope = pow(sin(pi * withinBeat), 1.7).toDouble();
  final double loopFade = min(1, min(time / 0.06, (12 - time) / 0.06));
  final double bass = sin(_tau * chord.first / 2 * time) * 0.12;
  final double pad =
      chord
          .map((double frequency) => sin(_tau * frequency * time))
          .reduce((double a, double b) => a + b) *
      0.032;
  final double lead =
      sin(_tau * melody[beatIndex % melody.length] * time) *
      noteEnvelope *
      0.055;
  final double pulse =
      sin(_tau * 70 * time) *
      exp(-withinBeat * 10) *
      (beatIndex.isEven ? 0.07 : 0.035);
  return (bass + pad + lead + pulse) * loopFade;
}

double _countdownSample(double time, int sample) {
  final double envelope = exp(-time * 26);
  return (sin(_tau * 760 * time) + sin(_tau * 1140 * time) * 0.35) *
      envelope *
      0.34;
}

double _cardSample(double time, int sample) {
  final double progress = time / 0.11;
  final double frequency = 560 + progress * 520;
  return sin(_tau * frequency * time) * pow(1 - progress, 1.8) * 0.38;
}

double _castSample(double time, int sample) {
  final double progress = time / 0.32;
  final double frequency = 180 + progress * 680;
  final double noise = sin(sample * 12.9898) * sin(sample * 0.047);
  return (sin(_tau * frequency * time) * 0.25 + noise * 0.09) *
      sin(pi * progress);
}

double _projectileSample(double time, int sample) {
  final double progress = time / 0.58;
  final double wobble = sin(_tau * (250 + progress * 180) * time);
  final double air = sin(sample * 0.731) * sin(sample * 0.0137);
  return (wobble * 0.16 + air * 0.075) * pow(sin(pi * progress), 0.7);
}

double _impactSample(double time, int sample) {
  final double progress = time / 0.34;
  final double noise = sin(sample * 4.123) * sin(sample * 0.019);
  final double boom = sin(_tau * (96 - progress * 42) * time);
  return (boom * 0.42 + noise * 0.22) * exp(-progress * 4.2);
}

double _healSample(double time, int sample) {
  final double progress = time / 0.62;
  const List<double> notes = <double>[392, 523.25, 659.25, 783.99];
  final int noteIndex = min(
    notes.length - 1,
    (progress * notes.length).floor(),
  );
  final double local = (progress * notes.length) % 1;
  final double envelope = pow(sin(pi * local), 0.8).toDouble();
  return (sin(_tau * notes[noteIndex] * time) * 0.23 +
          sin(_tau * notes[noteIndex] * 2 * time) * 0.06) *
      envelope *
      (1 - progress * 0.35);
}
