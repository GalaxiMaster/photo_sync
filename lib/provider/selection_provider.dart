import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';

class SelectionNotifier extends Notifier<Set<ImageAsset>> {
  @override
  Set<ImageAsset> build() => {};

  void toggle(ImageAsset asset) {
    if (state.contains(asset)) {
      state = { ...state }..remove(asset);
    } else {
      state = { ...state, asset };
    }
  }

  void clear() => state = {};
}

final selectionProvider = NotifierProvider<SelectionNotifier, Set<ImageAsset>>(
  SelectionNotifier.new,
);

final isSelectionModeProvider = Provider<bool>((ref) {
  return ref.watch(selectionProvider).isNotEmpty;
});