import 'package:flutter/material.dart';

class ArenaVisualTheme {
  const ArenaVisualTheme({
    required this.id,
    required this.field,
    required this.fieldAccent,
    required this.river,
    required this.riverEdge,
    required this.bridge,
    required this.bridgeLine,
    required this.boundary,
    required this.playerWash,
    required this.opponentWash,
  });

  final String id;
  final Color field;
  final Color fieldAccent;
  final Color river;
  final Color riverEdge;
  final Color bridge;
  final Color bridgeLine;
  final Color boundary;
  final Color playerWash;
  final Color opponentWash;

  static const ArenaVisualTheme trainingGarden = ArenaVisualTheme(
    id: 'arena-training-garden',
    field: Color(0xFF82D279),
    fieldAccent: Color(0xFF71B96A),
    river: Color(0xFF72C8F1),
    riverEdge: Color(0xFF5FAF68),
    bridge: Color(0xFFFFE0A4),
    bridgeLine: Color(0xFFD8A85A),
    boundary: Color(0xFFFFD89A),
    playerWash: Color(0x222878F0),
    opponentWash: Color(0x22F05E5E),
  );

  static const ArenaVisualTheme sunsetCanyon = ArenaVisualTheme(
    id: 'arena-sunset-canyon',
    field: Color(0xFFE29B65),
    fieldAccent: Color(0xFFC87950),
    river: Color(0xFF62B8D7),
    riverEdge: Color(0xFF9D6243),
    bridge: Color(0xFFFFD28B),
    bridgeLine: Color(0xFFB87C47),
    boundary: Color(0xFFF4C17D),
    playerWash: Color(0x242878F0),
    opponentWash: Color(0x28A93E3E),
  );

  static const ArenaVisualTheme midnightCircuit = ArenaVisualTheme(
    id: 'arena-midnight-circuit',
    field: Color(0xFF253A67),
    fieldAccent: Color(0xFF17284F),
    river: Color(0xFF31B9CF),
    riverEdge: Color(0xFF197F9C),
    bridge: Color(0xFF8BA6D8),
    bridgeLine: Color(0xFF4D6698),
    boundary: Color(0xFF6F86B3),
    playerWash: Color(0x452878F0),
    opponentWash: Color(0x45F05E5E),
  );

  static const ArenaVisualTheme auroraSummit = ArenaVisualTheme(
    id: 'arena-aurora-summit',
    field: Color(0xFF6CB9A1),
    fieldAccent: Color(0xFF4B8C83),
    river: Color(0xFF9EDFE8),
    riverEdge: Color(0xFF3D857C),
    bridge: Color(0xFFE8D6C2),
    bridgeLine: Color(0xFFAE91B8),
    boundary: Color(0xFFD6C3EC),
    playerWash: Color(0x357C6BE8),
    opponentWash: Color(0x35E45D8B),
  );

  static ArenaVisualTheme fromId(String id) {
    return switch (id) {
      'arena-sunset-canyon' => sunsetCanyon,
      'arena-midnight-circuit' => midnightCircuit,
      'arena-aurora-summit' => auroraSummit,
      _ => trainingGarden,
    };
  }
}
