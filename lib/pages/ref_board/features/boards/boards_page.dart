import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ref_providers.dart';

Future<void> showCreateBoardDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('New board',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Board name',
          hintStyle: TextStyle(color: Colors.white38),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (title != null && title.trim().isNotEmpty) {
    await ref.read(refDaoProvider).createBoard(title.trim());
  }
}

/// Board list, filtered by the shared top-bar search. The canvas editor is the
/// next step; each board already stores a JSON Canvas document.
/// Place it inside an Expanded in home.dart.
class BoardsPage extends ConsumerWidget {
  const BoardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(refBoardsProvider);
    final query = ref.watch(refQueryProvider).toLowerCase();

    return Expanded(
      child: boards.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Text('Could not load boards: $e',
              style: const TextStyle(color: Colors.white54)),
        ),
        data: (all) {
          final list = query.isEmpty
              ? all
              : all.where((b) => b.title.toLowerCase().contains(query)).toList();
          if (list.isEmpty) {
            return Center(
              child: Text(
                query.isEmpty ? 'No boards yet. Use + to create one.' : 'No matches.',
                style: const TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView(children: [
            for (final b in list)
              ListTile(
                leading: const Icon(Icons.dashboard_outlined, color: Colors.white54),
                title: Text(b.title, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Updated ${b.updatedAt.toLocal().toString().split('.').first}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
