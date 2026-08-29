import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

const int _maxRequestBytes = 1024 * 1024;
const int _maxMessageBytes = 16 * 1024;
const int _maxStackTraceBytes = 256 * 1024;
const int _maxMetadataBytes = 128 * 1024;
const int _maxBreadcrumbs = 100;
const int _maxTags = 50;
const int _maxTagKeyBytes = 64;
const int _maxTagValueBytes = 256;
const int _maxBatchSize = 100;
const int _maxJsonDepth = 10;

const Set<String> _sensitiveKeys = {
  'password',
  'passwd',
  'secret',
  'token',
  'accesstoken',
  'refreshtoken',
  'authorization',
  'auth',
  'cookie',
  'setcookie',
  'apikey',
  'privatekey',
  'clientsecret',
  'session',
  'sessionid',
  'creditcard',
  'cardnumber',
  'cvv',
};

/// A p0inter event that can be serialized and sent by [ErrorLoggingService].
///
/// The transport only depends on this small contract so error and log events
/// can share validation, batching, retries, and response handling without
/// allowing either event shape to accidentally include the other's fields.
abstract interface class LoggingEvent {
  /// The application-generated correlation identifier for this event.
  String get eventId;

  /// Returns the allow-listed p0inter payload.
  Map<String, dynamic> toJson();

  /// Returns a local validation error, or `null` when the payload is usable.
  String? get validationError;
}

/// Severity accepted by p0inter log events.
enum LogLevel { trace, debug, info, warning, error, critical }

/// Configuration for [ErrorLoggingService].
///
/// The explicit constructor is useful for dependency injection and tests. For
/// a build-time configuration, use [ErrorLoggingConfig.fromEnvironment] and
/// provide `ERROR_LOGGING_*` values with `--dart-define`.
/// For example, development and production can select different origins:
///
/// ```text
/// flutter run --dart-define=ERROR_LOGGING_ENABLED=true \\
///   --dart-define=ERROR_LOGGING_ENVIRONMENT=development \\
///   --dart-define=ERROR_LOGGING_BASE_URL=http://10.0.2.2:8000
/// flutter build apk --release --dart-define=ERROR_LOGGING_ENABLED=true \\
///   --dart-define=ERROR_LOGGING_ENVIRONMENT=production \\
///   --dart-define=ERROR_LOGGING_BASE_URL=https://logs.example.com
/// ```
///
/// A Dart define is not secret storage: values can be recovered from a shipped
/// mobile or desktop binary. Production clients should use a narrowly scoped,
/// ingestion-only key or send events through a trusted application relay.
class ErrorLoggingConfig {
  const ErrorLoggingConfig({
    required this.baseUrl,
    required this.projectKey,
    required this.environment,
    this.service = 'daily-pass',
    this.release,
    this.platform,
    this.enabled = true,
    this.timeout = const Duration(seconds: 2),
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 200),
    this.maxBackoff = const Duration(seconds: 2),
  });

  /// Reads `ERROR_LOGGING_*` compile-time defines.
  ///
  /// Logging is disabled by default. Set `ERROR_LOGGING_ENABLED=true` in a
  /// build that should report logs or errors.
  factory ErrorLoggingConfig.fromEnvironment() {
    const enabledValue = String.fromEnvironment(
      'ERROR_LOGGING_ENABLED',
      defaultValue: 'false',
    );
    const baseUrlValue = String.fromEnvironment(
      'ERROR_LOGGING_BASE_URL',
      defaultValue: '',
    );
    const projectKeyValue = String.fromEnvironment(
      'ERROR_LOGGING_PROJECT_KEY',
      defaultValue: '',
    );
    const environmentValue = String.fromEnvironment(
      'ERROR_LOGGING_ENVIRONMENT',
      defaultValue: 'development',
    );
    const releaseValue = String.fromEnvironment(
      'ERROR_LOGGING_RELEASE',
      defaultValue: '',
    );
    const platformValue = String.fromEnvironment(
      'ERROR_LOGGING_PLATFORM',
      defaultValue: '',
    );

    Uri baseUrl;
    try {
      baseUrl = Uri.parse(baseUrlValue);
    } on FormatException {
      // Keep configuration construction non-throwing. The service will return
      // an invalid-configuration result when an enabled URL cannot be used.
      baseUrl = Uri.parse('');
    }

    return ErrorLoggingConfig(
      baseUrl: baseUrl,
      projectKey: projectKeyValue,
      environment: environmentValue,
      release: releaseValue.isEmpty ? null : releaseValue,
      platform: platformValue.isEmpty ? null : platformValue,
      enabled: enabledValue.toLowerCase() == 'true',
    );
  }

  final Uri baseUrl;
  final String projectKey;
  final String environment;
  final String service;
  final String? release;
  final String? platform;
  final bool enabled;
  final Duration timeout;
  final int maxAttempts;
  final Duration initialBackoff;
  final Duration maxBackoff;

  /// Returns a validation error, or `null` when this configuration is usable.
  String? get validationError {
    if (!enabled) {
      return null;
    }
    if (baseUrl.scheme != 'http' && baseUrl.scheme != 'https') {
      return 'baseUrl must use http or https';
    }
    if (baseUrl.host.isEmpty) {
      return 'baseUrl must include a host';
    }
    if (baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        baseUrl.userInfo.isNotEmpty) {
      return 'baseUrl must not include credentials, query, or fragment data';
    }
    if (projectKey.trim().isEmpty) {
      return 'projectKey is required when logging is enabled';
    }
    if (environment.trim().isEmpty) {
      return 'environment is required when logging is enabled';
    }
    if (environment.trim().toLowerCase() == 'production' &&
        baseUrl.scheme != 'https') {
      return 'production logging requires an https baseUrl';
    }
    if (service.trim().isEmpty) {
      return 'service must not be empty';
    }
    if (_utf8Length(service) > 256 || _utf8Length(environment) > 256) {
      return 'service and environment must be at most 256 UTF-8 bytes';
    }
    if (release != null && _utf8Length(release!) > 256) {
      return 'release must be at most 256 UTF-8 bytes';
    }
    if (platform != null && _utf8Length(platform!) > 256) {
      return 'platform must be at most 256 UTF-8 bytes';
    }
    if (timeout <= Duration.zero) {
      return 'timeout must be positive';
    }
    if (maxAttempts < 1 || maxAttempts > 5) {
      return 'maxAttempts must be between 1 and 5';
    }
    if (initialBackoff < Duration.zero || maxBackoff < Duration.zero) {
      return 'backoff durations must not be negative';
    }
    if (maxBackoff < initialBackoff) {
      return 'maxBackoff must be at least initialBackoff';
    }
    return null;
  }

  /// Resolves an ingestion endpoint while preserving any path prefix in the
  /// configured origin.
  Uri endpoint(String path) {
    final prefix = baseUrl.path.replaceFirst(RegExp(r'/+$'), '');
    return baseUrl.replace(path: '$prefix/api/v1/$path');
  }
}

