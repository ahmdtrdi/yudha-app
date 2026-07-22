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

  static const ArenaVisualTheme cpns = ArenaVisualTheme(
    id: 'arena-cpns',
    field: Color(0xFFDDD0B5),
    fieldAccent: Color(0xFFB9A98B),
    river: Color(0xFF55AFC7),
    riverEdge: Color(0xFF8B806A),
    bridge: Color(0xFFEEDDBD),
    bridgeLine: Color(0xFFC0A679),
    boundary: Color(0xFFE8D6B5),
    playerWash: Color(0x38284F8F),
    opponentWash: Color(0x38B74A45),
  );

  static const ArenaVisualTheme bumn = ArenaVisualTheme(
    id: 'arena-bumn',
    field: Color(0xFF384B4E),
    fieldAccent: Color(0xFF26383C),
    river: Color(0xFF2E91A2),
    riverEdge: Color(0xFF1F626D),
    bridge: Color(0xFF9DA5A4),
    bridgeLine: Color(0xFF626D6F),
    boundary: Color(0xFF7B8584),
    playerWash: Color(0x3828A5AC),
    opponentWash: Color(0x38D1903D),
  );

  static ArenaVisualTheme fromId(String id) {
    return switch (id) {
      'arena-bumn' => bumn,
      _ => cpns,
    };
  }
}
