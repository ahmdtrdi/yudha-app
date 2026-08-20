import 'dart:async';

import 'package:uuid/uuid.dart';

typedef SocketAckEmitter =
    void Function(
      String event,
      Map<String, Object?> payload,
      void Function(dynamic response) acknowledgement,
    );

class SocketCommandFailure implements Exception {
  const SocketCommandFailure({
    required this.code,
    required this.message,
    this.details = const <String, dynamic>{},
    this.requestId,
  });

  final String code;
  final String message;
  final Map<String, dynamic> details;
  final String? requestId;

  @override
  String toString() => message;
}

class SocketCommandAcknowledger {
  SocketCommandAcknowledger({
    String Function()? commandIdGenerator,
    this.acknowledgementTimeout = const Duration(seconds: 2),
  }) : _commandIdGenerator = commandIdGenerator ?? const Uuid().v4;

  final String Function() _commandIdGenerator;
  final Duration acknowledgementTimeout;

  Future<Map<String, dynamic>> send({
    required String event,
    required Map<String, Object?> payload,
    required SocketAckEmitter emit,
    required Future<void> Function() reconnect,
  }) async {
    final Map<String, Object?> command = <String, Object?>{
      ...payload,
      'commandId': _commandIdGenerator(),
    };

    Future<Map<String, dynamic>> attempt() {
      final completer = Completer<Map<String, dynamic>>();
      emit(event, command, (dynamic response) {
        if (!completer.isCompleted) completer.complete(_asMap(response));
      });
      return completer.future.timeout(acknowledgementTimeout);
    }

    Map<String, dynamic> acknowledgement;
    try {
      acknowledgement = await attempt();
    } on TimeoutException {
      await reconnect();
      acknowledgement = await attempt();
    }

    final Map<String, dynamic> error = _asMap(acknowledgement['error']);
    if (error.isNotEmpty) {
      throw SocketCommandFailure(
        code: error['code']?.toString() ?? 'COMMAND_REJECTED',
        message:
            error['message']?.toString() ?? 'Command arena ditolak server.',
        details: _asMap(error['details']),
        requestId: error['requestId']?.toString(),
      );
    }
    return acknowledgement;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map<Object?, Object?>) {
      return value.map(
        (Object? key, Object? item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
  }
}
