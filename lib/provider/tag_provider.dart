import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';

class TagStoreNotifier extends AsyncNotifier<List<ImmichTag>> {
  ImmichService get _service => ref.read(immichServiceProvider);

  @override
  Future<List<ImmichTag>> build() => _service.getAllTags();
}

final tagStoreProvider = AsyncNotifierProvider<TagStoreNotifier, List<ImmichTag>>(
  TagStoreNotifier.new,
);