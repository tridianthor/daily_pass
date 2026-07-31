import 'package:flutter/material.dart';
import 'package:interactive_toast/interactive_toast.dart';

class NotificationService {
  static void showSuccess(BuildContext context, String message) {
    AppBanner.of(context).show(
      context,
      message,
      config: BannerConfig(
        message: message,
        type: BannerType.success,
        duration: const Duration(seconds: 3),
        showProgress: false,
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    AppBanner.of(context).show(
      context,
      message,
      config: BannerConfig(
        message: message,
        type: BannerType.info,
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    AppBanner.of(context).show(
      context,
      message,
      config: BannerConfig(
        message: message,
        type: BannerType.warning,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    AppBanner.of(context).show(
      context,
      message,
      config: BannerConfig(
        message: message,
        type: BannerType.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showWithUndo(
    BuildContext context,
    String message,
    VoidCallback onUndo,
  ) {
    AppBanner.of(context).show(
      context,
      message,
      config: BannerConfig(
        message: message,
        type: BannerType.info,
        duration: const Duration(seconds: 5),
        showProgress: true,
        action: BannerAction(
          label: 'UNDO',
          onTap: onUndo,
        ),
      ),
    );
  }

  static void showCustom(
    BuildContext context,
    String message, {
    BannerType type = BannerType.info,
    Duration duration = const Duration(seconds: 3),
    bool showProgress = false,
    BannerAction? action,
  }) {
    AppBanner.of(context).show(
      context,
      message,
      config: BannerConfig(
        message: message,
        type: type,
        duration: duration,
        showProgress: showProgress,
        action: action,
      ),
    );
  }
}
