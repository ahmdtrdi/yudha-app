import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yudha_mobile/app/config/app_config.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/data/repositories/game_economy_repository.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';

class BackendGameEconomyRepository extends GameEconomyRepository {
  BackendGameEconomyRepository({
    required String accessToken,
    this.baseUrl = AppConfig.apiBaseUrl,
    http.Client? client,
  }) : _accessToken = accessToken,
       _client = client ?? http.Client();

  final String _accessToken;
  final String baseUrl;
  final http.Client _client;

  @override
  Future<AuthoritativeEconomySnapshot> fetch() async {
    final Map<String, dynamic> data = await _request(
      'GET',
      Uri.parse('$baseUrl/store/items'),
    );
    final Map<String, dynamic> equipped = _map(data['equipped']);
    return AuthoritativeEconomySnapshot(
      coins: _int(data['coins']),
      ownedItemIds: _list(
        data['ownedItemIds'],
      ).map((Object? value) => value.toString()).toSet(),
      characterId:
          _text(equipped['characterId']) ??
          GameEconomyCatalog.defaultCharacterId,
      towerId: _text(equipped['towerId']) ?? GameEconomyCatalog.defaultTowerId,
      arenaId: _text(equipped['arenaId']) ?? GameEconomyCatalog.defaultArenaId,
    );
  }

  @override
  Future<AuthoritativeEconomySnapshot> purchaseAndEquip(
    CosmeticItem item,
  ) async {
    final String requestId = _requestId('purchase-${item.id}');
    await _request(
      'POST',
      Uri.parse('$baseUrl/store/purchases'),
      body: <String, Object?>{'itemId': item.id, 'idempotencyKey': requestId},
    );
    await _setLoadoutRequest(
      characterId: item.type == CosmeticType.character ? item.id : null,
      towerId: item.type == CosmeticType.tower ? item.id : null,
      arenaId: item.type == CosmeticType.arena ? item.id : null,
    );
    return fetch();
  }

  @override
  Future<AuthoritativeEconomySnapshot> setLoadout({
    String? characterId,
    String? towerId,
    String? arenaId,
  }) async {
    await _setLoadoutRequest(
      characterId: characterId,
      towerId: towerId,
      arenaId: arenaId,
    );
    return fetch();
  }

  @override
  Future<AuthoritativeEconomySnapshot> grantBetaCredit() async {
    await _request(
      'POST',
      Uri.parse('$baseUrl/store/beta-credits'),
      body: <String, Object?>{'idempotencyKey': _requestId('beta-credit')},
    );
    return fetch();
  }

  Future<void> _setLoadoutRequest({
    String? characterId,
    String? towerId,
    String? arenaId,
  }) async {
    await _request(
      'PATCH',
      Uri.parse('$baseUrl/store/loadout'),
      body: <String, Object?>{
        'characterId': ?characterId,
        'towerId': ?towerId,
        'arenaId': ?arenaId,
      },
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final Map<String, String> headers = <String, String>{
      'authorization': 'Bearer $_accessToken',
      'content-type': 'application/json',
    };
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final http.Response response = switch (method) {
      'POST' => await _client.post(uri, headers: headers, body: encodedBody),
      'PATCH' => await _client.patch(uri, headers: headers, body: encodedBody),
      _ => await _client.get(uri, headers: headers),
    };
    final Object? decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? 'Economy request gagal.'
          : 'Economy request gagal.';
      throw GameEconomyApiException(message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const GameEconomyApiException(
        'Economy API mengembalikan data yang tidak valid.',
      );
    }
    final Object? wrappedData = decoded['data'];
    return wrappedData is Map<String, dynamic> ? wrappedData : decoded;
  }

  String _requestId(String operation) {
    return 'mobile-$operation-${DateTime.now().microsecondsSinceEpoch}';
  }

  Map<String, dynamic> _map(Object? value) {
    return value is Map<String, dynamic> ? value : const <String, dynamic>{};
  }

  List<Object?> _list(Object? value) {
    return value is List<Object?> ? value : const <Object?>[];
  }

  String? _text(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  int _int(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    _client.close();
  }
}

class GameEconomyApiException implements Exception {
  const GameEconomyApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