/// A breadcrumb accepted by the p0inter error-event contract.
class ErrorBreadcrumb {
  ErrorBreadcrumb({
    required DateTime timestamp,
    required this.category,
    required this.message,
    Map<String, dynamic>? metadata,
  }) : timestamp = timestamp.toUtc(),
       metadata = Map.unmodifiable(_redactMap(metadata));

  final DateTime timestamp;
  final String category;
  final String message;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'message': message,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

/// A serialized error event ready for p0inter ingestion.
class ErrorLogEvent implements LoggingEvent {
  factory ErrorLogEvent({
    required DateTime timestamp,
    required String errorType,
    required String message,
    String? stackTrace,
    String? fingerprint,
    required String environment,
    required String service,
    String? release,
    String? platform,
    Map<String, String>? tags,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? user,
    Map<String, dynamic>? request,
    Map<String, dynamic>? context,
    List<ErrorBreadcrumb>? breadcrumbs,
    String? eventId,
  }) {
    final resolvedEventId =
        eventId == null || eventId.isEmpty ? const Uuid().v4() : eventId;
    final eventMetadata = <String, dynamic>{
      if (metadata != null) ...metadata,
      'event_id': resolvedEventId,
    };

    return ErrorLogEvent._(
      timestamp: timestamp,
      errorType: errorType,
      message: message,
      stackTrace: stackTrace,
      fingerprint: fingerprint,
      environment: environment,
      service: service,
      release: release,
      platform: platform,
      tags: _redactStringMap(tags),
      metadata: _redactMap(eventMetadata),
      user: _redactMap(user),
      request: _redactMap(request),
      context: _redactMap(context),
      breadcrumbs: breadcrumbs ?? const <ErrorBreadcrumb>[],
      eventId: resolvedEventId,
    );
  }

