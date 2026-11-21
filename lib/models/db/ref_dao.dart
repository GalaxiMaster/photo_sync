import 'package:drift/drift.dart';
import 'package:photo_sync/models/app_settings_models.dart';
import 'package:uuid/uuid.dart';

import 'ref_tables.dart';

part 'ref_dao.g.dart';

const _uuid = Uuid();

/// All Photo Ref queries. Hangs off the shared AppDatabase as `db.refDao`.
@DriftAccessor(
  tables: [RefItems, RefTags, RefItemTags, RefNotes, RefAnnotations, RefBoards],
)
class RefDao extends DatabaseAccessor<AppDatabase> with _$RefDaoMixin {
  RefDao(super.db);

  // Items
  Stream<List<RefItem>> watchLibrary() => (select(refItems)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Stream<RefItem?> watchItem(String id) =>
      (select(refItems)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<void> insertItem(RefItemsCompanion c) => into(refItems).insert(c);

  Future<void> softDeleteItem(String id) {
    final now = DateTime.now();
    return (update(refItems)..where((t) => t.id.equals(id))).write(
      RefItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // Notes
  Stream<RefNote?> watchNote(String itemId) =>
      (select(refNotes)..where((t) => t.itemId.equals(itemId))).watchSingleOrNull();

  Future<void> saveNote(String itemId, String markdown) =>
      into(refNotes).insertOnConflictUpdate(RefNotesCompanion.insert(
        itemId: itemId,
        markdown: Value(markdown),
        updatedAt: DateTime.now(),
      ));

  // Tags
  Stream<List<RefTag>> watchTags(String itemId) {
    final q = select(refTags).join([
      innerJoin(refItemTags, refItemTags.tagId.equalsExp(refTags.id)),
    ])
      ..where(refItemTags.itemId.equals(itemId))
      ..orderBy([OrderingTerm.asc(refTags.name)]);
    return q.watch().map((rows) => rows.map((r) => r.readTable(refTags)).toList());
  }

  Future<void> addTag(String itemId, String rawName, {String source = 'user'}) async {
    final name = rawName.trim().toLowerCase();
    if (name.isEmpty) return;
    await transaction(() async {
      var tag = await (select(refTags)..where((t) => t.name.equals(name)))
          .getSingleOrNull();
      tag ??= await into(refTags).insertReturning(
        RefTagsCompanion.insert(id: _uuid.v4(), name: name, source: Value(source)),
      );
      await into(refItemTags).insert(
        RefItemTagsCompanion.insert(itemId: itemId, tagId: tag.id),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> removeTag(String itemId, String tagId) => (delete(refItemTags)
        ..where((t) => t.itemId.equals(itemId) & t.tagId.equals(tagId)))
      .go();

  // Keyword search over title, body, notes, tags and URL.
  // Semantic / composition search will merge with this later.
  Stream<List<RefItem>> watchKeywordSearch(String query) {
    final like = '%${query.trim()}%';
    return customSelect(
      'SELECT DISTINCT i.* FROM ref_items i '
      'LEFT JOIN ref_notes n ON n.item_id = i.id '
      'LEFT JOIN ref_item_tags it ON it.item_id = i.id '
      'LEFT JOIN ref_tags t ON t.id = it.tag_id '
      'WHERE i.deleted_at IS NULL AND '
      '(i.title LIKE ? OR i.body_text LIKE ? OR i.source_url LIKE ? '
      'OR n.markdown LIKE ? OR t.name LIKE ?) '
      'ORDER BY i.created_at DESC',
      variables: List.generate(5, (_) => Variable<String>(like)),
      readsFrom: {refItems, refNotes, refItemTags, refTags},
    ).watch().map((rows) => rows.map((r) => refItems.map(r.data)).toList());
  }

  // Boards
  Stream<List<RefBoard>> watchBoards() => (select(refBoards)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  Future<void> createBoard(String title) {
    final now = DateTime.now();
    return into(refBoards).insert(RefBoardsCompanion.insert(
      id: _uuid.v4(),
      title: title,
      createdAt: now,
      updatedAt: now,
    ));
  }
}
