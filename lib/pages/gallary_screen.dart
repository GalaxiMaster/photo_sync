import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/pages/full_screen_view.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:photo_sync/services/exiftool.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});
  @override
  GalleryScreenState createState() => GalleryScreenState();
}

class GalleryScreenState extends ConsumerState<GalleryScreen> {
  final _scrollController = ScrollController();

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

    return Expanded(
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
            if (widget.asset.imageSources.length > 1) _buildExternalSourceLabel(widget.asset.imageSources.last),

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

  Widget _buildExternalSourceLabel(ImageSource source) => Positioned(
    bottom: 10, left: 12.5,
    child: SvgPicture.asset(
      switch (source) {
        ImageSource.local => 'assets/icons/local.svg',
        ImageSource.immich => 'assets/icons/immich.svg',
      },
      width: 15,
      height: 15,
      colorFilter: ColorFilter.mode(Colors.white.withAlpha(200), BlendMode.srcIn),
    )
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