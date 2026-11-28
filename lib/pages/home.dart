import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/Side_Panels/menu_panel.dart';
import 'package:photo_sync/Widgets/delete_confirmation.dart';
import 'package:photo_sync/Widgets/search_popup.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/pages/explore.dart';
import 'package:photo_sync/pages/gallary_screen.dart';
import 'package:photo_sync/pages/person_page.dart';
import 'package:photo_sync/pages/ref_board/boards/boards_page.dart';
import 'package:photo_sync/pages/ref_board/capture/add_item_sheet.dart';
import 'package:photo_sync/pages/ref_board/library/library_page.dart';
import 'package:photo_sync/pages/tags_screen.dart';
import 'package:photo_sync/provider/body_provider.dart';
import 'package:photo_sync/provider/ref_providers.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import '../provider/gallary_provider.dart';

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  final double iconSize = 22;
  final deleteKey = GlobalKey();
  final sideBarKey = GlobalKey();

  final sidebar = SidebarOverlay();
  late final SideBarContent sideBarContent;

  final TextEditingController queryController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    sideBarContent = SideBarContent(key: sideBarKey, overlayController: sidebar);
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appBodyProvider);
    final inSelectionMode = ref.watch(isSelectionModeProvider(current));
    final selection = ref.watch(selectionProvider(current));
    final previousPage = ref.watch(appBodyProvider.notifier).previousPage;
    final currentSearch = ref.watch(searchOptionsProvider);

    ref.listen(searchOptionsProvider.select((state)=> state.query), (oldQuery, query) => queryController.text = query);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SizedBox(
            height: 65,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  if (previousPage == null)
                    IconButton(
                      onPressed: (){
                        sidebar.show(context, sideBarContent);
                      }, 
                      icon: Icon(Icons.menu)
                    )
                  else
                    IconButton(
                      onPressed: (){
                        ref.read(appBodyProvider.notifier).goToPrevious();
                      }, 
                      icon: Icon(Icons.arrow_back_outlined)
                    ),
                  
                  const Text(
                    'Gallery',
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 20, 
                      fontWeight: FontWeight.w300
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        width: inSelectionMode ? 800 : 400,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: inSelectionMode ? 1.0 : 0.0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              elevation: 12,
                              borderRadius: BorderRadius.circular(24),
                              color: const Color(0xFF1A1A1A),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                child: switch (current.bodyType) {
                                  AppType.pSync => PhotoSyncSelectBar(ref: ref, iconSize: iconSize, selection: selection, deleteKey: deleteKey, selectionScope: current,),
                                  AppType.pRef => PhotoRefSelectBar(ref: ref, iconSize: iconSize, selection: selection, deleteKey: deleteKey, selectionScope: current,),
                                }
                              ),
                            ),
                          ),
                        )
                      ),
                      
                      Align(
                        alignment: Alignment.center,
                        child: Material(
                          elevation: 12,
                          borderRadius: BorderRadius.circular(24),
                          color: const Color.fromARGB(255, 43, 43, 43),
                          child: Container(
                            width: 400,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.search, color: Colors.white),
                                SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: queryController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Search...',
                                      hintStyle: TextStyle(color: Colors.white70),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    onFieldSubmitted: (value) {
                                      final newOptions = ref.read(searchOptionsProvider.notifier).updateQuery(value);
                                      ref.read(galleryBucketProvider.notifier).searchFromOptions(newOptions);
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final SearchOptions? searchOptions = await showSearchOptionsDialog(context, initialSettings: currentSearch, localSearch: ref.read(galleryBucketProvider.notifier).isLocal);
                                    if (searchOptions != null) {
                                      ref.read(galleryBucketProvider.notifier).searchFromOptions(searchOptions);
                                      ref.read(searchOptionsProvider.notifier).updateState(searchOptions);
                                    }
                                  },
                                  visualDensity: VisualDensity.compact,
                                  iconSize: iconSize,
                                  icon: const Icon(Icons.filter_list, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  switch (current) {
                    AppBody.photoRefHome => IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => showAddItemSheet(context, ref),
                    ),
                    AppBody.photoRefBoards => IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => showCreateBoardDialog(context, ref),
                    ),
                    _ => IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () => ref.read(galleryBucketProvider.notifier).refresh(),
                    ),
                  }
                ],
              ),
            ),
          ),            
          switch (current) {
            AppBody.gallery => const GalleryScreen(),
            AppBody.explore => const ExplorePage(),
            AppBody.person => const PersonPage(),
            AppBody.tags => const TagsScreen(),
            AppBody.photoRefHome => LibraryPage(),
            AppBody.photoRefBoards => BoardsPage()
          }
        ],
      ),
    );
  }
}