  /// Builds an event from a caught exception and optional stack trace.
  factory ErrorLogEvent.fromError({
    required Object error,
    StackTrace? stackTrace,
    required ErrorLoggingConfig config,
    DateTime? timestamp,
    String? fingerprint,
    Map<String, String>? tags,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? user,
    Map<String, dynamic>? request,
    Map<String, dynamic>? context,
    List<ErrorBreadcrumb>? breadcrumbs,
  }) {
    return ErrorLogEvent(
      timestamp: timestamp ?? DateTime.now(),
      errorType: error.runtimeType.toString(),
      message: _safeString(error),
      stackTrace: stackTrace == null ? null : _safeString(stackTrace),
      fingerprint: fingerprint,
      environment: config.environment,
      service: config.service,
      release: config.release,
      platform: config.platform,
      tags: tags,
      metadata: metadata,
      user: user,
      request: request,
      context: context,
      breadcrumbs: breadcrumbs,
    );
  }

  ErrorLogEvent._({
    required DateTime timestamp,
    required this.errorType,
    required this.message,
    required this.stackTrace,
    required this.fingerprint,
    required this.environment,
    required this.service,
    required this.release,
    required this.platform,
    required Map<String, String> tags,
    required Map<String, dynamic> metadata,
    required Map<String, dynamic> user,
    required Map<String, dynamic> request,
    required Map<String, dynamic> context,
    required List<ErrorBreadcrumb> breadcrumbs,
    required this.eventId,
  }) : timestamp = timestamp.toUtc(),
       tags = Map.unmodifiable(tags),
       metadata = Map.unmodifiable(metadata),
       user = Map.unmodifiable(user),
       request = Map.unmodifiable(request),
       context = Map.unmodifiable(context),
       breadcrumbs = List.unmodifiable(breadcrumbs);

  final DateTime timestamp;
  final String errorType;
  final String message;
  final String? stackTrace;
  final String? fingerprint;
  final String environment;
  final String service;
  final String? release;
  final String? platform;
  final Map<String, String> tags;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> user;
  final Map<String, dynamic> request;
  final Map<String, dynamic> context;
  final List<ErrorBreadcrumb> breadcrumbs;
  @override
  final String eventId;

  @override
  Map<String, dynamic> toJson() {
    final error = <String, dynamic>{
      'type': errorType,
      'message': message,
      if (stackTrace != null && stackTrace!.isNotEmpty)
        'stack_trace': stackTrace,
      if (fingerprint != null && fingerprint!.isNotEmpty)
        'fingerprint': fingerprint,
    };

    return {
      'type': 'error',
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      if (environment.isNotEmpty) 'environment': environment,
      if (release != null && release!.isNotEmpty) 'release': release,
      if (service.isNotEmpty) 'service': service,
      if (platform != null && platform!.isNotEmpty) 'platform': platform,
      if (tags.isNotEmpty) 'tags': tags,
      'metadata': metadata,
      if (user.isNotEmpty) 'user': user,
      if (request.isNotEmpty) 'request': request,
      if (context.isNotEmpty) 'context': context,
      if (breadcrumbs.isNotEmpty)
        'breadcrumbs':
            breadcrumbs.map((breadcrumb) => breadcrumb.toJson()).toList(),
    };
  }

