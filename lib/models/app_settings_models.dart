import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_sync/models/db/ref_dao.dart';
import 'package:photo_sync/models/db/ref_paths.dart';
import 'package:photo_sync/models/db/ref_tables.dart';

part 'app_settings_models.g.dart';

class SettingsTable extends Table {
  IntColumn get id => integer()();
  TextColumn get theme => text().withDefault(const Constant('system'))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    SettingsTable,
    // Photo Ref tables (defined in ref_board/core/db/ref_tables.dart)
    RefItems, RefTags, RefItemTags, RefNotes, RefAnnotations, RefBoards,
  ],
  daos: [RefDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<SettingsTableData?> getSettings() => (select(settingsTable)..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<void> saveSettings(SettingsTableCompanion settings) => into(settingsTable).insertOnConflictUpdate(settings);

  // // Cache — basic CRUD
  // Future<List<PhotoCacheTableData>> getAllPhotos() =>
  //     select(photoCacheTable).get();

  // Future<void> upsertPhoto(PhotoCacheTableCompanion photo) =>
  //     into(photoCacheTable).insertOnConflictUpdate(photo);

  // Future<void> upsertPhotos(List<PhotoCacheTableCompanion> photos) =>
  //     batch((b) => b.insertAllOnConflictUpdate(photoCacheTable, photos));

  // Future<void> deletePhoto(String id) =>
  //     (delete(photoCacheTable)..where((t) => t.id.equals(id))).go();

  // Future<void> clearCache() => delete(photoCacheTable).go();
}

/// %LOCALAPPDATA%\PhotoSync\app.db on Windows (see RefPaths for other platforms).
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final paths = await RefPaths.get();
    return kDebugMode // Weird bug where .createInBackground causes the database to take almost a minute to load in debug mode specifically
      ? NativeDatabase(paths.databaseFile)
      : NativeDatabase.createInBackground(paths.databaseFile);
  });
}
