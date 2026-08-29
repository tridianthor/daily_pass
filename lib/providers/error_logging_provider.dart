import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/services/error_logging_service.dart';

/// Build-time configuration for the p0inter log and error reporter.
final errorLoggingConfigProvider = Provider<ErrorLoggingConfig>((ref) {
  return ErrorLoggingConfig.fromEnvironment();
});

/// HTTP client owned by the application provider container.
///
/// Keeping the client at application scope avoids creating an unclosed client
/// every time a screen reports an event. Tests can override this provider with
/// a deterministic client.
final errorLoggingClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Shared, best-effort log and error reporting service.
final errorLoggingServiceProvider = Provider<ErrorLoggingService>((ref) {
  final service = ErrorLoggingService(
    config: ref.watch(errorLoggingConfigProvider),
    client: ref.watch(errorLoggingClientProvider),
  );
  ref.onDispose(service.close);
  return service;
});
