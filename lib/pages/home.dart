import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/delete_confirmation.dart';
import 'package:photo_sync/Widgets/search_popup.dart';
import 'package:photo_sync/Widgets/side_panels.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/pages/explore.dart';
import 'package:photo_sync/pages/gallary_screen.dart';
import 'package:photo_sync/provider/body_provider.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import '../provider/gallary_provider.dart';

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<MainApp> {
  final double iconSize = 22;
  final deleteKey = GlobalKey();
  final sideBarKey = GlobalKey();

  final sidebar = SidebarOverlay();
  late final SideBarContent sideBarContent;

  final TextEditingController queryController = TextEditingController();

  SearchOptions? currentSearch;

  static final _bodies = <AppBody, Widget>{
    AppBody.gallery:     const GalleryScreen(),
    AppBody.explore:  const ExplorePage(),
  };
  
  @override
  void initState() {
    super.initState();
    sideBarContent = SideBarContent(key: sideBarKey, overlayController: sidebar);
  }

  @override
  Widget build(BuildContext context) {
    final inSelectionMode = ref.watch(isSelectionModeProvider);
    final selection = ref.watch(selectionProvider);
    final current = ref.watch(appBodyProvider);

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
                  IconButton(
                    onPressed: (){
                      sidebar.show(context, sideBarContent);
                    }, 
                    icon: Icon(Icons.menu)
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
                                width: 800,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => ref.read(selectionProvider.notifier).clear(),
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
                                          final int totalBytes = selection.fold(0, (sum, asset) {
                                            final size = asset.exifInfo['fileSizeInByte'] ?? 0;
                                            return sum + (size as int);
                                          });
                                          final bool? confirm = await DeletePopups.delete(
                                            itemCount: selection.length, 
                                            spaceSaved: totalBytes/pow(1024, 2),
                                            context: context, 
                                            anchorKey: deleteKey,
                                            sources: selection.expand((asset) => asset.imageSources).toSet(),
                                            isTrashed: selection.every((a) => a.isTrashed ?? false)
                                          );
                                          if (confirm ?? false) {
                                            ref.read(galleryProvider.notifier).deleteAssets(
                                              selection,
                                              isTrashed: selection.every((a) => a.isTrashed ?? false),
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
                                ),
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
                                      final SearchOptions searchOptions = SearchOptions(query: value.trim(), searchType: SearchType.context);
                                      
                                      ref.read(galleryProvider.notifier).searchFromOptions(searchOptions);
                                      currentSearch = searchOptions;
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final SearchOptions? searchOptions = await showSearchOptionsDialog(context, initialSettings: currentSearch, localSearch: ref.read(galleryProvider.notifier).isLocal);
                                    if (searchOptions != null) {
                                      ref.read(galleryProvider.notifier).searchFromOptions(searchOptions);
                                      queryController.text = searchOptions.query;
                                      currentSearch = searchOptions;
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
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => ref.read(galleryProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
          ),
           _bodies[current]!,
        ],
      ),
    );
  }
}