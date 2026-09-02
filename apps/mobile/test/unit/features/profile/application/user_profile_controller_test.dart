import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_controller.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_state.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';

void main() {
  test('loads and saves the authenticated profile', () async {
    final _FakeUserProfileRepository repository = _FakeUserProfileRepository();
    final UserProfileController controller = UserProfileController(
      repository: repository,
    );

    await controller.load();
    expect(controller.state.status, UserProfileStatus.ready);
    expect(controller.state.profile?.username, 'raka');

    final UserProfile? updated = await controller.save(
      const UserProfileUpdate(
        username: 'raka-baru',
        fullName: 'Raka Baru',
        target: ProfileTarget.bumn,
      ),
    );

    expect(updated?.displayName, 'Raka Baru');
    expect(controller.state.profile?.target, ProfileTarget.bumn);
  });

  test('keeps the current profile when saving fails', () async {
    final _FakeUserProfileRepository repository = _FakeUserProfileRepository();
    final UserProfileController controller = UserProfileController(
      repository: repository,
    );
    await controller.load();
    repository.shouldFail = true;

    final UserProfile? updated = await controller.save(
      const UserProfileUpdate(
        username: 'raka-baru',
        fullName: 'Raka Baru',
        target: ProfileTarget.bumn,
      ),
    );

    expect(updated, isNull);
    expect(controller.state.status, UserProfileStatus.ready);
    expect(controller.state.profile?.username, 'raka');
    expect(controller.state.errorMessage, isNotEmpty);
  });
}

class _FakeUserProfileRepository implements UserProfileRepository {
  bool shouldFail = false;

  @override
  Future<void> deleteAccount() async {
    if (shouldFail) throw Exception('Akun belum dapat dihapus.');
  }

  @override
  Future<UserProfile> deleteAccountData() async {
    if (shouldFail) throw Exception('Data belum dapat dihapus.');
    return const UserProfile(
      id: 'user-1',
      username: 'raka',
      fullName: 'Raka Saputra',
      target: ProfileTarget.cpns,
    );
  }

  @override
  Future<UserProfile> fetchProfile() async {
    return const UserProfile(
      id: 'user-1',
      username: 'raka',
      fullName: 'Raka Saputra',
      target: ProfileTarget.cpns,
    );
  }

  @override
  Future<UserProfile> updateProfile(UserProfileUpdate update) async {
    if (shouldFail) {
      throw Exception('Profil belum dapat disimpan.');
    }
    return UserProfile(
      id: 'user-1',
      username: update.username,
      fullName: update.fullName,
      target: update.target,
    );
  }
}
