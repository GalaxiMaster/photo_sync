
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

}

final peopleStoreProvider = AsyncNotifierProvider<PeopleStoreNotifier, List<ImmichPerson>>(
  PeopleStoreNotifier.new,
);
