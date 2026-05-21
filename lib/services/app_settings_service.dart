import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:photo_sync/services/tools.dart';

// Future<void> updateTheme(WidgetRef ref, String theme) async {
//   final db = ref.read(databaseProvider);
//   await db.saveSettings(SettingsTableCompanion(
//     id: const Value(1),
//     theme: Value(theme),
//   ));
//   ref.invalidate(settingsProvider);
// }

Future<Set<String>> setupPhotoCache(Ref ref) async {
  Directory? dir = await getLocalPhotoDirectory();

  final downloadedPhotos = dir
      .listSync()
      .whereType<File>()
      .map((f) => p.basename(f.path))
      .toSet();

  return downloadedPhotos;
}