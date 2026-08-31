import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';

void main() {
  group('Solo draft compatibility contract', () {
    test('round-trips balanced, recommended, and custom requests', () {
      final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[
        <String, dynamic>{
          'idempotencyKey': 'solo-balanced-1',
          'mechanicMode': 'focus',
          'questionSelection': <String, dynamic>{'type': 'balanced'},
        },
        <String, dynamic>{
          'idempotencyKey': 'solo-recommended-1',
          'mechanicMode': 'standard',
          'questionSelection': <String, dynamic>{'type': 'recommended'},
          'recommendationId': 'rec-1',
        },
        <String, dynamic>{
          'idempotencyKey': 'solo-custom-1',
          'mechanicMode': 'speed',
          'questionSelection': <String, dynamic>{
            'type': 'custom',
            'skillIds': <String>['cpns.tiu.numerik.percentage-increase'],
          },
        },
      ];

      for (final Map<String, dynamic> payload in payloads) {
        expect(SoloDraftSessionRequest.fromJson(payload).toJson(), payload);
      }
    });

    test('rejects unknown mechanic and question-selection values', () {
      expect(
        () => SoloMechanicMode.parse('untimed'),
        throwsA(
          isA<SoloContractException>().having(
            (SoloContractException error) => error.field,
            'field',
            'mechanicMode',
          ),
        ),
      );
      expect(
        () => SoloQuestionSelection.fromJson(<String, dynamic>{'type': 'auto'}),
        throwsA(
          isA<SoloContractException>().having(
            (SoloContractException error) => error.field,
            'field',
            'questionSelection.type',
          ),
        ),
      );
    });

    test('requires unique Custom skill IDs', () {
      expect(
        () => SoloCustomQuestionSelection(const <String>[]),
        throwsA(isA<SoloContractException>()),
      );
      expect(
        () => SoloCustomQuestionSelection(const <String>[
          'cpns.tiu.numerik',
          'cpns.tiu.numerik',
        ]),
        throwsA(
          isA<SoloContractException>().having(
            (SoloContractException error) => error.field,
            'field',
            'questionSelection.skillIds',
          ),
        ),
      );
    });

    test('requires recommendation identity only for Recommended', () {
      expect(
        () => SoloSessionConfiguration(
          mechanicMode: SoloMechanicMode.focus,
          questionSelection: const SoloRecommendedQuestionSelection(),
        ),
        throwsA(
          isA<SoloContractException>().having(
            (SoloContractException error) => error.field,
            'field',
            'recommendationId',
          ),
        ),
      );
      expect(
        () => SoloSessionConfiguration(
          mechanicMode: SoloMechanicMode.focus,
          questionSelection: const SoloBalancedQuestionSelection(),
          recommendationId: 'rec-1',
        ),
        throwsA(isA<SoloContractException>()),
      );
    });

    test('does not infer V2 evidence from legacy Practice', () {
      final LegacyPracticeSoloCompatibility compatibility =
          LegacyPracticeSoloCompatibility(
            category: ' tiu ',
            subcategory: 'numerik',
          );

      expect(compatibility.category, 'tiu');
      expect(compatibility.subcategory, 'numerik');
      expect(compatibility.effectiveMechanicMode, isNull);
      expect(compatibility.effectiveQuestionSelection, isNull);
      expect(compatibility.limitations, hasLength(3));
    });
  });
}
