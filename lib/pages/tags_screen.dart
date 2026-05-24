import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/tag_provider.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagStoreProvider);

    return tagsAsync.when(
      data: (tags) => Row(
        spacing: 10,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explorer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...tags.map(_tagBox),
                ]
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Tags',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 0.1, color: Colors.grey.withValues(alpha: 0.2)),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(255, 17, 17, 17),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Color.fromARGB(255, 15, 24, 39), width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(Icons.sell, size: 20, color: Colors.white.withValues(alpha: 0.8)),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white.withValues(alpha: 0.6)),
                                SizedBox(width: 10),
                                Text(
                                  'Tags',
                                  style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
                                ),
                              ],
                            ),
                          )
                        ),
                      ),
                    )
                  ],
                )
              ]
            ),
          ),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text('Error loading tags: $e'),
    );
  }
  Widget _tagBox(ImmichTag tag) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        hoverColor: Colors.grey.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            color: tag.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          width: double.infinity,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.local_offer, size: 20, color: tag.color),
              const SizedBox(width: 10),
              Text(tag.name),
            ],
          ),
        ),
      ),
    );
  }
}