  /// Returns a local validation error, or `null` when the event is API-safe.
  @override
  String? get validationError {
    try {
      if (errorType.isEmpty || _utf8Length(errorType) > 256) {
        return 'error.type must be between 1 and 256 UTF-8 bytes';
      }
      if (_utf8Length(message) > _maxMessageBytes) {
        return 'error.message exceeds the 16 KiB limit';
      }
      if (stackTrace != null &&
          _utf8Length(stackTrace!) > _maxStackTraceBytes) {
        return 'error.stack_trace exceeds the 256 KiB limit';
      }
      if (fingerprint != null && _utf8Length(fingerprint!) > 256) {
        return 'error.fingerprint exceeds the 256-byte limit';
      }
      if (tags.length > _maxTags) {
        return 'event contains more than 50 tags';
      }
      for (final entry in tags.entries) {
        if (_utf8Length(entry.key) > _maxTagKeyBytes ||
            _utf8Length(entry.value) > _maxTagValueBytes) {
          return 'tag key or value exceeds its UTF-8 byte limit';
        }
      }
      if (breadcrumbs.length > _maxBreadcrumbs) {
        return 'event contains more than 100 breadcrumbs';
      }
      if (_jsonBytes(metadata) > _maxMetadataBytes) {
        return 'metadata exceeds the 128 KiB limit';
      }
      final payload = toJson();
      if (_jsonDepth(payload) > _maxJsonDepth) {
        return 'event exceeds the maximum JSON nesting depth';
      }
      if (_jsonBytes(payload) > _maxRequestBytes) {
        return 'event exceeds the 1 MiB request limit';
      }
      // _jsonBytes also verifies that all values are JSON encodable.
      _jsonBytes(payload);
      return null;
    } on FormatException {
      return 'event contains unsupported or invalid JSON data';
    } on JsonUnsupportedObjectError {
      return 'event contains unsupported or invalid JSON data';
    } catch (_) {
      return 'event validation failed';
    }
  }
}

/// A serialized log-only event ready for p0inter ingestion.
///
/// Unlike [ErrorLogEvent], this event has no nested `error`, `context`, or
/// `breadcrumbs` fields. Its required [level] and [message] are sent using
/// p0inter's `type: log` payload shape, so it is stored as a log rather than
/// being grouped into an issue.
class LogEvent implements LoggingEvent {
  factory LogEvent({
    required DateTime timestamp,
    required LogLevel level,
    required String message,
    required String environment,
    required String service,
    String? release,
    String? logger,
    String? platform,
    String? traceId,
    Map<String, String>? tags,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? user,
    Map<String, dynamic>? request,
    String? eventId,
  }) {
    final resolvedEventId =
        eventId == null || eventId.isEmpty ? const Uuid().v4() : eventId;
    final eventMetadata = <String, dynamic>{
      if (metadata != null) ...metadata,
      'event_id': resolvedEventId,
    };

    return LogEvent._(
      timestamp: timestamp,
      level: level,
      message: message,
      environment: environment,
      service: service,
      release: release,
      logger: logger,
      platform: platform,
      traceId: traceId,
      tags: _redactStringMap(tags),
      metadata: _redactMap(eventMetadata),
      user: _redactMap(user),
      request: _redactMap(request),
      eventId: resolvedEventId,
    );
  }

  /// Builds a log event using the dimensions from [config].
  factory LogEvent.fromMessage({
    required String message,
    required LogLevel level,
    required ErrorLoggingConfig config,
    DateTime? timestamp,
    String? logger,
    String? traceId,
    Map<String, String>? tags,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? user,
    Map<String, dynamic>? request,
  }) {
    return LogEvent(
      timestamp: timestamp ?? DateTime.now(),
      level: level,
      message: message,
      environment: config.environment,
      service: config.service,
      release: config.release,
      logger: logger,
      platform: config.platform,
      traceId: traceId,
      tags: tags,
      metadata: metadata,
      user: user,
      request: request,
    );
  }

  LogEvent._({
    required DateTime timestamp,
    required this.level,
    required this.message,
    required this.environment,
    required this.service,
    required this.release,
    required this.logger,
    required this.platform,
    required this.traceId,
    required Map<String, String> tags,
    required Map<String, dynamic> metadata,
    required Map<String, dynamic> user,
    required Map<String, dynamic> request,
    required this.eventId,
  }) : timestamp = timestamp.toUtc(),
       tags = Map.unmodifiable(tags),
       metadata = Map.unmodifiable(metadata),
       user = Map.unmodifiable(user),
       request = Map.unmodifiable(request);

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String environment;
  final String service;
  final String? release;
  final String? logger;
  final String? platform;
  final String? traceId;
  final Map<String, String> tags;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> user;
  final Map<String, dynamic> request;

