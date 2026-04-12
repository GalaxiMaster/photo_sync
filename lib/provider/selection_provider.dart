import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String id) {
    if (state.contains(id)) {
      state = { ...state }..remove(id);
    } else {
      state = { ...state, id };
    }
  }

  void clear() => state = {};
}

final selectionProvider = NotifierProvider<SelectionNotifier, Set<String>>(
  SelectionNotifier.new,
);

final isSelectionModeProvider = Provider<bool>((ref) {
  return ref.watch(selectionProvider).isNotEmpty;
});