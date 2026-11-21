// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ref_dao.dart';

// ignore_for_file: type=lint
mixin _$RefDaoMixin on DatabaseAccessor<AppDatabase> {
  $RefItemsTable get refItems => attachedDatabase.refItems;
  $RefTagsTable get refTags => attachedDatabase.refTags;
  $RefItemTagsTable get refItemTags => attachedDatabase.refItemTags;
  $RefNotesTable get refNotes => attachedDatabase.refNotes;
  $RefAnnotationsTable get refAnnotations => attachedDatabase.refAnnotations;
  $RefBoardsTable get refBoards => attachedDatabase.refBoards;
  RefDaoManager get managers => RefDaoManager(this);
}

class RefDaoManager {
  final _$RefDaoMixin _db;
  RefDaoManager(this._db);
  $$RefItemsTableTableManager get refItems =>
      $$RefItemsTableTableManager(_db.attachedDatabase, _db.refItems);
  $$RefTagsTableTableManager get refTags =>
      $$RefTagsTableTableManager(_db.attachedDatabase, _db.refTags);
  $$RefItemTagsTableTableManager get refItemTags =>
      $$RefItemTagsTableTableManager(_db.attachedDatabase, _db.refItemTags);
  $$RefNotesTableTableManager get refNotes =>
      $$RefNotesTableTableManager(_db.attachedDatabase, _db.refNotes);
  $$RefAnnotationsTableTableManager get refAnnotations =>
      $$RefAnnotationsTableTableManager(
        _db.attachedDatabase,
        _db.refAnnotations,
      );
  $$RefBoardsTableTableManager get refBoards =>
      $$RefBoardsTableTableManager(_db.attachedDatabase, _db.refBoards);
}
