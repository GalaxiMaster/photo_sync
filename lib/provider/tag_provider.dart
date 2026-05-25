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
  void addTag(ImmichTag tag) {
    final flat = (state.value ?? []).expand((t) => t.flatten()).toList();
    state = AsyncData(nestChildren([...flat, tag]));
  }
  void removeTag(String tagId) {
    final flat = (state.value ?? []).expand((t) => t.flatten()).toList();
    state = AsyncData(nestChildren(flat.where((t) => t.id != tagId).toList()));
  }
  void updateTag(ImmichTag updatedTag) {
    final flat = (state.value ?? []).expand((t) => t.flatten()).toList();
    state = AsyncData(nestChildren(flat.map((t) => t.id == updatedTag.id ? updatedTag : t).toList()));
  }
}

final tagStoreProvider = AsyncNotifierProvider<TagStoreNotifier, List<ImmichTag>>(
  TagStoreNotifier.new,
);