import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:photo_sync/main.dart';

Timer? _snackbarTimer;

void showErrorSnackbar(String errorMessage) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  
  _snackbarTimer?.cancel();
  messenger.clearSnackBars();

  final controller = messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.red.shade800,
      behavior: SnackBarBehavior.floating,
      width: 900,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      action: SnackBarAction(
        label: 'DISMISS',
        textColor: Colors.white,
        onPressed: () {
          messenger.hideCurrentSnackBar();
        },
      ),
    ),
  );

  // Manually dismiss after 2s to work around Flutter desktop bug
  _snackbarTimer = Timer(const Duration(seconds: 3), () {
    try {
      if (scaffoldMessengerKey.currentState != null) {
        controller.close();
      }
    } catch (_) {} // Ignore if already dismissed
  });
}

void showSuccessSnackbar(String message) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  _snackbarTimer?.cancel();
  messenger.clearSnackBars();

  final controller = messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
      width: 900,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      action: SnackBarAction(
        label: 'DISMISS',
        textColor: Colors.white,
        onPressed: () => messenger.hideCurrentSnackBar(),
      ),
    ),
  );

  _snackbarTimer = Timer(const Duration(seconds: 3), () {
    try {
      if (scaffoldMessengerKey.currentState != null) {
        controller.close();
      }
    } catch (_) {} // Ignore if already dismissed
 });
}
