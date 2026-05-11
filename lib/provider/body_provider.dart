// main_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppBody { gallery, explore }

class AppBodyNotifier extends Notifier<AppBody> {
  @override
  AppBody build() => AppBody.gallery;

  void switchTo(AppBody body) => state = body;
}

final appBodyProvider = NotifierProvider<AppBodyNotifier, AppBody>(
  AppBodyNotifier.new,
);