import 'package:uuid/uuid.dart';
import '../../models/completion.dart';
import '../database/completions_dao.dart';

class CompletionService {
  final CompletionsDao _completionsDao = CompletionsDao();
  final Uuid _uuid = const Uuid();

  /// Toggle completion status for an activity on a specific date
  Future<Completion> toggleCompletion(String activityId, DateTime date) async {
    final existing = await _completionsDao.getByActivityAndDate(activityId, date);
    final now = DateTime.now();
    
    if (existing != null) {
      // Toggle existing completion
      final updated = existing.copyWith(
        isCompleted: !existing.isCompleted,
        completedAt: now,
      );
      await _completionsDao.update(updated);
      return updated;
    } else {
      // Create new completion (marked as complete)
      final completion = Completion(
        id: _uuid.v4(),
        activityId: activityId,
        completedDate: _normalizeDate(date),
        completedAt: now,
        isCompleted: true,
      );
      await _completionsDao.insert(completion);
      return completion;
    }
  }

  /// Mark activity as completed on a specific date
  Future<Completion> markCompleted(String activityId, DateTime date) async {
    final existing = await _completionsDao.getByActivityAndDate(activityId, date);
    
    if (existing != null) {
      if (existing.isCompleted) {
        return existing; // Already completed
      }
      final updated = existing.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );
      await _completionsDao.update(updated);
      return updated;
    } else {
      final completion = Completion(
        id: _uuid.v4(),
        activityId: activityId,
        completedDate: _normalizeDate(date),
        completedAt: DateTime.now(),
        isCompleted: true,
      );
      await _completionsDao.insert(completion);
      return completion;
    }
  }

  /// Mark activity as not completed on a specific date
  Future<Completion> markNotCompleted(String activityId, DateTime date) async {
    final existing = await _completionsDao.getByActivityAndDate(activityId, date);
    
    if (existing != null) {
      final updated = existing.copyWith(
        isCompleted: false,
        completedAt: DateTime.now(),
      );
      await _completionsDao.update(updated);
      return updated;
    } else {
      final completion = Completion(
        id: _uuid.v4(),
        activityId: activityId,
        completedDate: _normalizeDate(date),
        completedAt: DateTime.now(),
        isCompleted: false,
      );
      await _completionsDao.insert(completion);
      return completion;
    }
  }

  /// Get completion status for activity on a specific date
  Future<bool> isCompleted(String activityId, DateTime date) async {
    final completion = await _completionsDao.getByActivityAndDate(
      activityId,
      _normalizeDate(date),
    );
    return completion?.isCompleted ?? false;
  }

  /// Get completion record for activity on a specific date
  Future<Completion?> getCompletion(String activityId, DateTime date) async {
    return await _completionsDao.getByActivityAndDate(
      activityId,
      _normalizeDate(date),
    );
  }

  /// Get all completions for a specific date
  Future<List<Completion>> getCompletionsForDate(DateTime date) async {
    return await _completionsDao.getByDate(_normalizeDate(date));
  }

  /// Get all completions for an activity
  Future<List<Completion>> getCompletionsForActivity(String activityId) async {
    return await _completionsDao.getByActivity(activityId);
  }

  /// Get completion count for an activity
  Future<int> getCompletionCount(String activityId) async {
    final completions = await _completionsDao.getByActivity(activityId);
    return completions.where((c) => c.isCompleted).length;
  }

  /// Delete completion
  Future<void> deleteCompletion(String id) async {
    await _completionsDao.delete(id);
  }

  /// Delete all completions for an activity
  Future<void> deleteCompletionsForActivity(String activityId) async {
    await _completionsDao.deleteByActivity(activityId);
  }

  /// Delete all completions
  Future<void> deleteAllCompletions() async {
    await _completionsDao.deleteAll();
  }

  /// Normalize date to midnight (remove time component)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
