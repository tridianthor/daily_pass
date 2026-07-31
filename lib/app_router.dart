import 'package:go_router/go_router.dart';
import 'features/home/home_screen.dart';
import 'features/activity_form/create_activity_screen.dart';
import 'features/activity_form/edit_activity_screen.dart';
import 'features/settings/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => const CreateActivityScreen(),
    ),
    GoRoute(
      path: '/edit/:id',
      builder: (context, state) => EditActivityScreen(
        activityId: state.pathParameters['id']!,
      ),
    ),
  ],
);