  @override
  final String eventId;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'log',
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      if (environment.isNotEmpty) 'environment': environment,
      if (release != null && release!.isNotEmpty) 'release': release,
      if (service.isNotEmpty) 'service': service,
      if (logger != null && logger!.isNotEmpty) 'logger': logger,
      if (platform != null && platform!.isNotEmpty) 'platform': platform,
      if (tags.isNotEmpty) 'tags': tags,
      'metadata': metadata,
      if (user.isNotEmpty) 'user': user,
      if (request.isNotEmpty) 'request': request,
      if (traceId != null && traceId!.isNotEmpty) 'trace_id': traceId,
    };
  }

  /// Returns a local validation error, or `null` when the event is API-safe.
  @override
  String? get validationError {
    try {
      if (message.trim().isEmpty) {
        return 'message must not be empty';
      }
      if (_utf8Length(message) > _maxMessageBytes) {
        return 'message exceeds the 16 KiB limit';
      }
      final dimensions = <String, String?>{
        'environment': environment,
        'release': release,
        'service': service,
        'logger': logger,
        'platform': platform,
        'trace_id': traceId,
      };
      for (final entry in dimensions.entries) {
        if (entry.value != null && _utf8Length(entry.value!) > 256) {
          return '${entry.key} exceeds the 256-byte limit';
        }
      }
      if (tags.length > _maxTags) {
        return 'event contains more than 50 tags';
      }
      for (final entry in tags.entries) {
        if (_utf8Length(entry.key) > _maxTagKeyBytes ||
            _utf8Length(entry.value) > _maxTagValueBytes) {
          return 'tag key or value exceeds its UTF-8 byte limit';
        }
      }
      if (_jsonBytes(metadata) > _maxMetadataBytes) {
        return 'metadata exceeds the 128 KiB limit';
      }
      final payload = toJson();
      if (_jsonDepth(payload) > _maxJsonDepth) {
        return 'event exceeds the maximum JSON nesting depth';
      }
      if (_jsonBytes(payload) > _maxRequestBytes) {
        return 'event exceeds the 1 MiB request limit';
      }
      // _jsonBytes also verifies that all values are JSON encodable.
      _jsonBytes(payload);
      return null;
    } on FormatException {
      return 'event contains unsupported or invalid JSON data';
    } on JsonUnsupportedObjectError {
      return 'event contains unsupported or invalid JSON data';
    } catch (_) {
      return 'event validation failed';
    }
  }
}

enum ErrorLoggingStatus {
  accepted,
  partialSuccess,
  rejected,
  skipped,
  invalidPayload,
  httpFailure,
  transportFailure,
  malformedResponse,
}

/// Outcome of a single or batch logging request.
class ErrorLoggingResult {
  const ErrorLoggingResult._({
    required this.status,
    this.statusCode,
    this.eventId,
    this.accepted,
    this.rejected,
    this.errorCode,
    this.errorMessage,
    this.requestId,
    required this.attempts,
  });

  factory ErrorLoggingResult.accepted({
    required String eventId,
    required int attempts,
  }) {
    return ErrorLoggingResult._(
      status: ErrorLoggingStatus.accepted,
      statusCode: 202,
      eventId: eventId,
      accepted: 1,
      attempts: attempts,
    );
  }

  factory ErrorLoggingResult.batch({
    required int accepted,
    required int rejected,
    required int attempts,
  }) {
    final status =
        accepted == 0 && rejected > 0
            ? ErrorLoggingStatus.rejected
            : rejected > 0
            ? ErrorLoggingStatus.partialSuccess
            : ErrorLoggingStatus.accepted;
    return ErrorLoggingResult._(
      status: status,
      statusCode: 200,
      accepted: accepted,
      rejected: rejected,
      attempts: attempts,
    );
  }

  factory ErrorLoggingResult.skipped() {
    return const ErrorLoggingResult._(
      status: ErrorLoggingStatus.skipped,
      attempts: 0,
    );
  }

  factory ErrorLoggingResult.invalid(String message) {
    return ErrorLoggingResult._(
      status: ErrorLoggingStatus.invalidPayload,
      errorMessage: message,
      attempts: 0,
    );
  }

  factory ErrorLoggingResult.httpFailure({
    required int statusCode,
    String? errorCode,
    String? errorMessage,
    String? requestId,
    required int attempts,
  }) {
    return ErrorLoggingResult._(
      status: ErrorLoggingStatus.httpFailure,
      statusCode: statusCode,
      errorCode: errorCode,
      errorMessage: errorMessage,
      requestId: requestId,
      attempts: attempts,
    );
  }

  factory ErrorLoggingResult.transportFailure({
    required String message,
    required int attempts,
  }) {
    return ErrorLoggingResult._(
      status: ErrorLoggingStatus.transportFailure,
      errorMessage: message,
      attempts: attempts,
    );
  }

