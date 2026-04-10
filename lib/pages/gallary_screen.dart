import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
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
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(galleryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(galleryProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Gallery',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.read(galleryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: galleryState.when(
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
        crossAxisCount: 6,
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


class _Tile extends StatelessWidget {
  final GalleryItem asset;
  const _Tile({required this.asset});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: asset is SingleAsset
                  ? (asset as SingleAsset).asset.thumbnailUrl()
                  : (asset as StackedAssets).primary.thumbnailUrl(),
              httpHeaders: {'x-api-key': ImmichConfig.apiKey},
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Color(0xFF1A1A1A)),
              errorWidget: (_, _, _) => const ColoredBox(
                color: Color(0xFF1A1A1A),
                child: Icon(Icons.broken_image, color: Colors.white24),
              ),
            ),
          ),
          if (asset is StackedAssets)
            Positioned(
              right: 10,
              bottom: 10,
              child: Icon(Icons.filter_none, size: 14, color: Colors.white.withAlpha(200),)
            ),
        ],
      ),
    );
  }
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


class _FullscreenView extends StatelessWidget {
  final GalleryItem asset;
  const _FullscreenView({required this.asset});

  ImmichAsset get _primary => switch (asset) {
        SingleAsset a => a.asset,
        StackedAssets a => a.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _primary.originalFileName,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: _primary.thumbnailUrl(size: 'preview'),
            httpHeaders: {'x-api-key': ImmichConfig.apiKey},
            fit: BoxFit.contain,
            placeholder: (_, _) =>
                const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, _, _) =>
                const Icon(Icons.broken_image, color: Colors.white38, size: 64),
          ),
        ),
      ),
    );
  }
}