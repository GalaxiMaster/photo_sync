import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_settings_models.g.dart';

class SettingsTable extends Table {
  IntColumn get id => integer()();
  TextColumn get theme => text().withDefault(const Constant('system'))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [SettingsTable])
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase.createInBackground(file);
  });
}