  factory ErrorLoggingResult.malformedResponse({required int attempts}) {
    return ErrorLoggingResult._(
      status: ErrorLoggingStatus.malformedResponse,
      attempts: attempts,
    );
  }

  final ErrorLoggingStatus status;
  final int? statusCode;
  final String? eventId;
  final int? accepted;
  final int? rejected;
  final String? errorCode;
  final String? errorMessage;
  final String? requestId;
  final int attempts;

  bool get isSuccess =>
      status == ErrorLoggingStatus.accepted ||
      status == ErrorLoggingStatus.partialSuccess;

  @override
  String toString() {
    return 'ErrorLoggingResult(status: $status, statusCode: $statusCode, '
        'accepted: $accepted, rejected: $rejected, attempts: $attempts)';
  }
}

/// Best-effort client for p0inter log and error ingestion.
///
/// The service never throws reporting failures into application code. Inject
/// [client], [clock], [delay], and [jitter] to make transport and retry
/// behavior deterministic in tests. An injected client remains owned by the
/// caller and is not closed by [close].
class ErrorLoggingService {
  ErrorLoggingService({
    required this.config,
    http.Client? client,
    DateTime Function()? clock,
    Future<void> Function(Duration)? delay,
    double Function()? jitter,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _clock = clock ?? DateTime.now,
       _delay = delay ?? ((duration) => Future<void>.delayed(duration)),
       _jitter = jitter ?? _randomJitter;

  final ErrorLoggingConfig config;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _delay;
  final double Function() _jitter;
  bool _closed = false;

  /// Reports one caught exception as an error event.
  Future<ErrorLoggingResult> logError(
    Object error, {
    StackTrace? stackTrace,
    String? fingerprint,
    Map<String, String>? tags,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? user,
    Map<String, dynamic>? request,
    Map<String, dynamic>? context,
    List<ErrorBreadcrumb>? breadcrumbs,
  }) async {
    final ready = _ready();
    if (ready != null) {
      return ready;
    }

    try {
      final event = ErrorLogEvent.fromError(
        error: error,
        stackTrace: stackTrace,
        config: config,
        timestamp: _clock(),
        fingerprint: fingerprint,
        tags: tags,
        metadata: metadata,
        user: user,
        request: request,
        context: context,
        breadcrumbs: breadcrumbs,
      );
      return await sendEvent(event);
    } catch (_) {
      return ErrorLoggingResult.invalid('event construction failed');
    }
  }

  /// Reports one structured log message without creating a p0inter issue.
  ///
  /// The message is sent as `type: log` with the requested [level]. Reporting
  /// failures are returned as [ErrorLoggingResult] values and never thrown
  /// into the caller's application flow.
  ///
  /// ```dart
  /// await service.logMessage(
  ///   'activity creation started',
  ///   level: LogLevel.info,
  ///   logger: 'activity-form',
  /// );
  /// ```
  Future<ErrorLoggingResult> logMessage(
    String message, {
    LogLevel level = LogLevel.info,
    String? logger,
    String? traceId,
    Map<String, String>? tags,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? user,
    Map<String, dynamic>? request,
  }) async {
    final ready = _ready();
    if (ready != null) {
      return ready;
    }

    try {
      final event = LogEvent.fromMessage(
        message: message,
        level: level,
        config: config,
        timestamp: _clock(),
        logger: logger,
        traceId: traceId,
        tags: tags,
        metadata: metadata,
        user: user,
        request: request,
      );
      return await sendEvent(event);
    } catch (_) {
      return ErrorLoggingResult.invalid('event construction failed');
    }
  }

  /// Sends one already-constructed log or error event.
  Future<ErrorLoggingResult> sendEvent(LoggingEvent event) async {
    final ready = _ready();
    if (ready != null) {
      return ready;
    }

    final validationError = event.validationError;
    if (validationError != null) {
      return ErrorLoggingResult.invalid(validationError);
    }

    late final String body;
    try {
      body = jsonEncode(event.toJson());
    } catch (_) {
      return ErrorLoggingResult.invalid('event contains invalid JSON data');
    }
    if (_utf8Length(body) > _maxRequestBytes) {
      return ErrorLoggingResult.invalid(
        'event exceeds the 1 MiB request limit',
      );
    }

    final outcome = await _post(config.endpoint('events'), body);
    if (outcome.response == null) {
      return ErrorLoggingResult.transportFailure(
        message: outcome.failureMessage ?? 'request failed',
        attempts: outcome.attempts,
      );
    }
    return _parseSingleResponse(outcome.response!, outcome.attempts);
  }

  /// Sends up to 100 already-constructed log or error events in one request.
  Future<ErrorLoggingResult> sendBatch(Iterable<LoggingEvent> events) async {
    final ready = _ready();
    if (ready != null) {
      return ready;
    }

    final eventList = List<LoggingEvent>.of(events);
    if (eventList.isEmpty) {
      return ErrorLoggingResult.invalid(
        'batch must contain at least one event',
      );
    }
    if (eventList.length > _maxBatchSize) {
      return ErrorLoggingResult.invalid(
        'batch cannot contain more than 100 events',
      );
    }

    for (final event in eventList) {
      final validationError = event.validationError;
      if (validationError != null) {
        return ErrorLoggingResult.invalid(validationError);
      }
    }

    late final String body;
    try {
      body = jsonEncode({
        'events': eventList.map((event) => event.toJson()).toList(),
      });
    } catch (_) {
      return ErrorLoggingResult.invalid('batch contains invalid JSON data');
    }
    if (_utf8Length(body) > _maxRequestBytes) {
      return ErrorLoggingResult.invalid(
        'batch exceeds the 1 MiB request limit',
      );
    }

    final outcome = await _post(config.endpoint('events/batch'), body);
    if (outcome.response == null) {
      return ErrorLoggingResult.transportFailure(
        message: outcome.failureMessage ?? 'request failed',
        attempts: outcome.attempts,
      );
    }
    return _parseBatchResponse(
      outcome.response!,
      outcome.attempts,
      eventList.length,
    );
  }

  /// Closes an internally-created HTTP client. Injected clients remain owned
  /// by their caller.
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    if (_ownsClient) {
      _client.close();
    }
  }

  ErrorLoggingResult? _ready() {
    if (!config.enabled) {
      return ErrorLoggingResult.skipped();
    }
    final configurationError = config.validationError;
    if (configurationError != null) {
      return ErrorLoggingResult.invalid(configurationError);
    }
    if (_closed) {
      return ErrorLoggingResult.transportFailure(
        message: 'logging service is closed',
        attempts: 0,
      );
    }
    return null;
  }

  Future<_HttpOutcome> _post(Uri endpoint, String body) async {
    var attempts = 1;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Project-Key': config.projectKey,
    };
    try {
      var response = await _client
          .post(endpoint, headers: headers, body: body)
          .timeout(config.timeout);

      while (_isRetryable(response.statusCode) &&
          attempts < config.maxAttempts) {
        await _delay(_retryDelay(response, attempts));
        attempts++;
        response = await _client
            .post(endpoint, headers: headers, body: body)
            .timeout(config.timeout);
      }
      return _HttpOutcome.response(response, attempts);
    } catch (_) {
      return _HttpOutcome.failure(attempts, 'transport failure');
    }
  }

