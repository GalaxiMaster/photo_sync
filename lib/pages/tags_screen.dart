import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/pages/gallary_screen.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/provider/tag_provider.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  ImmichTag? selectedTag;

  @override
  void initState() {
    super.initState();
  }

  void selectTag(ImmichTag? tag) {
    setState(() {
      selectedTag = tag;
    });
    if (tag == null) return;
    ref.read(galleryBucketProvider.notifier).loadCloud(tags: {tag.id});
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagStoreProvider);

    return tagsAsync.when(
      data: (tags) => Expanded(
        child: Row(
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
                    ...tags.map(_tagElement),
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
                        onPressed: () {
                          if (selectedTag?.parentId == null) {
                            selectTag(null);
                            return;
                          }
                          selectTag(tags.expand((t) => t.flatten()).toList().firstWhere((t) => t.id == selectedTag?.parentId, orElse: () => selectedTag!)); // Go up in tree (could just store a flattened list in the storeProvider to avoid expanding every time but probably doesnt matter much)
                        },
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
                                    onPressed: () {
                                      setState(() {
                                        selectedTag = null;
                                      });
                                    },
                                    icon: Icon(Icons.sell, size: 20, color: Colors.white.withValues(alpha: 0.8)),
                                  ),
                                  ...selectedTag != null ? _pathSegment(selectedTag!, tags.expand((t) => t.flatten()).toList()) : [],
                                ],
                              ),
                            )
                          ),
                        ),
                      )
                    ],
                  ),
                  selectedTag != null
                    ? GalleryScreen()
                    : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: Material(
                        color: Color.fromARGB(255, 17, 17, 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Color.fromARGB(255, 15, 24, 39), width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            children: tags.map((tag) {
                              return InkWell(
                                onTap: () => selectTag(tag),
                                hoverColor: Color.fromARGB(255, 34, 44, 79),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    height: 132,
                                    width: 150,
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.local_offer, size: 80, color: tag.color),
                                        Text(
                                          tag.name,
                                          style: TextStyle(fontSize: 14, color: tag.color),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                          ).toList()
                        ),
                        ),
                      ),
                  ),
                ]
              ),
            ),
          ],
        ),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text('Error loading tags: $e'),
    );
  }
  Widget _tagElement(ImmichTag tag, {int indentLevel = 0}) {
    if (tag.children.isEmpty) {
      return _tagBox(tag);
    }
    final Map<String, bool> expanded = {};

    return StatefulBuilder(
      builder: (context, setState) {
        int depth = (selectedTag?.value ?? '').split('/').length;

        bool isExpanded = expanded[tag.id] ?? depth >= (indentLevel + 1) ? true : false;
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _tagBox(tag, isExpanded: isExpanded, onToggle: () => setState(() => expanded[tag.id] = !isExpanded)),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: SizedBox(
                  height: isExpanded ? null : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Column(
                      children: tag.children.map((child) => _tagElement(child, indentLevel: indentLevel + 1)).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tagBox(ImmichTag tag, {int indentLevel = 0, bool isExpanded = false, VoidCallback? onToggle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => selectTag(tag),
        hoverColor: Colors.grey.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            color: selectedTag?.id == tag.id ? tag.color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          width: double.infinity,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: indentLevel * 10),
              if (onToggle != null) ...[
                GestureDetector(
                  onTap: onToggle,
                  child: Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 16)
                ),
                const SizedBox(width: 4),
              ]
              else SizedBox(width: 20), // Placeholder for alignment with toggled items
              Icon(Icons.local_offer, size: 20, color: tag.color),
              const SizedBox(width: 10),
              Text(tag.name, style: TextStyle(fontSize: 14, color: selectedTag?.name == tag.name ? Color.fromARGB(255, 145, 198, 250) : Colors.white.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pathSegment(ImmichTag tag, List<ImmichTag> tags) {
    return [
      if (tag.parentId != null) ..._pathSegment(tags.where((t) => t.id == tag.parentId).first, tags),
      SizedBox(width: 10),
      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white.withValues(alpha: 0.6)),
      SizedBox(width: 10),
      GestureDetector(
        onTap: () {
          if (selectedTag == tag) return;
          selectTag(tag);
        },
        child: MouseRegion(
          cursor: selectedTag == tag ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: Text(
            tag.name,
            style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 164, 210, 255)),
          ),
        ),
      ),
    ];
  }
}