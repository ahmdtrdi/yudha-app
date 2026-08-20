import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/data/repositories/backend_game_economy_repository.dart';

void main() {
  test('maps the production store snapshot and equipped loadout', () async {
    final BackendGameEconomyRepository repository =
        BackendGameEconomyRepository(
          accessToken: 'token',
          baseUrl: 'https://api.example.test',
          client: MockClient((http.Request request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/store/items');
            expect(request.headers['authorization'], 'Bearer token');
            return http.Response(
              jsonEncode(<String, Object?>{
                'data': <String, Object?>{
                  'coins': 420,
                  'ownedItemIds': <String>[
                    'character-basic-squire',
                    'character-basic-pip',
                    'tower-garda-biru',
                  ],
                  'items': <Map<String, Object?>>[
                    <String, Object?>{
                      'id': 'character-basic-pip',
                      'type': 'character_skin',
                      'name': 'Pip Server',
                      'description': 'Authoritative description',
                      'rarity': 'rare',
                      'coinPrice': 777,
                      'passExclusive': true,
                    },
                  ],
                  'equipped': <String, Object?>{
                    'characterId': 'character-basic-pip',
                    'towerId': 'tower-garda-biru',
                    'arenaId': 'arena-cpns',
                  },
                },
              }),
              200,
            );
          }),
        );
    addTearDown(repository.dispose);

    final snapshot = await repository.fetch();

    expect(snapshot.coins, 420);
    expect(snapshot.characterId, 'character-basic-pip');
    expect(snapshot.towerId, 'tower-garda-biru');
    expect(snapshot.ownedItemIds, contains('character-basic-pip'));
    expect(snapshot.items.single.name, 'Pip Server');
    expect(snapshot.items.single.price, 777);
    expect(snapshot.items.single.passExclusive, isTrue);
    expect(snapshot.items.single.assetPath, isNotNull);
  });

  test('purchase persists the selected cosmetic before refreshing', () async {
    final List<String> requests = <String>[];
    final BackendGameEconomyRepository repository =
        BackendGameEconomyRepository(
          accessToken: 'token',
          baseUrl: 'https://api.example.test',
          client: MockClient((http.Request request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.url.path == '/store/loadout') {
              expect(jsonDecode(request.body), <String, Object?>{
                'characterId': 'character-basic-pip',
              });
            }
            if (request.url.path == '/store/items') {
              return http.Response(
                jsonEncode(<String, Object?>{
                  'data': <String, Object?>{
                    'coins': 10,
                    'ownedItemIds': <String>[
                      'character-basic-squire',
                      'character-basic-pip',
                      'tower-garda-biru',
                      'arena-cpns',
                    ],
                    'equipped': <String, Object?>{
                      'characterId': 'character-basic-pip',
                      'towerId': 'tower-garda-biru',
                      'arenaId': 'arena-cpns',
                    },
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode(<String, Object?>{
                'data': <String, Object?>{'ok': true},
              }),
              200,
            );
          }),
        );
    addTearDown(repository.dispose);

    final snapshot = await repository.purchaseAndEquip(
      GameEconomyCatalog.characters[1],
    );

    expect(requests, <String>[
      'POST /store/purchases',
      'PATCH /store/loadout',
      'GET /store/items',
    ]);
    expect(snapshot.characterId, 'character-basic-pip');
  });
}
