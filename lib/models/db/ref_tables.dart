import 'package:drift/drift.dart';

// Photo Ref tables. They live in the shared AppDatabase (models/app_settings_models.dart),
// all prefixed "Ref" so they can't collide with Immich or settings tables.
// UUID ids + updatedAt + deletedAt tombstones so sync can be added later.

@DataClassName('RefItem')
class RefItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // image | link | text
  TextColumn get title => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get bodyText => text().nullable()();
  TextColumn get blobHash => text().nullable()();
  TextColumn get mime => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get itemType => text().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('local_only'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get sourceTimestampMs => integer().nullable()();
  TextColumn get textContent => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RefTag')
class RefTags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get source => text().withDefault(const Constant('user'))(); // user | ai

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RefItemTag')
class RefItemTags extends Table {
  TextColumn get itemId => text().references(RefItems, #id)();
  TextColumn get tagId => text().references(RefTags, #id)();

  @override
  Set<Column> get primaryKey => {itemId, tagId};
}

@DataClassName('RefNote')
class RefNotes extends Table {
  TextColumn get itemId => text().references(RefItems, #id)();
  TextColumn get markdown => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId};
}

/// Non-destructive overlay shapes in normalised 0-1 coordinates (UI comes later).
@DataClassName('RefAnnotation')
class RefAnnotations extends Table {
  TextColumn get itemId => text().references(RefItems, #id)();
  TextColumn get shapesJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId};
}

/// canvasJson follows the JSON Canvas format (nodes + edges).
@DataClassName('RefBoard')
class RefBoards extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get canvasJson =>
      text().withDefault(const Constant('{"nodes":[],"edges":[]}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
