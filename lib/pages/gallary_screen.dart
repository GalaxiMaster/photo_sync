import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/delete_confirmation.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/pages/full_screen_view.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import 'package:photo_sync/services/api_service.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final _scrollController = ScrollController();
  final double iconSize = 22;
  final deleteKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 500) {
      ref.read(galleryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(galleryProvider);
    final inSelectionMode = ref.watch(isSelectionModeProvider);
    final selection = ref.watch(selectionProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SizedBox(
            height: 65,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gallery',
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 20, 
                      fontWeight: FontWeight.w300
                    ),
                  ),
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
                                          final bool? confirm = await showDeleteConfirmationPopup(selection.length, totalBytes/pow(1024, 2),context, deleteKey);
                                          if (confirm ?? false) {
                                            ref.read(galleryProvider.notifier).deleteAssets(selection.map((element) => element.id).toList());
                                            if (context.mounted) {
                                              showSuccessSnackbar(context, 'Selected assets deleted successfully');
                                            }
                                          }
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          showErrorSnackbar(context, 'Failed to delete selected assets. Please try again:\n$e');
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
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Search...',
                                      hintStyle: TextStyle(color: Colors.white70),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    onFieldSubmitted: (value) {
                                      // if (value.trim().isEmpty) return;
                                      ref.read(galleryProvider.notifier).smartSearch(value.trim());
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
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
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => ref.read(galleryProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: galleryState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.white54, size: 48),
                    const SizedBox(height: 12),
                    Text(err.toString(),
                        style: const TextStyle(color: Colors.white54)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(galleryProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (assets) => _Grid(
                assets: assets,
                scrollController: _scrollController,
                hasMore: ref.read(galleryProvider.notifier).hasMore,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<GalleryItem> assets;
  final ScrollController scrollController;
  final bool hasMore;

  const _Grid({
    required this.assets,
    required this.scrollController,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        if (index >= assets.length) {
          return const _LoadingTile();
        }
        return _Tile(asset: assets[index]);
      },
    );
  }
}


class _Tile extends ConsumerStatefulWidget {
  final GalleryItem asset;
  const _Tile({required this.asset});

  @override
  ConsumerState<_Tile> createState() => _TileState();
}

class _TileState extends ConsumerState<_Tile> {
  final ValueNotifier<bool> _isHovered = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    final all = switch (widget.asset) {
      SingleAsset a => [a.asset],
      StackedAssets a => [a.primary, ...a.children],
    };
    final isSelected = ref.watch(
      selectionProvider.select((set) => set.contains(widget.asset.leadAsset)),
    );
    final inSelectionMode = ref.watch(isSelectionModeProvider);

    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: GestureDetector(
        onTap: () => inSelectionMode 
            ? toggleElementSelection(all) 
            : _showFullscreen(context),
        onLongPress: () => toggleElementSelection(all),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CachedNetworkImage(
                  imageUrl: widget.asset.thumbnailUrl(),
                  httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isHovered,
              builder: (context, hovered, child) {
                if (hovered) {
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: MediaQuery.of(context).size.height / 6,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.6, 1.0], 
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Color(0x99212121),
                          ],
                        ),
                      ),
                    ),
                  );
                }       
                return const SizedBox.shrink();
              }  
            ),

            if (widget.asset is StackedAssets) _buildStackIcon(),
            if (widget.asset.isRaw) _buildRawLabel(),
            
            ValueListenableBuilder<bool>(
              valueListenable: _isHovered,
              builder: (context, hovered, child) {
                if (hovered || inSelectionMode) {
                  return Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () => toggleElementSelection(all),
                      child: Icon(
                        Icons.check_circle,
                        color: isSelected ? Colors.blueAccent : Colors.white38,
                        size: 20,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
  void toggleElementSelection(List<ImmichAsset> all) { 
    for (final ImmichAsset el in all) {
      ref.read(selectionProvider.notifier).toggle(el);
    }
  }
  Widget _buildStackIcon() => const Positioned(
    right: 10, bottom: 10, 
    child: Icon(Icons.filter_none, size: 14, color: Colors.white70)
  );

  Widget _buildRawLabel() => const Positioned(
    top: 10, right: 12.5,
    child: Text('RAW', style: TextStyle(color: Colors.white70, fontSize: 10))
  );

  void _showFullscreen(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullscreenView(asset: widget.asset),
    ));
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1A1A1A),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }
}