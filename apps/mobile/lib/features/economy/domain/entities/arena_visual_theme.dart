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

  static const ArenaVisualTheme lembahBara = ArenaVisualTheme(
    id: 'arena-lembah-bara',
    field: Color(0xFFE56B2E),
    fieldAccent: Color(0xFF7A271F),
    river: Color(0xFFFF9A3C),
    riverEdge: Color(0xFF68211C),
    bridge: Color(0xFFD99B65),
    bridgeLine: Color(0xFF784D35),
    boundary: Color(0xFFFFB65F),
    playerWash: Color(0x38284F8F),
    opponentWash: Color(0x38B74A45),
  );

  static const ArenaVisualTheme padangHarmoni = ArenaVisualTheme(
    id: 'arena-padang-harmoni',
    field: Color(0xFFA9D957),
    fieldAccent: Color(0xFF4C8B45),
    river: Color(0xFF7BC9B5),
    riverEdge: Color(0xFF367963),
    bridge: Color(0xFFEAD596),
    bridgeLine: Color(0xFF9B7D45),
    boundary: Color(0xFFE9F4B2),
    playerWash: Color(0x3828A5AC),
    opponentWash: Color(0x38D1903D),
  );

  static const ArenaVisualTheme gurunCendekia = ArenaVisualTheme(
    id: 'arena-gurun-cendekia',
    field: Color(0xFFE6B873),
    fieldAccent: Color(0xFFB66C3E),
    river: Color(0xFF86BFC1),
    riverEdge: Color(0xFF4B8586),
    bridge: Color(0xFFD9A866),
    bridgeLine: Color(0xFF8F633C),
    boundary: Color(0xFFF5D49D),
    playerWash: Color(0x38284F8F),
    opponentWash: Color(0x38B74A45),
  );

  static const ArenaVisualTheme rimbaYudha = ArenaVisualTheme(
    id: 'arena-rimba-yudha',
    field: Color(0xFF78B85A),
    fieldAccent: Color(0xFF235C3D),
    river: Color(0xFF54A89C),
    riverEdge: Color(0xFF28645C),
    bridge: Color(0xFF9B7548),
    bridgeLine: Color(0xFF5C422C),
    boundary: Color(0xFFB9DC82),
    playerWash: Color(0x38284F8F),
    opponentWash: Color(0x38B74A45),
  );

  static ArenaVisualTheme fromId(String id) {
    return switch (id) {
      'arena-lembah-bara' => lembahBara,
      'arena-gurun-cendekia' => gurunCendekia,
      'arena-rimba-yudha' => rimbaYudha,
      _ => padangHarmoni,
    };
  }
}
