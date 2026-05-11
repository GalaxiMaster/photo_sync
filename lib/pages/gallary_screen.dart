import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/delete_confirmation.dart';
import 'package:photo_sync/Widgets/search_popup.dart';
import 'package:photo_sync/Widgets/side_panels.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/pages/full_screen_view.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:photo_sync/services/exiftool.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final _scrollController = ScrollController();
  final double iconSize = 22;
  final deleteKey = GlobalKey();
  final sideBarKey = GlobalKey();

  final sidebar = SidebarOverlay();
  late final SideBarContent sideBarContent;

  final TextEditingController queryController = TextEditingController();

  SearchOptions? currentSearch;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    sideBarContent = SideBarContent(key: sideBarKey, overlayController: sidebar);
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
                                            ref.read(galleryProvider.notifier).deleteAssets(selection);
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
      cacheExtent: 200,
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
                child: !widget.asset.isLocal ? CachedNetworkImage(
                  imageUrl: widget.asset.thumbnailUrl(),
                  httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(color: Color(0xFF1A1A1A)),
                ) : LocalAssetTile(asset: widget.asset.leadAsset),
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



class LocalAssetTile extends StatelessWidget {
  final ImmichAsset asset;
  final bool preview;
  final void Function(ImmichAsset asset)? onTap;

  const LocalAssetTile({super.key, required this.asset, this.onTap, this.preview = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap?.call(asset),
      child: asset.isVideo
          ? _VideoTile(asset: asset)
          : LocalImage(asset: asset, preview: preview),
    );
  }
}

class LocalImage extends ConsumerStatefulWidget {
  final ImmichAsset asset;
  final bool preview;
  const LocalImage({super.key, required this.asset, this.preview = true});

  @override
  ConsumerState<LocalImage> createState() => _ImageTileState();
}

class _ImageTileState extends ConsumerState<LocalImage> {
  Future<Uint8List?>? future;
  @override
  @override
  void initState() {
    super.initState();
    _refreshFuture();
  }
  @override
  void didUpdateWidget(covariant LocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.asset.localPath != widget.asset.localPath) {
      _refreshFuture();
    }
  }
  void _refreshFuture() {
    future = widget.asset.isRaw
        ? getEmbeddedJpeg(widget.asset.localPath!)
        : null;
  }
  @override
  Widget build(BuildContext context) {
    if (widget.asset.isRaw) {
      return FutureBuilder<Uint8List?>(
        future: future,
        key: ValueKey(widget.asset.originalUrl),
        builder: (context, snapshot) {
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            debugPrint('Image decode failed: ${snapshot.error}');
            return const Icon(Icons.broken_image);
          }
      
          return RotatedBox(
            quarterTurns: _exifRotation(widget.asset.exifInfo),
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              key: ValueKey(widget.asset.originalUrl),
              cacheWidth: widget.preview ? 400 : widget.asset.exifInfo['exifImageWidth'],
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image decode failed: $error');
                return const Icon(Icons.warning_amber_rounded);
              },
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame == null) return const ColoredBox(color: Colors.black12);
                return child;
              },
            ),
          );
        },
      );
    }

    return RotatedBox(
      quarterTurns: _exifRotation(widget.asset.exifInfo),
      child: Image.file(
        File(widget.asset.localPath!),
        fit: BoxFit.cover,
        cacheWidth: widget.preview ? 200 : null,
        key: ValueKey(widget.asset.originalUrl),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const ColoredBox(color: Color(0xFF1A1A1A));
        },
        errorBuilder: (context, _, _) => const _ErrorTile(),
      ),
    );
  }
}
int _exifRotation(Map exifInfo) {
  final orientation = exifInfo['Orientation']?.toString().toLowerCase() ?? '';
  if (orientation.contains('rotate 90') || orientation.contains('90 cw')) return 1;
  if (orientation.contains('rotate 180') || orientation.contains('180'))   return 2;
  if (orientation.contains('rotate 270') || orientation.contains('90 ccw')) return 3;
  return 0;
}


class _VideoTile extends ConsumerStatefulWidget {
  final ImmichAsset asset;
  const _VideoTile({required this.asset});

  @override
  ConsumerState<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends ConsumerState<_VideoTile> {
  late final Future<Uint8List?> future;

  @override
  void initState() {
    super.initState();
    future = getEmbeddedJpeg(widget.asset.localPath!);
  }
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: FutureBuilder<Uint8List?>(
            future: future,
            key: ValueKey(widget.asset.originalUrl),
            builder: (context, snapshot) {
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                debugPrint('Image decode failed: ${snapshot.error}');
                return const Icon(Icons.broken_image);
              }
          
              return RotatedBox(
                quarterTurns: _exifRotation(widget.asset.exifInfo),
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  key: ValueKey(widget.asset.originalUrl),
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Image decode failed: $error');
                    return const Icon(Icons.warning_amber_rounded);
                  },
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (frame == null) return const ColoredBox(color: Colors.black12);
                    return child;
                  },
                ),
              );
            },
          ),
        ),
        Center(child: Icon(Icons.play_circle, color: Colors.white70, size: 30)),
      ],
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String error;
  const _ErrorTile() : error = 'broken';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(0xFF2A2A2A),
      child: Column(
        children: [
          Icon(Icons.broken_image, color: Colors.white38),
          Text(error),
        ],
      ),
    );
  }
}