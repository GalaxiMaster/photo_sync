import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
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
    if (pos.pixels >= pos.maxScrollExtent - 400) {
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
                  if (inSelectionMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Center(
                      child: Material(
                        elevation: 12,
                        borderRadius: BorderRadius.circular(24),
                        color: const Color(0xFF1A1A1A),
                        child: Container(
                          width: 800,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              IconButton(
                                onPressed: (){},
                                visualDensity: VisualDensity.compact,
                                iconSize: iconSize,
                                icon: Icon(Icons.share_outlined)
                              ),
                              IconButton(
                                onPressed: (){},
                                visualDensity: VisualDensity.compact,
                                iconSize: iconSize,
                                icon: Icon(Icons.photo_album_outlined)
                              ),
                              IconButton(
                                onPressed: (){},
                                visualDensity: VisualDensity.compact,
                                iconSize: iconSize,
                                icon: Icon(Icons.label_outline)
                              ),
                              IconButton(
                                onPressed: () async {
                                  try {
                                    ref.read(galleryProvider.notifier).deleteAssets(selection.toList());
                                    if (context.mounted) {
                                      showSuccessSnackbar(context, 'Selected assets deleted successfully');
                                    }
                                  } catch (e) {
                                    showErrorSnackbar(context, 'Failed to delete selected assets. Please try again:\n$e');
                                  }
                                },
                                visualDensity: VisualDensity.compact,
                                iconSize: iconSize,
                                icon: Icon(Icons.delete_outline)
                              )
                            ],
                          )
                        ),
                      ),
                    ),
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


class _Tile extends ConsumerWidget {
  final GalleryItem asset;
  final ValueNotifier<bool> _isHovered = ValueNotifier(false);

  _Tile({required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(
      selectionProvider.select((set) => set.contains(asset.id)),
    );

    final inSelectionMode = ref.watch(isSelectionModeProvider);

    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: GestureDetector(
        onTap: () => inSelectionMode 
            ? ref.read(selectionProvider.notifier).toggle(asset.id) 
            : _showFullscreen(context),
        onLongPress: () => ref.read(selectionProvider.notifier).toggle(asset.id),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CachedNetworkImage(
                  imageUrl: asset.thumbnailUrl(),
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

            if (asset is StackedAssets) _buildStackIcon(),
            if (asset.isRaw) _buildRawLabel(),
            
            ValueListenableBuilder<bool>(
              valueListenable: _isHovered,
              builder: (context, hovered, child) {
                if (hovered || inSelectionMode) {
                  return Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () => ref.read(selectionProvider.notifier).toggle(asset.id),
                      child: Icon(
                        Icons.check_circle,
                        color: isSelected ? Colors.blueAccent : Colors.white38,
                        size: 20,
                      ),
                    ),
                  );
                }       
                return const SizedBox.shrink();
              }  
            ),
          ],
        ),
      ),
    );
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
      builder: (_) => _FullscreenView(asset: asset),
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


class _FullscreenView extends StatefulWidget {
  final GalleryItem asset;
  const _FullscreenView({required this.asset});

  @override
  State<_FullscreenView> createState() => _FullscreenViewState();
}

class _FullscreenViewState extends State<_FullscreenView> {
  late ImmichAsset _active;

  @override
  void initState() {
    super.initState();
    _active = switch (widget.asset) {
      SingleAsset a => a.asset,
      StackedAssets a => a.primary,
    };
  }

  List<ImmichAsset> get _all => switch (widget.asset) {
    SingleAsset a => [a.asset],
    StackedAssets a => [a.primary, ...a.children],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _active.originalFileName,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: _active.thumbnailUrl(size: 'preview'),
                httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                fit: BoxFit.contain,
                placeholder: (_, _) =>
                    const CircularProgressIndicator(color: Colors.white),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.broken_image, color: Colors.white38, size: 64),
              ),
            ),
          ),
          if (widget.asset is StackedAssets)
            Positioned(
              bottom: 15,
              right: 0,
              left: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _all.map((a) {
                  final isActive = a == _active;
                  return GestureDetector(
                    onTap: () => setState(() => _active = a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      width: isActive ? 65 : 45,
                      height: isActive ? 65 : 45,
                      margin: EdgeInsets.only(
                        right: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withAlpha((255 * 0.4).round()),
                          width: isActive ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isActive ? 1.0 : 0.5,
                                child: CachedNetworkImage(
                                  imageUrl: a.thumbnailUrl(size: 'preview'),
                                  httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      const CircularProgressIndicator(color: Colors.white),
                                  errorWidget: (_, _, _) =>
                                      const Icon(Icons.broken_image, color: Colors.white38, size: 32),
                                ),
                              ),
                            ),
                            if (a.isRaw)
                              Center(
                                child: Text(
                                  'RAW',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((255 * 0.6).round()),
                                    fontSize: isActive ? 10 : 6,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}