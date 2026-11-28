import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/provider/body_provider.dart';

class SelectionNotifier extends Notifier<Set<String>> {
  SelectionNotifier(this.pageId);
  final AppBody pageId;

  @override
  Set<String> build() => {};

  void toggle(String asset) {
    if (state.contains(asset)) {
      state = { ...state }..remove(asset);
    } else {
      state = { ...state, asset };
    }
  }

  void clear() => state = {};
}

final selectionProvider = NotifierProvider.family<SelectionNotifier, Set<String>, AppBody>(
  SelectionNotifier.new,
);

final isSelectionModeProvider = Provider.family<bool, AppBody>((ref, pageId) {
  return ref.watch(selectionProvider(pageId)).isNotEmpty;
});
