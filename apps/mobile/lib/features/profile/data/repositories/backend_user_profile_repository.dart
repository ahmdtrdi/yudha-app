import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';

class UserProfileApiConfig {
  const UserProfileApiConfig({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.accessToken,
    this.requestTimeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final String? accessToken;
  final Duration requestTimeout;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;
}

class BackendUserProfileRepository implements UserProfileRepository {
  BackendUserProfileRepository({
    required UserProfileApiConfig config,
    http.Client? client,
  }) : _config = config,
       _client = client ?? http.Client();

  final UserProfileApiConfig _config;
  final http.Client _client;

  @override
  Future<UserProfile> fetchProfile() async {
    return UserProfile.fromJson(await _request('GET'));
  }

  @override
  Future<UserProfile> updateProfile(UserProfileUpdate update) async {
    return UserProfile.fromJson(await _request('PATCH', body: update.toJson()));
  }

  Future<Map<String, dynamic>> _request(
    String method, {
    Map<String, Object?>? body,
  }) async {
    if (!_config.hasAccessToken) {
      throw const UserProfileApiException(
        'Sesi loginmu sudah berakhir. Silakan masuk kembali.',
      );
    }

    final Uri uri = Uri.parse('${_config.baseUrl}/profile');
    final Map<String, String> headers = <String, String>{
      'authorization': 'Bearer ${_config.accessToken}',
      'content-type': 'application/json',
    };
    final http.Response response;
    try {
      response = method == 'PATCH'
          ? await _client
                .patch(uri, headers: headers, body: jsonEncode(body))
                .timeout(_config.requestTimeout)
          : await _client
                .get(uri, headers: headers)
                .timeout(_config.requestTimeout);
    } on TimeoutException {
      throw const UserProfileApiException(
        'Profil membutuhkan waktu terlalu lama untuk dimuat. Coba lagi.',
      );
    }

    final Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw const UserProfileApiException(
        'Profil belum dapat dibaca. Silakan coba lagi.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserProfileApiException(_messageForStatus(response.statusCode));
    }
    if (decoded is! Map<String, dynamic>) {
      throw const UserProfileApiException(
        'Profil belum dapat dibaca. Silakan coba lagi.',
      );
    }
    return decoded;
  }

  String _messageForStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Sesi loginmu sudah berakhir. Silakan masuk kembali.';
    }
    if (statusCode == 404) {
      return 'Profilmu belum ditemukan.';
    }
    if (statusCode >= 500) {
      return 'Profil sedang tidak tersedia. Coba lagi sebentar.';
    }
    return 'Perubahan profil belum berhasil disimpan. Silakan coba lagi.';
  }
}

class UserProfileApiException implements Exception {
  const UserProfileApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
