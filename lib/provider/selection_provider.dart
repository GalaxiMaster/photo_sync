import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/services/api_service.dart';

class SelectionNotifier extends Notifier<Set<ImmichAsset>> {
  @override
  Set<ImmichAsset> build() => {};

  void toggle(ImmichAsset asset) {
    if (state.contains(asset)) {
      state = { ...state }..remove(asset);
    } else {
      state = { ...state, asset };
    }
  }

  void clear() => state = {};
}

final selectionProvider = NotifierProvider<SelectionNotifier, Set<ImmichAsset>>(
  SelectionNotifier.new,
);

final isSelectionModeProvider = Provider<bool>((ref) {
  return ref.watch(selectionProvider).isNotEmpty;
});