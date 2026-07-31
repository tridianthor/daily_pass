import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_strings.dart';
import 'home_mobile.dart';
import 'home_desktop.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          // Offline badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 14, color: colorScheme.onSecondaryContainer),
                const SizedBox(width: 4),
                Text(
                  AppStrings.offline,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return const HomeMobileLayout();
          }
          return const HomeDesktopLayout();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
