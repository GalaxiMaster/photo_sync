import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/Side_Panels/photo_info_panel.dart';
import 'package:photo_sync/models/app_settings_models.dart';
import '../../../provider/ref_providers.dart';
import 'guide_painter.dart';

const _kPanelColor = Color(0xFF1A1A1A);

class ItemPage extends ConsumerStatefulWidget {
  const ItemPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends ConsumerState<ItemPage> {
  bool _showInfo = false;
  Guide _guide = Guide.none;

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kPanelColor,
        title: const Text(
          'Delete this item?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          'It will be removed from your reference library.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(refDaoProvider).softDeleteItem(widget.id);
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(refItemProvider(widget.id));

    return Scaffold(
      backgroundColor: Colors.black,
      body: item.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Text(
            'Could not load item: $e',
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        data: (it) {
          if (it == null || it.deletedAt != null) {
            return const Center(
              child: Text(
                'This item no longer exists.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, c) {
              final panelWidth = c.maxWidth < 400 ? c.maxWidth : 400.0;
              final infoPanel = InfoPanel.reference(
                item: it,
                onClose: () => setState(() => _showInfo = false),
              );
              final viewer = _viewerWithToolbar(context, it);

              if (c.maxWidth >= 760) {
                return Row(
                  children: [
                    Expanded(child: viewer),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      width: _showInfo ? 400 : 0,
                      decoration: const BoxDecoration(),
                      clipBehavior: Clip.hardEdge,
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: 400,
                        maxWidth: 400,
                        child: infoPanel,
                      ),
                    ),
                  ],
                );
              }

              return Stack(
                children: [
                  Positioned.fill(child: viewer),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    top: 0,
                    bottom: 0,
                    right: _showInfo ? 0 : -panelWidth,
                    width: panelWidth,
                    child: ClipRect(child: infoPanel),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _viewerWithToolbar(BuildContext context, RefItem it) {
    return Stack(
      children: [
        Positioned.fill(
          child: _Viewer(item: it, guide: _guide),
        ),
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    it.title ?? 'Reference',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
                if (it.kind == 'image')
                  PopupMenuButton<Guide>(
                    tooltip: 'Composition guide',
                    icon: const Icon(Icons.grid_on, color: Colors.white),
                    initialValue: _guide,
                    color: _kPanelColor,
                    onSelected: (guide) => setState(() => _guide = guide),
                    itemBuilder: (_) => [
                      for (final guide in Guide.values)
                        PopupMenuItem(
                          value: guide,
                          child: Text(
                            guide.label,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                IconButton(
                  tooltip: 'Info',
                  icon: Icon(
                    _showInfo ? Icons.info : Icons.info_outline,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _showInfo = !_showInfo),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: _delete,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class _Viewer extends ConsumerWidget {
  const _Viewer({required this.item, required this.guide});
  final RefItem item;
  final Guide guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.kind != 'image' || item.blobHash == null) {
      return Center(
        child: Icon(
          item.kind == 'link' ? Icons.link : Icons.notes,
          size: 64,
          color: Colors.white24,
        ),
      );
    }
    final blobs = ref.watch(refBlobStoreProvider);
    final ratio =
        (item.width != null && item.height != null && item.height! > 0)
        ? item.width! / item.height!
        : 4 / 3;

    // AspectRatio keeps the guide overlay exactly on the image bounds.
    return InteractiveViewer(
      maxScale: 8,
      child: Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                blobs.originalFile(item.blobHash!),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'This image format can’t be previewed here.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              IgnorePointer(child: CustomPaint(painter: GuidePainter(guide))),
            ],
          ),
        ),
      ),
    );
  }
}
