import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/Side_Panels/photo_info_panel.dart';
import 'package:photo_sync/models/app_settings_models.dart';
import 'package:photo_sync/models/immich_models.dart';
import '../../../provider/ref_providers.dart';
import 'guide_painter.dart';

const _kPanelColor = Color(0xFF1A1A1A);
const _kLabel = TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600);

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      isDense: true,
      filled: true,
      fillColor: _kPanelColor,
      border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
    );

class ItemPage extends ConsumerStatefulWidget {
  const ItemPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends ConsumerState<ItemPage> {
  final _noteCtl = TextEditingController();
  final _tagCtl = TextEditingController();
  Timer? _saveTimer;
  bool _noteLoaded = false;
  bool _noteDirty = false;
  Guide _guide = Guide.none;

  @override
  void initState() {
    super.initState();
    // Fill the note field once from the DB, then let the user own it.
    ref.listenManual(
      refNoteProvider(widget.id),
      (_, next) {
        if (!_noteLoaded && next.hasValue) {
          _noteCtl.text = next.value?.markdown ?? '';
          _noteLoaded = true;
        }
      },
      fireImmediately: true,
    );
  }

  void _onNoteChanged(String v) {
    _noteDirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _flushNote);
  }

  Future<void> _flushNote() async {
    if (!_noteDirty) return;
    _noteDirty = false;
    await ref.read(refDaoProvider ).saveNote(widget.id, _noteCtl.text);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_noteDirty) {
      ref.read(refDaoProvider ).saveNote(widget.id, _noteCtl.text);
    }
    _noteCtl.dispose();
    _tagCtl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kPanelColor,
        title: const Text('Delete this item?',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text('It will be removed from your reference library.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(refDaoProvider ).softDeleteItem(widget.id);
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(refItemProvider(widget.id));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(item.value?.title ?? 'Reference',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300)),
        actions: [
          if (item.value?.kind == 'image')
            PopupMenuButton<Guide>(
              tooltip: 'Composition guide',
              icon: const Icon(Icons.grid_on),
              initialValue: _guide,
              color: _kPanelColor,
              onSelected: (g) => setState(() => _guide = g),
              itemBuilder: (_) => [
                for (final g in Guide.values)
                  PopupMenuItem(
                    value: g,
                    child: Text(g.label, style: const TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: item.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Text('Could not load item: $e', style: const TextStyle(color: Colors.white54)),
        ),
        data: (it) {
          if (it == null || it.deletedAt != null) {
            return const Center(
              child: Text('This item no longer exists.',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return LayoutBuilder(builder: (context, c) {
            final viewer = _Viewer(item: it, guide: _guide);
            if (c.maxWidth >= 900) {
              return Row(children: [
                Expanded(child: viewer),
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _panel(it),
                  ),
                ),
              ]);
            }
            return ListView(children: [
              SizedBox(height: c.maxHeight * 0.55, child: viewer),
              Padding(padding: const EdgeInsets.all(16), child: _panel(it)),
            ]);
          });
        },
      ),
    );
  }

  Widget _panel(RefItem it) {
    final tags = ref.watch(refItemTagsProvider(widget.id)).value ?? const <RefTag>[];
    final db = ref.read(refDaoProvider);
    return SizedBox(width: 400, height: 1000, child: InfoPanel(asset: it.toImageAsset(), functions: (close: (){}, addFace: null, onFaceHover: null)));
    // return Column(
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: [
    //     if (it.sourceUrl != null) ...[
    //       SelectableText(it.sourceUrl!,
    //           style: const TextStyle(color: Colors.white70, fontSize: 13)),
    //       const SizedBox(height: 12),
    //     ],
    //     if (it.kind == 'text' && it.bodyText != null) ...[
    //       SelectableText(it.bodyText!,
    //           style: const TextStyle(color: Colors.white, fontSize: 15)),
    //       const SizedBox(height: 12),
    //     ],
    //     const Text('Tags', style: _kLabel),
    //     const SizedBox(height: 8),
    //     Wrap(spacing: 6, runSpacing: 6, children: [
    //       for (final t in tags)
    //         InputChip(
    //           label: Text(t.name),
    //           labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
    //           backgroundColor: const Color(0xFF2B2B2B),
    //           deleteIconColor: Colors.white54,
    //           side: BorderSide.none,
    //           onDeleted: () => db.removeTag(widget.id, t.id),
    //         ),
    //     ]),
    //     const SizedBox(height: 8),
    //     TextField(
    //       controller: _tagCtl,
    //       style: const TextStyle(color: Colors.white),
    //       decoration: _dec('Add a tag and press Enter'),
    //       onSubmitted: (v) async {
    //         await db.addTag(widget.id, v);
    //         _tagCtl.clear();
    //       },
    //     ),
    //     const SizedBox(height: 20),
    //     const Text('Notes', style: _kLabel),
    //     const SizedBox(height: 8),
    //     TextField(
    //       controller: _noteCtl,
    //       minLines: 5,
    //       maxLines: 14,
    //       style: const TextStyle(color: Colors.white),
    //       onChanged: _onNoteChanged,
    //       decoration: _dec('Why you saved this, what to study…'),
    //     ),
    //     const SizedBox(height: 20),
    //     Text(
    //       [
    //         if (it.width != null && it.height != null) '${it.width} × ${it.height}',
    //         'Added ${it.createdAt.toLocal().toString().split(' ').first}',
    //         if (it.syncState == 'local_only') 'Not synced yet',
    //       ].join('   '),
    //       style: const TextStyle(color: Colors.white38, fontSize: 12),
    //     ),
    //   ],
    // );
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
    final ratio = (item.width != null && item.height != null && item.height! > 0)
        ? item.width! / item.height!
        : 4 / 3;

    // AspectRatio keeps the guide overlay exactly on the image bounds.
    return InteractiveViewer(
      maxScale: 8,
      child: Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(fit: StackFit.expand, children: [
            Image.file(
              blobs.originalFile(item.blobHash!),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Text('This image format can’t be previewed here.',
                    style: TextStyle(color: Colors.white54)),
              ),
            ),
            IgnorePointer(child: CustomPaint(painter: GuidePainter(guide))),
          ]),
        ),
      ),
    );
  }
}