  bool _isRetryable(int statusCode) => statusCode == 429 || statusCode == 500;

  Duration _retryDelay(http.Response response, int attempt) {
    final retryAfter = _header(response, 'retry-after');
    final retryAfterSeconds = int.tryParse(retryAfter ?? '');
    if (retryAfterSeconds != null && retryAfterSeconds >= 0) {
      return _capDuration(Duration(seconds: retryAfterSeconds));
    }

    final multiplier = 1 << (attempt - 1);
    final base = _capDuration(config.initialBackoff * multiplier);
    final jitter = _jitter().clamp(0.0, 1.0);
    return _capDuration(
      Duration(milliseconds: (base.inMilliseconds * (1 + jitter)).round()),
    );
  }

  Duration _capDuration(Duration duration) {
    if (duration > config.maxBackoff) {
      return config.maxBackoff;
    }
    return duration;
  }

  ErrorLoggingResult _parseSingleResponse(
    http.Response response,
    int attempts,
  ) {
    if (response.statusCode != 202) {
      return _parseHttpFailure(response, attempts);
    }
    final body = _decodeObject(response.body);
    final eventId = body?['event_id'];
    if (body == null ||
        body['accepted'] != true ||
        eventId is! String ||
        eventId.isEmpty) {
      return ErrorLoggingResult.malformedResponse(attempts: attempts);
    }
    return ErrorLoggingResult.accepted(eventId: eventId, attempts: attempts);
  }

