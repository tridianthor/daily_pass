import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_toast/interactive_toast.dart';
import 'app.dart';
import 'core/services/app_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppNotificationService().initialize();
  runApp(
    AppBanner(
      controller: AppBannerController(),
      child: const ProviderScope(
        child: DailyPassApp(),
      ),
    ),
  );
}
