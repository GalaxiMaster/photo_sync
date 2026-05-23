
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';

class PeopleStoreNotifier extends AsyncNotifier<List<ImmichPerson>> {
  ImmichService get _service => ref.read(immichServiceProvider);
  
  @override
  Future<List<ImmichPerson>> build() {
    return _service.getPeople();
  }
  Future<ImmichPerson?> getPersonById(String id) async {
    final people = state.hasValue
        ? state.value!
        : await future;

    return people.firstWhereOrNull((person) => person.id == id);
  }

}

final peopleStoreProvider = AsyncNotifierProvider<PeopleStoreNotifier, List<ImmichPerson>>(
  PeopleStoreNotifier.new,
);

final personByIdProvider = FutureProvider.family<ImmichPerson?, String>((ref, id) async {
  final people = await ref.watch(peopleStoreProvider.future);
  return people.firstWhereOrNull((p) => p.id == id);
});

final assetFacesProvider = FutureProvider.family<List<AssetFace>, String>((ref, assetId) async {
  return ref.read(immichServiceProvider).getFaces(assetId: assetId);
});