  ErrorLoggingResult _parseBatchResponse(
    http.Response response,
    int attempts,
    int eventCount,
  ) {
    if (response.statusCode != 200) {
      return _parseHttpFailure(response, attempts);
    }
    final body = _decodeObject(response.body);
    final accepted = body?['accepted'];
    final rejected = body?['rejected'];
    if (accepted is! int || rejected is! int || accepted < 0 || rejected < 0) {
      return ErrorLoggingResult.malformedResponse(attempts: attempts);
    }
    if (accepted + rejected != eventCount) {
      return ErrorLoggingResult.malformedResponse(attempts: attempts);
    }
    return ErrorLoggingResult.batch(
      accepted: accepted,
      rejected: rejected,
      attempts: attempts,
    );
  }

  ErrorLoggingResult _parseHttpFailure(http.Response response, int attempts) {
    final body = _decodeObject(response.body);
    final error = body?['error'];
    final errorMap = error is Map ? error : null;
    final rawMessage = errorMap?['message'];
    final rawCode = errorMap?['code'];
    final rawRequestId = errorMap?['request_id'];
    final requestId =
        rawRequestId is String && rawRequestId.isNotEmpty
            ? rawRequestId
            : _header(response, 'x-request-id');
    final message =
        rawMessage is String ? _safeResponseMessage(rawMessage) : null;
    return ErrorLoggingResult.httpFailure(
      statusCode: response.statusCode,
      errorCode: rawCode is String ? rawCode : null,
      errorMessage: message,
      requestId: requestId,
      attempts: attempts,
    );
  }

  Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String? _header(http.Response response, String name) {
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  String _safeResponseMessage(String message) {
    if (config.projectKey.isEmpty) {
      return message;
    }
    return message.replaceAll(config.projectKey, '[REDACTED]');
  }
}

class _HttpOutcome {
  const _HttpOutcome.response(this.response, this.attempts)
    : failureMessage = null;

  const _HttpOutcome.failure(this.attempts, this.failureMessage)
    : response = null;

  final http.Response? response;
  final int attempts;
  final String? failureMessage;
}

Map<String, dynamic> _redactMap(Map<String, dynamic>? input) {
  if (input == null) {
    return <String, dynamic>{};
  }
  final value = _redactValue(input, 0);
  if (value is! Map) {
    throw const FormatException('structured value must be an object');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, String> _redactStringMap(Map<String, String>? input) {
  if (input == null) {
    return <String, String>{};
  }
  final result = <String, String>{};
  for (final entry in input.entries) {
    result[entry.key] = _isSensitiveKey(entry.key) ? '[REDACTED]' : entry.value;
  }
  return result;
}

Object? _redactValue(Object? value, int depth) {
  if (depth > _maxJsonDepth) {
    throw const FormatException('structured value is too deeply nested');
  }
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('structured object keys must be strings');
      }
      final key = entry.key as String;
      result[key] =
          _isSensitiveKey(key)
              ? '[REDACTED]'
              : _redactValue(entry.value, depth + 1);
    }
    return Map.unmodifiable(result);
  }
  if (value is List) {
    return List.unmodifiable(
      value.map((item) => _redactValue(item, depth + 1)),
    );
  }
  throw const FormatException('structured value is not JSON encodable');
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return _sensitiveKeys.any(normalized.contains);
}

int _utf8Length(String value) => utf8.encode(value).length;

int _jsonBytes(Object? value) => utf8.encode(jsonEncode(value)).length;

int _jsonDepth(Object? value) {
  if (value is Map) {
    var childDepth = 0;
    for (final entry in value.entries) {
      final candidate = _jsonDepth(entry.value);
      if (candidate > childDepth) {
        childDepth = candidate;
      }
    }
    return childDepth + 1;
  }
  if (value is List) {
    var childDepth = 0;
    for (final item in value) {
      final candidate = _jsonDepth(item);
      if (candidate > childDepth) {
        childDepth = candidate;
      }
    }
    return childDepth + 1;
  }
  return 0;
}

String _safeString(Object value) {
  try {
    return value.toString();
  } catch (_) {
    return '<unprintable ${value.runtimeType}>';
  }
}

double _randomJitter() => math.Random().nextDouble();
