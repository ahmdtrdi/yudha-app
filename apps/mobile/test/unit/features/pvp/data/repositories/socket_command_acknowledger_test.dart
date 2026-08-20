import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/pvp/data/repositories/socket_command_acknowledger.dart';

void main() {
  group('SocketCommandAcknowledger', () {
    test(
      'adds a command ID and resolves a successful acknowledgement',
      () async {
        Map<String, Object?>? emitted;
        final acknowledger = SocketCommandAcknowledger(
          commandIdGenerator: () => 'command-1',
        );

        final result = await acknowledger.send(
          event: 'join_queue',
          payload: <String, Object?>{'mode': 'casual'},
          emit: (event, payload, acknowledgement) {
            emitted = payload;
            acknowledgement(<String, Object?>{
              'data': <String, Object?>{'accepted': true},
              'requestId': 'request-1',
            });
          },
          reconnect: () async {},
        );

        expect(emitted, containsPair('commandId', 'command-1'));
        expect(result['requestId'], 'request-1');
      },
    );

    test('retries once with the same command ID after timeout', () async {
      final emitted = <Map<String, Object?>>[];
      var reconnects = 0;
      final acknowledger = SocketCommandAcknowledger(
        commandIdGenerator: () => 'command-retry',
        acknowledgementTimeout: const Duration(milliseconds: 1),
      );

      await acknowledger.send(
        event: 'play_card',
        payload: <String, Object?>{'roomId': 'room-1'},
        emit: (event, payload, acknowledgement) {
          emitted.add(Map<String, Object?>.from(payload));
          if (emitted.length == 2) {
            acknowledgement(<String, Object?>{
              'data': <String, Object?>{'accepted': true},
              'requestId': 'request-retry',
            });
          }
        },
        reconnect: () async => reconnects += 1,
      );

      expect(emitted, hasLength(2));
      expect(emitted[0]['commandId'], emitted[1]['commandId']);
      expect(reconnects, 1);
    });

    test('surfaces stable backend error metadata', () async {
      final acknowledger = SocketCommandAcknowledger(
        commandIdGenerator: () => 'command-error',
      );

      final future = acknowledger.send(
        event: 'open_card',
        payload: <String, Object?>{'roomId': 'room-1'},
        emit: (event, payload, acknowledgement) {
          acknowledgement(<String, Object?>{
            'error': <String, Object?>{
              'code': 'QUEUE_UNAVAILABLE',
              'message': 'Koordinasi tidak tersedia.',
              'details': <String, Object?>{'recoverable': true},
              'requestId': 'request-error',
            },
          });
        },
        reconnect: () async {},
      );

      await expectLater(
        future,
        throwsA(
          isA<SocketCommandFailure>()
              .having((error) => error.code, 'code', 'QUEUE_UNAVAILABLE')
              .having((error) => error.requestId, 'requestId', 'request-error')
              .having(
                (error) => error.details['recoverable'],
                'recoverable',
                true,
              ),
        ),
      );
    });
  });
}
