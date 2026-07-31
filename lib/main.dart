import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_toast/interactive_toast.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBanner(
      controller: AppBannerController(),
      child: ProviderScope(
        child: DailyPassApp(),
      ),
    ),
  );
}
