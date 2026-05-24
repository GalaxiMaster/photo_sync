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
}

final tagStoreProvider = AsyncNotifierProvider<TagStoreNotifier, List<ImmichTag>>(
  TagStoreNotifier.new,
);