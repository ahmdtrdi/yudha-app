import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/profile/data/repositories/backend_user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

void main() {
  group('BackendUserProfileRepository', () {
    test('maps the authenticated profile response', () async {
      final BackendUserProfileRepository repository =
          BackendUserProfileRepository(
            config: const UserProfileApiConfig(
              baseUrl: 'https://api.example.test',
              accessToken: 'token-123',
            ),
            client: MockClient((http.Request request) async {
              expect(request.method, 'GET');
              expect(
                request.url.toString(),
                'https://api.example.test/profile',
              );
              expect(request.headers['authorization'], 'Bearer token-123');
              return http.Response(
                jsonEncode(<String, Object?>{
                  'id': 'user-1',
                  'username': 'raka',
                  'full_name': 'Raka Saputra',
                  'target': 'bumn',
                }),
                200,
              );
            }),
          );

      final profile = await repository.fetchProfile();

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Raka Saputra');
      expect(profile.target, ProfileTarget.bumn);
    });

    test('sends only editable profile fields when saving', () async {
      final BackendUserProfileRepository repository =
          BackendUserProfileRepository(
            config: const UserProfileApiConfig(
              baseUrl: 'https://api.example.test',
              accessToken: 'token-123',
            ),
            client: MockClient((http.Request request) async {
              expect(request.method, 'PATCH');
              expect(jsonDecode(request.body), <String, Object?>{
                'username': 'raka-baru',
                'full_name': 'Raka Baru',
                'target': 'cpns',
              });
              return http.Response(
                jsonEncode(<String, Object?>{
                  'id': 'user-1',
                  'username': 'raka-baru',
                  'full_name': 'Raka Baru',
                  'target': 'cpns',
                }),
                200,
              );
            }),
          );

      final profile = await repository.updateProfile(
        const UserProfileUpdate(
          username: 'raka-baru',
          fullName: 'Raka Baru',
          target: ProfileTarget.cpns,
        ),
      );

      expect(profile.username, 'raka-baru');
      expect(profile.target, ProfileTarget.cpns);
    });
  });
}
