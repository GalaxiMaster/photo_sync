import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/app_settings_models.dart';
import 'package:photo_sync/pages/gallary_screen.dart';
import 'package:photo_sync/provider/body_provider.dart';
import 'package:photo_sync/provider/selection_provider.dart';

import '../../../provider/ref_providers.dart';
import '../item/item_page.dart';

const double _kTileSpacing = 2.0;
const _kTileColor = Color(0xFF1A1A1A);


class RefItemGrid extends ConsumerStatefulWidget {
  const RefItemGrid({super.key, required this.items});
  final List<RefItem> items;  
  @override
  RefItemGridState createState() => RefItemGridState();
}

class RefItemGridState extends ConsumerState<RefItemGrid> {
  @override
  Widget build(BuildContext context) {
    final selection = ref.read(selectionProvider(AppBody.photoRefHome));

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: _kTileSpacing,
        mainAxisSpacing: _kTileSpacing,
      ),
      itemCount: widget.items.length,
      itemBuilder: (_, i)  {
        final item = widget.items[i];
        return TileShell(
          isSelected: selection.contains(item.id),
          inSelectionMode: selection.isNotEmpty,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ItemPage(id: item.id)),
          ),
          onToggleSelect: (){
            ref.read(selectionProvider(AppBody.photoRefHome).notifier).toggle(item.id);
          },
          child: RefItemTile(key: ValueKey(item.id), item: item)
        );
      }
    );
  }
}

class RefItemTile extends ConsumerWidget {
  const RefItemTile({super.key, required this.item});
  final RefItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget content;
    if (item.kind == 'image' && item.blobHash != null) {
      final blobs = ref.watch(refBlobStoreProvider);
      content = Image.file(
        blobs.thumbFile(item.blobHash!),
        fit: BoxFit.cover,
        cacheWidth: 400,
        frameBuilder: (_, child, frame, wasSync) =>
            wasSync || frame != null ? child : const ColoredBox(color: _kTileColor),
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white38),
        ),
      );
    } else {
      final isLink = item.kind == 'link';
      content = Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isLink ? Icons.link : Icons.notes, size: 18, color: Colors.white54),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                isLink ? (item.title ?? item.sourceUrl ?? '') : (item.bodyText ?? ''),
                overflow: TextOverflow.fade,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            if (isLink && item.sourceUrl != null)
              Text(
                item.sourceUrl!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
      );
    }

    return Material(
      color: _kTileColor,
      child: content,
    );
  }
}
