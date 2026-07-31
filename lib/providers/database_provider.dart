import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database_helper.dart';

/// Provider for the database singleton instance.
/// Uses the singleton pattern from DatabaseHelper.
final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});
