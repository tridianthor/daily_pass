import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/completion.dart';
import '../core/database/completions_dao.dart';

/// Completions for a specific date, indexed by activity ID.
/// Returns a Map{activityId, Completion} for efficient lookup.
final completionsForDateProvider = FutureProvider.family<Map<String, Completion>, DateTime>((ref, date) async {
  final completionsDao = CompletionsDao();
  final completions = await completionsDao.getByDate(date);
  
  // Index by activityId for O(1) lookup
  return {for (var c in completions) c.activityId: c};
});

/// Completion status for a specific activity on a specific date.
/// Returns the Completion if it exists, null otherwise.
final completionStatusProvider = FutureProvider.family<Completion?, (String, DateTime)>((ref, params) async {
  final (activityId, date) = params;
  final completionsDao = CompletionsDao();
  return completionsDao.getByActivityAndDate(activityId, date);
});

/// Convenience provider to check if an activity is completed on a given date.
final isActivityCompletedProvider = FutureProvider.family<bool, (String, DateTime)>((ref, params) async {
  final completion = await ref.watch(completionStatusProvider(params).future);
  return completion?.isCompleted ?? false;
});

/// All completions for a specific activity.
final completionsForActivityProvider = FutureProvider.family<List<Completion>, String>((ref, activityId) async {
  final completionsDao = CompletionsDao();
  return completionsDao.getByActivity(activityId);
});

/// Total completion count provider.
final completionCountProvider = FutureProvider<int>((ref) async {
  final completionsDao = CompletionsDao();
  return completionsDao.count();
});
