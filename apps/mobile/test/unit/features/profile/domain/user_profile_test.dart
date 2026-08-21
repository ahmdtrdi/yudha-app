import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';

void main() {
  test('maps the complete profile response used by the profile page', () {
    final UserProfile profile = UserProfile.fromJson(<String, dynamic>{
      'id': '14714bab-48a8-463b-8b83-8b770c4af5ec',
      'username': 'user_gal',
      'fullName': 'rindengan2',
      'target': 'bumn',
      'rankPoints': 1178,
      'tier': 'elite',
      'rankedStats': <String, dynamic>{
        'wins': 3,
        'losses': 1,
        'draws': 0,
        'winRate': 75,
      },
      'yCoins': 783,
      'characterId': 'character-legend-drakor',
      'towerId': 'tower-garda-biru',
      'streak': <String, dynamic>{
        'current': 2,
        'best': 2,
        'lastDate': '2026-08-20',
      },
    });

    expect(profile.target, ProfileTarget.bumn);
    expect(profile.rankPoints, 1178);
    expect(profile.tier, 'elite');
    expect(profile.rankedStats?.totalMatches, 4);
    expect(profile.rankedStats?.winRate, 0.75);
    expect(profile.yCoins, 783);
    expect(profile.characterId, 'character-legend-drakor');
    expect(profile.towerId, 'tower-garda-biru');
    expect(profile.streak?.current, 2);
    expect(profile.streak?.best, 2);
    expect(profile.streak?.lastDate, DateTime(2026, 8, 20));
  });
}
