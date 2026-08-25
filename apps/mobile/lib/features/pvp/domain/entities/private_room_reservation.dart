import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

/// Reservation returned after successfully creating a private room.
class PrivateRoomReservation {
  const PrivateRoomReservation({
    required this.code,
    required this.target,
    required this.expiresAt,
  });

  final String code;
  final BattleTarget target;
  final DateTime expiresAt;
}
