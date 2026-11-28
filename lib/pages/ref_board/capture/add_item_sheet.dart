import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/pages/ref_board/insta_frame_capture/capture_screen.dart';
import 'package:photo_sync/pages/ref_board/insta_frame_capture/frame_saver.dart';

import '../../../provider/ref_providers.dart';

Future<void> showAddItemSheet(BuildContext context, WidgetRef ref) {
  final capture = ref.read(refCaptureServiceProvider);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SheetTile(
          icon: Icons.add_photo_alternate_outlined,
          label: 'Photos',
          onTap: () async { // todo add sheet that prevents clicking while the file dialog is up
            Navigator.pop(sheetContext);
            final result = await FilePicker.pickFiles(
                type: FileType.image);
            final files = result
                .where((f) => f.path != null)
                .map((f) => File(f.path!));
            final n = await capture.addImageFiles(files);
            if (n > 0) showSuccessSnackbar('Added $n photo${n == 1 ? '' : 's'}');
          },
        ),
        _SheetTile(
          icon: Icons.link,
          label: 'Link',
          onTap: () async {
            Navigator.pop(sheetContext);
            final url = await _ask(context, 'Add link', 'https://…');
            if (url != null) {
              if (url.contains('instagram.com') && context.mounted) {
                final saved = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CaptureScreen(
                      url: url.trim(),
                      onSave: ref.read(frameSaverProvider).save,
                    ),
                  ),
                );
                if (saved != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $saved frames')));
                }
              }
              await capture.addLink(url);
            }
          },
        ),
        _SheetTile(
          icon: Icons.notes,
          label: 'Note',
          onTap: () async {
            Navigator.pop(sheetContext);
            final text =
                await _ask(context, 'Add note', 'Write something…', multiline: true);
            if (text != null) await capture.addText(text);
          },
        ),
      ]),
    ),
  );
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: onTap,
      );
}

Future<String?> _ask(BuildContext context, String title, String hint,
    {bool multiline = false}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          minLines: multiline ? 4 : 1,
          maxLines: multiline ? 10 : 1,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
          onSubmitted: multiline ? null : (v) => Navigator.pop(ctx, v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
