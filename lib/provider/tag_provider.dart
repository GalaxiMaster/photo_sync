import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';

class TagStoreNotifier extends AsyncNotifier<List<ImmichTag>> {
  ImmichService get _service => ref.read(immichServiceProvider);

  @override
  Future<List<ImmichTag>> build() async {
    final tags = await _service.getAllTags();
    return nestChildren(tags);
  }

  List<ImmichTag> nestChildren(List<ImmichTag> tags) {
    final tagIds = {for (var tag in tags) tag.id};
    final childrenMap = <String, List<ImmichTag>>{};
    final rootTags = <ImmichTag>[];

    for (final tag in tags) {
      if (tag.parentId != null && tagIds.contains(tag.parentId)) {
        childrenMap.putIfAbsent(tag.parentId!, () => []).add(tag);
      } else {
        rootTags.add(tag);
      }
    }

    ImmichTag buildTree(ImmichTag tag) {
      final children = childrenMap[tag.id];
      if (children == null) return tag;
      return tag.copyWith(children: children.map(buildTree).toList());
    }

    return rootTags.map(buildTree).toList();
  }
  void createTag(ImmichTag tag) async{
    final completeTag = await _service.createTag(tag);
    final flat = (state.value ?? []).expand((t) => t.flatten()).toList();
    state = AsyncData(nestChildren([...flat, completeTag]));
  }
  void deleteTag(String tagId) {
    _service.deleteTag(tagId);
    final flat = (state.value ?? []).expand((t) => t.flatten()).toList();
    state = AsyncData(nestChildren(flat.where((t) => t.id != tagId).toList()));
  }
  void updateTag(ImmichTag updatedTag) {
    _service.updateTag(updatedTag);
    final flat = (state.value ?? []).expand((t) => t.flatten()).toList();
    state = AsyncData(nestChildren(flat.map((t) => t.id == updatedTag.id ? updatedTag : t).toList()));
  }

  ImmichTag? getIdFromPath(String path) {
    final flat = (state.value ?? []).expand((t) => t.flatten()).toList();
    for (final t in flat) {
      if (t.value == path) return t;
    }
    return null;
  }
}

final tagStoreProvider = AsyncNotifierProvider<TagStoreNotifier, List<ImmichTag>>(
  TagStoreNotifier.new,
);