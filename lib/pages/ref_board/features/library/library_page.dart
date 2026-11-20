import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/pages/ref_board/core/ref_providers.dart';
import 'package:photo_sync/pages/ref_board/features/library/item_grid.dart';

/// Reference library. Search comes from the shared top bar (refQueryProvider),
/// so there is no separate search page. Place it inside an Expanded in home.dart.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(refItemsProvider);
    final searching = ref.watch(refQueryProvider).isNotEmpty;

    final Widget body = Expanded(
      child: items.when(
        skipLoadingOnReload: true, // keep the grid on screen while a search re-runs
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Text('Could not load library: $e',
              style: const TextStyle(color: Colors.white54)),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  searching
                      ? 'No matches.'
                      : 'Nothing here yet. Drop photos onto the window or use +.',
                  style: const TextStyle(color: Colors.white54),
                ),
              )
            : RefItemGrid(items: list),
      ),
    );

    if (!_isDesktop) return body;
    return DropTarget(
      onDragDone: (detail) async {
        final files = detail.files.map((f) => File(f.path));
        final n = await ref.read(refCaptureServiceProvider).addImageFiles(files);
        if (n > 0) showSuccessSnackbar('Added $n photo${n == 1 ? '' : 's'}');
      },
      child: body,
    );
  }
}