class PhotoSyncSelectBar extends StatelessWidget {
  const PhotoSyncSelectBar({
    super.key,
    required this.ref,
    required this.iconSize,
    required this.selection,
    required this.deleteKey, 
    required this.selectionScope,
  });

  final WidgetRef ref;
  final double iconSize;
  final Set<String> selection;
  final GlobalKey<State<StatefulWidget>> deleteKey;
  final AppBody selectionScope;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => ref.read(selectionProvider(selectionScope).notifier).clear(),
          padding: EdgeInsets.zero,
          iconSize: iconSize,
          icon: const Icon(Icons.clear, color: Colors.white),
        ),
        Text(
          '${selection.length} selected',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const Spacer(),
        IconButton(onPressed: () {}, visualDensity: VisualDensity.compact, iconSize: iconSize, icon: const Icon(Icons.share_outlined, color: Colors.white)),
        IconButton(onPressed: () {}, visualDensity: VisualDensity.compact, iconSize: iconSize, icon: const Icon(Icons.photo_album_outlined, color: Colors.white)),
        IconButton(onPressed: () {}, visualDensity: VisualDensity.compact, iconSize: iconSize, icon: const Icon(Icons.label_outline, color: Colors.white)),
        IconButton(
          key: deleteKey,
          onPressed: () async {
            try {
              final assets = ref.read(flatGalleryProvider).where((asset) => selection.contains(asset.id)).map((el)=>el.leadAsset).toSet();
              if (assets.isEmpty) throw Exception('Could not find assets to delete');

              final int totalBytes = assets.fold(0, (sum, asset) {
                final size = asset.exifInfo['fileSizeInByte'] ?? 0;
                return sum + (size as int);
              });
              final bool? confirm = await DeletePopups.delete(
                itemCount: assets.length, 
                spaceSaved: totalBytes/pow(1024, 2),
                context: context, 
                anchorKey: deleteKey,
                sources: assets.expand((asset) => asset.imageSources).toSet(),
                isTrashed: assets.every((a) => a.isTrashed ?? false)
              );
              if (confirm ?? false) {
                ref.read(galleryBucketProvider.notifier).deleteAssets(
                  assets,
                  isTrashed: assets.every((a) => a.isTrashed ?? false),
                  deleteFromExternalSource: (assetsFound) => confirmExternalSourceDelete(context, assetsFound)
                );
                if (context.mounted) {
                  showSuccessSnackbar('Successfully sent selected assets to the trash');
                }
              }
            } catch (e) {
              if (!context.mounted) return;
              showErrorSnackbar('Failed to delete selected assets. Please try again:\n$e');
            }
          },
          visualDensity: VisualDensity.compact,
          iconSize: iconSize,
          icon: const Icon(Icons.delete_outline, color: Colors.white),
        ),
      ],
    );
  }
}
class PhotoRefSelectBar extends StatelessWidget {
  const PhotoRefSelectBar({
    super.key,
    required this.ref,
    required this.iconSize,
    required this.selection,
    required this.deleteKey, required this.selectionScope,
  });

  final WidgetRef ref;
  final double iconSize;
  final Set<String> selection;
  final GlobalKey<State<StatefulWidget>> deleteKey;
  final AppBody selectionScope;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => ref.read(selectionProvider(selectionScope).notifier).clear(),
          padding: EdgeInsets.zero,
          iconSize: iconSize,
          icon: const Icon(Icons.clear, color: Colors.white),
        ),
        Text(
          '${selection.length} selected',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const Spacer(),
        IconButton(
          key: deleteKey,
          onPressed: () async {
            try {
              final bool? confirm = await DeletePopups.deleteRefItem(
                itemCount: selection.length, 
                context: context, 
                anchorKey: deleteKey,
              );
              if (confirm ?? false) {
                for (final String itemId in selection) {
                  await ref.read(refDaoProvider).softDeleteItem(itemId);
                }
                ref.read(selectionProvider(selectionScope).notifier).clear();
                if (context.mounted) Navigator.of(context).maybePop();
                if (context.mounted) {
                  showSuccessSnackbar('Successfully deleted items');
                }
              }
            } catch (e) {
              if (!context.mounted) return;
              showErrorSnackbar('Failed to delete selected items. Please try again:\n$e');
            }
          },
          visualDensity: VisualDensity.compact,
          iconSize: iconSize,
          icon: const Icon(Icons.delete_outline, color: Colors.white),
        ),
      ],
    );
  }
}