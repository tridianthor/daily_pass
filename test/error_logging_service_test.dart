import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:daily_pass/core/services/error_logging_service.dart';
import 'package:daily_pass/providers/error_logging_provider.dart';

void main() {
  group('ErrorLoggingConfig', () {
    test('reads build-time configuration without embedding credentials', () {
      final config = ErrorLoggingConfig.fromEnvironment();
      const enabledValue = String.fromEnvironment(
        'ERROR_LOGGING_ENABLED',
        defaultValue: 'false',
      );
      final expectedEnabled = enabledValue.toLowerCase() == 'true';

      expect(config.enabled, expectedEnabled);
      if (expectedEnabled) {
        expect(config.validationError, isNull);
        expect(config.endpoint('events').path, endsWith('/api/v1/events'));
      }
    });

    test('resolves single and batch endpoints with a path prefix', () {
      final config = _config(baseUrl: 'http://localhost:8000/p0inter/');

      expect(
        config.endpoint('events').toString(),
        'http://localhost:8000/p0inter/api/v1/events',
      );
      expect(
        config.endpoint('events/batch').toString(),
        'http://localhost:8000/p0inter/api/v1/events/batch',
      );
    });

    test(
      'accepts local HTTP for development and requires HTTPS in production',
      () {
        expect(
          _config(baseUrl: 'http://localhost:8000').validationError,
          isNull,
        );
        expect(
          _config(
            baseUrl: 'http://logging.example.test',
            environment: 'production',
          ).validationError,
          contains('https'),
        );
      },
    );
  });

  group('ErrorLoggingService', () {
    test(
      'rejects a data URI before transport and exposes the configuration error',
      () async {
        var requestCount = 0;
        final client = MockClient((_) async {
          requestCount++;
          return http.Response('{}', 202);
        });
        final service = ErrorLoggingService(
          config: ErrorLoggingConfig(
            baseUrl: Uri.dataFromString('http://localhost:8000'),
            projectKey: 'pk_test',
            environment: 'development',
          ),
          client: client,
        );

        final result = await service.sendEvent(_event());

        expect(result.status, ErrorLoggingStatus.invalidPayload);
        expect(result.errorMessage, contains('http or https'));
        expect(requestCount, 0);
      },
    );

    test('provider sends through one shared client and disposes it', () async {
      late http.BaseRequest request;
      final client = _TrackingClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({'accepted': true, 'event_id': 'provider-event'}),
          202,
        );
      });
      final container = ProviderContainer(
        overrides: [
          errorLoggingConfigProvider.overrideWithValue(_config()),
          errorLoggingClientProvider.overrideWith((ref) {
            ref.onDispose(client.close);
            return client;
          }),
        ],
      );

      final service = container.read(errorLoggingServiceProvider);
      final result = await service.sendEvent(_event());

      expect(result.status, ErrorLoggingStatus.accepted);
      expect(request.url.toString(), 'http://localhost:8000/api/v1/events');
      expect(request.headers['x-project-key'], 'pk_test');
      expect(container.read(errorLoggingServiceProvider), same(service));

      container.dispose();
      expect(client.closed, isTrue);
    });

    test('skips disabled logging without making a request', () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response('{}', 202);
      });
      final service = ErrorLoggingService(
        config: ErrorLoggingConfig(
          baseUrl: Uri.parse('http://localhost:8000'),
          projectKey: '',
          environment: 'development',
          enabled: false,
        ),
        client: client,
      );

      final result = await service.sendEvent(_event());

      expect(result.status, ErrorLoggingStatus.skipped);
      expect(requestCount, 0);
    });

    test('sends an API-compliant single error event', () async {
      late http.Request request;
      final client = MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({'accepted': true, 'event_id': 'server-event-1'}),
          202,
        );
      });
      final service = ErrorLoggingService(config: _config(), client: client);

      final result = await service.logError(
        StateError('failed'),
        stackTrace: StackTrace.fromString('at test.dart:1'),
        metadata: {'password': 'do-not-send', 'operation': 'save'},
      );

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final nestedError = body['error'] as Map<String, dynamic>;
      final metadata = body['metadata'] as Map<String, dynamic>;
      expect(request.url.toString(), 'http://localhost:8000/api/v1/events');
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers['x-project-key'], 'pk_test');
      expect(body['type'], 'error');
      expect(body['environment'], 'development');
      expect(nestedError['type'], 'StateError');
      expect(nestedError['message'], 'Bad state: failed');
      expect(nestedError['stack_trace'], 'at test.dart:1');
      expect(metadata['password'], '[REDACTED]');
      expect(metadata['operation'], 'save');
      expect(metadata['event_id'], isA<String>());
      expect(result.status, ErrorLoggingStatus.accepted);
      expect(result.eventId, 'server-event-1');
    });

    test(
      'sends an API-compliant single log event without issue fields',
      () async {
        late http.Request request;
        final client = MockClient((incoming) async {
          request = incoming;
          return http.Response(
            jsonEncode({'accepted': true, 'event_id': 'server-log-1'}),
            202,
          );
        });
        final service = ErrorLoggingService(config: _config(), client: client);

        final result = await service.logMessage(
          'activity creation started',
          level: LogLevel.warning,
          logger: 'activity-form',
          traceId: 'trace-1',
          metadata: {'password': 'do-not-send', 'activity_id': 'activity-1'},
          request: {'method': 'POST'},
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], 'log');
        expect(body['level'], 'warning');
        expect(body['message'], 'activity creation started');
        expect(body['environment'], 'development');
        expect(body['service'], 'daily-pass');
        expect(body['logger'], 'activity-form');
        expect(body['trace_id'], 'trace-1');
        expect(body.containsKey('error'), isFalse);
        expect(body.containsKey('context'), isFalse);
        expect(body.containsKey('breadcrumbs'), isFalse);
        final metadata = body['metadata'] as Map<String, dynamic>;
        expect(metadata['password'], '[REDACTED]');
        expect(metadata['activity_id'], 'activity-1');
        expect(metadata['event_id'], isA<String>());
        expect(result.status, ErrorLoggingStatus.accepted);
        expect(result.eventId, 'server-log-1');
      },
    );

    test('serializes every supported log level', () async {
      final requests = <http.Request>[];
      final client = MockClient((incoming) async {
        requests.add(incoming);
        return http.Response(
          jsonEncode({'accepted': true, 'event_id': 'server-log'}),
          202,
        );
      });
      final service = ErrorLoggingService(config: _config(), client: client);

      for (final level in LogLevel.values) {
        final result = await service.logMessage('message', level: level);
        expect(result.status, ErrorLoggingStatus.accepted);
      }

      expect(
        requests
            .map((request) => (jsonDecode(request.body) as Map)['level'])
            .toList(),
        ['trace', 'debug', 'info', 'warning', 'error', 'critical'],
      );
    });

    test('rejects empty log messages before transport', () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response('{}', 202);
      });
      final service = ErrorLoggingService(config: _config(), client: client);

      final result = await service.logMessage('   ');

      expect(result.status, ErrorLoggingStatus.invalidPayload);
      expect(result.errorMessage, contains('empty'));
      expect(requestCount, 0);
    });

    test('sends a mixed log and error batch', () async {
      late http.Request request;
      final client = MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode({'accepted': 2, 'rejected': 0}), 200);
      });
      final service = ErrorLoggingService(config: _config(), client: client);
      final logEvent = LogEvent(
        timestamp: DateTime.utc(2026, 8, 30, 12),
        level: LogLevel.info,
        message: 'worker started',
        environment: 'development',
        service: 'daily-pass',
        eventId: 'log-event',
      );

      final result = await service.sendBatch([logEvent, _event('error-event')]);

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final events = body['events'] as List<dynamic>;
      expect(events, hasLength(2));
      expect((events[0] as Map<String, dynamic>)['type'], 'log');
      expect((events[1] as Map<String, dynamic>)['type'], 'error');
      expect(result.status, ErrorLoggingStatus.accepted);
      expect(result.accepted, 2);
      expect(result.rejected, 0);
    });

    test('reports complete and partial batch responses', () async {
      final responses = <http.Response>[
        http.Response(jsonEncode({'accepted': 2, 'rejected': 0}), 200),
        http.Response(jsonEncode({'accepted': 1, 'rejected': 1}), 200),
      ];
      final client = MockClient((_) async => responses.removeAt(0));
      final service = ErrorLoggingService(config: _config(), client: client);

      final complete = await service.sendBatch([_event('one'), _event('two')]);
      final partial = await service.sendBatch([
        _event('three'),
        _event('four'),
      ]);

      expect(complete.status, ErrorLoggingStatus.accepted);
      expect(complete.accepted, 2);
      expect(complete.rejected, 0);
      expect(partial.status, ErrorLoggingStatus.partialSuccess);
      expect(partial.accepted, 1);
      expect(partial.rejected, 1);
    });

    test('retries 429/500 with the same body and bounded attempts', () async {
      final requests = <http.Request>[];
      final responses = <http.Response>[
        http.Response('busy', 500),
        http.Response(
          jsonEncode({'accepted': true, 'event_id': 'event-after-retry'}),
          202,
        ),
      ];
      final delays = <Duration>[];
      final client = MockClient((incoming) async {
        requests.add(incoming);
        return responses.removeAt(0);
      });
      final service = ErrorLoggingService(
        config: _config(
          maxAttempts: 3,
          initialBackoff: Duration.zero,
          maxBackoff: Duration.zero,
        ),
        client: client,
        delay: (duration) async => delays.add(duration),
        jitter: () => 0,
      );

      final result = await service.sendEvent(_event());

      expect(result.status, ErrorLoggingStatus.accepted);
      expect(result.attempts, 2);
      expect(requests, hasLength(2));
      expect(requests[0].body, requests[1].body);
      expect(delays, [Duration.zero]);
    });

    test('honors Retry-After on a retryable response', () async {
      final delays = <Duration>[];
      final responses = <http.Response>[
        http.Response('rate limited', 429, headers: {'Retry-After': '1'}),
        http.Response(
          jsonEncode({'accepted': true, 'event_id': 'event-after-rate-limit'}),
          202,
        ),
      ];
      final client = MockClient((_) async => responses.removeAt(0));
      final service = ErrorLoggingService(
        config: _config(
          initialBackoff: const Duration(milliseconds: 100),
          maxBackoff: const Duration(seconds: 2),
        ),
        client: client,
        delay: (duration) async => delays.add(duration),
        jitter: () => 0,
      );

      final result = await service.sendEvent(_event());

      expect(result.status, ErrorLoggingStatus.accepted);
      expect(delays, [const Duration(seconds: 1)]);
    });

    test('does not retry terminal HTTP failures', () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'unauthorized',
              'message': 'invalid key',
              'request_id': 'request-1',
            },
          }),
          401,
        );
      });
      final service = ErrorLoggingService(config: _config(), client: client);

      final result = await service.sendEvent(_event());

      expect(result.status, ErrorLoggingStatus.httpFailure);
      expect(result.statusCode, 401);
      expect(result.errorCode, 'unauthorized');
      expect(result.requestId, 'request-1');
      expect(result.attempts, 1);
      expect(requestCount, 1);
    });

    test(
      'returns non-throwing failures for transport and malformed responses',
      () async {
        final throwingClient = MockClient((_) async {
          throw http.ClientException('offline');
        });
        final throwingService = ErrorLoggingService(
          config: _config(),
          client: throwingClient,
        );
        final transportResult = await throwingService.sendEvent(_event());

        final malformedClient = MockClient(
          (_) async => http.Response('{"accepted":true}', 202),
        );
        final malformedService = ErrorLoggingService(
          config: _config(),
          client: malformedClient,
        );
        final malformedResult = await malformedService.sendEvent(_event());

        expect(transportResult.status, ErrorLoggingStatus.transportFailure);
        expect(malformedResult.status, ErrorLoggingStatus.malformedResponse);
      },
    );

    test('preserves all-rejected batch counts', () async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode({'accepted': 0, 'rejected': 2}), 200),
      );
      final service = ErrorLoggingService(config: _config(), client: client);

      final result = await service.sendBatch([_event('one'), _event('two')]);

      expect(result.status, ErrorLoggingStatus.rejected);
      expect(result.isSuccess, isFalse);
      expect(result.accepted, 0);
      expect(result.rejected, 2);
    });

    test('rejects oversized events before transport', () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response('{}', 202);
      });
      final service = ErrorLoggingService(config: _config(), client: client);
      final event = ErrorLogEvent(
        timestamp: DateTime.utc(2026, 8, 30),
        errorType: 'StateError',
        message: 'x' * (16 * 1024 + 1),
        environment: 'development',
        service: 'daily-pass',
        eventId: 'large-event',
      );

      final result = await service.sendEvent(event);

      expect(result.status, ErrorLoggingStatus.invalidPayload);
      expect(requestCount, 0);
    });

    test('rejects deep, non-JSON, and oversized batch input locally', () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response('{}', 202);
      });
      final service = ErrorLoggingService(config: _config(), client: client);

      Object deepValue = 'leaf';
      for (var index = 0; index < 12; index++) {
        deepValue = {'next': deepValue};
      }
      final deepResult = await service.logError(
        StateError('deep'),
        metadata: {'nested': deepValue},
      );
      final nonJsonResult = await service.logError(
        StateError('unsupported'),
        metadata: {'date': DateTime.utc(2026, 8, 30)},
      );
      final batchResult = await service.sendBatch(
        List<ErrorLogEvent>.generate(101, (index) => _event('event-$index')),
      );

      expect(deepResult.status, ErrorLoggingStatus.invalidPayload);
      expect(nonJsonResult.status, ErrorLoggingStatus.invalidPayload);
      expect(batchResult.status, ErrorLoggingStatus.invalidPayload);
      expect(requestCount, 0);
    });

    test('does not close an injected HTTP client', () {
      final client = _TrackingClient();
      final service = ErrorLoggingService(config: _config(), client: client);

      service.close();

      expect(client.closed, isFalse);
    });
  });
}

ErrorLoggingConfig _config({
  String baseUrl = 'http://localhost:8000',
  String environment = 'development',
  int maxAttempts = 3,
  Duration initialBackoff = const Duration(milliseconds: 200),
  Duration maxBackoff = const Duration(seconds: 2),
}) {
  return ErrorLoggingConfig(
    baseUrl: Uri.parse(baseUrl),
    projectKey: 'pk_test',
    environment: environment,
    maxAttempts: maxAttempts,
    initialBackoff: initialBackoff,
    maxBackoff: maxBackoff,
  );
}

ErrorLogEvent _event([String id = 'event-1']) {
  return ErrorLogEvent(
    timestamp: DateTime.utc(2026, 8, 30, 12),
    errorType: 'StateError',
    message: 'failed',
    environment: 'development',
    service: 'daily-pass',
    eventId: id,
  );
}

class _TrackingClient extends http.BaseClient {
  _TrackingClient([this._responseFactory]);

  final Future<http.Response> Function(http.BaseRequest)? _responseFactory;
  int requestCount = 0;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    final response =
        await _responseFactory?.call(request) ?? http.Response('', 202);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() {
    closed = true;
  }
}
