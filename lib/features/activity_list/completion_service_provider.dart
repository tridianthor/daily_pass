import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/completion_service.dart';

final completionServiceProvider = Provider<CompletionService>((ref) {
  return CompletionService();
});
