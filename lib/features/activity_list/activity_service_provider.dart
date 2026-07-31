import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/activities_dao.dart';
import '../../core/services/activity_service.dart';
import '../../providers/database_provider.dart';

final activityServiceProvider = Provider<ActivityService>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  final activitiesDao = ActivitiesDao(dbHelper);
  return ActivityService(activitiesDao);
});
