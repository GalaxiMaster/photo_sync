import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/pages/full_screen_view.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/provider/selection_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:photo_sync/services/exiftool.dart';
import 'package:flutter_svg/flutter_svg.dart';

// helpers
const int _kCrossAxisCount = 8;
const double _kTileSpacing = 2.0;
const double _kHeaderHeight = 32.0;
const double _kScrubberWidth = 36.0;

const _kGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: _kCrossAxisCount,
  crossAxisSpacing: _kTileSpacing,
  mainAxisSpacing: _kTileSpacing,
);

double _bucketHeight(MonthBucket b, double tileSize) {
  final count = b.assets?.length ?? b.count;
  final rows = (count / _kCrossAxisCount).ceil();
  final gridH = rows > 0 ? rows * tileSize + (rows - 1) * _kTileSpacing : 0.0;
  return _kHeaderHeight + gridH;
}

int _exifRotation(Map exifInfo) {
  final o = exifInfo['Orientation']?.toString().toLowerCase() ?? '';
  if (o.contains('rotate 90') || o.contains('90 cw')) return 1;
  if (o.contains('rotate 180') || o.contains('180')) return 2;
  if (o.contains('rotate 270') || o.contains('90 ccw')) return 3;
  return 0;
}
// screen
class GalleryScreen extends ConsumerStatefulWidget {
  final bool canScroll;
  final Widget? header;

  const GalleryScreen({super.key, this.canScroll = true, this.header});

  @override
  GalleryScreenState createState() => GalleryScreenState();
}

class GalleryScreenState extends ConsumerState<GalleryScreen> {
  final _scrollController = ScrollController();

  bool _scrubbing = false;
  double _scrubOffset = 0.0;
  double _maxScrollExtent = 1.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _tileSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width - _kScrubberWidth;
    return (w - (_kCrossAxisCount - 1) * _kTileSpacing) / _kCrossAxisCount;
  }

  void _correctScrollOnBucketChange(
    GalleryBucketState prev,
    GalleryBucketState next,
    double tileSize,
    double headerH,
  ) {
    if (!_scrollController.hasClients) return;

    double cumulative = headerH;
    double totalDelta = 0.0;

    for (var i = 0; i < next.buckets.length && i < prev.buckets.length; i++) {
      final oldH = _bucketHeight(prev.buckets[i], tileSize);
      final newH = _bucketHeight(next.buckets[i], tileSize);
      final delta = oldH - newH;

      if (delta.abs() > 0.5) {
        final bucketBottom = cumulative + oldH;
        if (bucketBottom <= _scrollController.offset + totalDelta) {
          totalDelta += delta;
        }
      }
      cumulative += oldH;
    }

    if (totalDelta.abs() > 0.5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(
          (_scrollController.offset - totalDelta)
              .clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bucketState = ref.watch(galleryBucketProvider);

    ref.listen<GalleryBucketState>(galleryBucketProvider, (prev, next) {
      if (prev == null) return;
      final headerH = widget.header != null ? 60.0 : 0.0;
      _correctScrollOnBucketChange(prev, next, _tileSize(context), headerH);
    });

    if (bucketState.initialising) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (bucketState.error != null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(bucketState.error!,
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(galleryBucketProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final buckets = bucketState.buckets;
    final tileSize = _tileSize(context);
    final headerH = widget.header != null ? 60.0 : 0.0;

    final slivers = <Widget>[
      if (widget.header != null) SliverToBoxAdapter(child: widget.header!),
      ...List.generate(buckets.length, (i) => _BucketSliver(
        key: ValueKey(buckets[i].key),
        bucket: buckets[i],
        bucketIndex: i,
        onVisible: () => ref.read(galleryBucketProvider.notifier).prefetchAround(i),
      )),
    ];

    final scrollView = CustomScrollView(
      controller: _scrollController,
      physics: widget.canScroll ? null : const NeverScrollableScrollPhysics(),
      shrinkWrap: !widget.canScroll,
      slivers: slivers,
    );

    if (!widget.canScroll || buckets.isEmpty) {
      return widget.canScroll ? Expanded(child: scrollView) : scrollView;
    }

    return Expanded(
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (_scrubbing) return false;
          final ext = n.metrics.maxScrollExtent;
          if (ext > 1.0) {
            setState(() {
              _maxScrollExtent = ext;
              _scrubOffset =
                  (n.metrics.pixels / ext).clamp(0.0, 1.0);
            });
          }
          return false;
        },
        child: Stack(
          children: [
            Positioned.fill(
              right: _kScrubberWidth,
              child: scrollView,
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _kScrubberWidth,
              child: _TimelineScrubber(
                buckets: buckets,
                scrollFraction: _scrubOffset,
                tileSize: tileSize,
                headerHeight: headerH,
                stableMax: _maxScrollExtent,
                onDragStart: () => setState(() => _scrubbing = true),
                onDragUpdate: (fraction) {
                  setState(() => _scrubOffset = fraction);
                  _scrollController.jumpTo(
                    (fraction * _maxScrollExtent).clamp(
                        0.0, _scrollController.position.maxScrollExtent),
                  );
                },
                onDragEnd: () => setState(() => _scrubbing = false),
                onTapPixelOffset: (pixels) => _scrollController.animateTo(
                  pixels.clamp(
                      0.0, _scrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketSliver extends ConsumerStatefulWidget {
  final MonthBucket bucket;
  final int bucketIndex;
  final VoidCallback onVisible;

  const _BucketSliver({
    super.key,
    required this.bucket,
    required this.bucketIndex,
    required this.onVisible,
  });

  @override
  ConsumerState<_BucketSliver> createState() => _BucketSliverState();
}

class _BucketSliverState extends ConsumerState<_BucketSliver> {
  bool _didRequestLoad = false;

  @override
  Widget build(BuildContext context) {
    final bucket = ref.watch(
      galleryBucketProvider.select(
        (s) => s.buckets.firstWhere(
          (b) => b.key == widget.bucket.key,
          orElse: () => widget.bucket,
        ),
      ),
    );

    if (bucket.assets == null && !bucket.loading && !_didRequestLoad) {
      _didRequestLoad = true;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (mounted) widget.onVisible(); });
    }
    
    if (bucket.assets != null) _didRequestLoad = false;

    final assets = bucket.assets;

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _MonthHeaderDelegate(
            year: bucket.year,
            month: bucket.month,
            count: bucket.count,
          ),
        ),
        SliverGrid(
          gridDelegate: _kGridDelegate,
          delegate: SliverChildBuilderDelegate(
            (_, i) => assets == null
                ? const _PlaceholderTile()
                : _Tile(asset: assets[i]),
            childCount: assets?.length ?? bucket.count,
          ),
        ),
      ],
    );
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int year, month, count;

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  const _MonthHeaderDelegate({
    required this.year,
    required this.month,
    required this.count,
  });

  @override
  double get minExtent => _kHeaderHeight;
  @override
  double get maxExtent => _kHeaderHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _kHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            '${_months[month]} $year',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate old) => old.year != year || old.month != month || old.count != count;
}

class _TimelineScrubber extends StatefulWidget {
  final List<MonthBucket> buckets;
  final double scrollFraction;
  final double tileSize;
  final double headerHeight;
  final double stableMax;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<double> onTapPixelOffset;

  const _TimelineScrubber({
    required this.buckets,
    required this.scrollFraction,
    required this.tileSize,
    required this.headerHeight,
    required this.stableMax,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTapPixelOffset,
  });

  @override
  State<_TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends State<_TimelineScrubber> {
  bool _dragging = false;
  final _trackKey = GlobalKey();

  // Cached pixel offsets: recomputed only when buckets/tileSize/headerHeight change
  List<double> _pixelOffsets = [];
  double _totalContentH = 1.0;
  String _cacheKey = '';

  @override
  void initState() {
    super.initState();
    _recomputeOffsets();
  }

  @override
  void didUpdateWidget(_TimelineScrubber old) {
    super.didUpdateWidget(old);
    _recomputeOffsets();
  }

  void _recomputeOffsets() {
    final key =
        '${widget.tileSize.toStringAsFixed(2)}:${widget.headerHeight}:'
        '${widget.buckets.map((b) => '${b.key}:${b.assets?.length ?? b.count}').join(',')}';
    if (key == _cacheKey) return;
    _cacheKey = key;

    double cumulative = widget.headerHeight;
    final offsets = <double>[];
    for (final b in widget.buckets) {
      offsets.add(cumulative);
      cumulative += _bucketHeight(b, widget.tileSize);
    }
    _pixelOffsets = offsets;
    _totalContentH = cumulative.clamp(1.0, double.infinity);
  }

  double _fractionAt(double localY) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    return (localY / box.size.height).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.buckets.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onVerticalDragStart: (d) {
        _dragging = true;
        widget.onDragStart();
        widget.onDragUpdate(_fractionAt(d.localPosition.dy));
      },
      onVerticalDragUpdate: (d) {
        if (_dragging) widget.onDragUpdate(_fractionAt(d.localPosition.dy));
      },
      onVerticalDragEnd: (_) {
        _dragging = false;
        widget.onDragEnd();
      },
      onTapDown: (d) => widget
          .onTapPixelOffset(_fractionAt(d.localPosition.dy) * widget.stableMax),
      child: Container(
        key: _trackKey,
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const thumbH = 20.0;
            final usable = constraints.maxHeight;

            // Map each year to the index of its oldest (lowest) bucket.
            final yearLabelIdx = <int, int>{};
            for (var i = 0; i < widget.buckets.length; i++) {
              yearLabelIdx[widget.buckets[i].year] = i;
            }

            final markers = <Widget>[];
            for (var i = 0; i < widget.buckets.length; i++) {
              final f = _pixelOffsets.length > i
                  ? (_pixelOffsets[i] / widget.stableMax).clamp(0.0, 1.0)
                  : 0.0;
              final b = widget.buckets[i];
              final top = f * usable;
              final isYearLabel = yearLabelIdx[b.year] == i;

              markers.add(Positioned(
                top: top - 0.5,
                right: 3,
                child: Container(
                  width: isYearLabel ? 10 : 5,
                  height: isYearLabel ? 1.5 : 1.0,
                  color: isYearLabel ? Colors.white54 : Colors.white24,
                ),
              ));

              if (isYearLabel) {
                final nextPixel = _pixelOffsets.length > i + 1
                    ? _pixelOffsets[i + 1]
                    : _totalContentH;
                final nextF = (nextPixel / _totalContentH).clamp(0.0, 1.0);
                const labelH = 10.0;
                final labelTop =
                    (nextF * usable - labelH).clamp(0.0, usable - labelH);
                final bucketPixels =
                    _pixelOffsets.length > i ? _pixelOffsets[i] : 0.0;

                markers.add(Positioned(
                  top: labelTop,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => widget.onTapPixelOffset(bucketPixels),
                    child: Text(
                      '${b.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ));
              }
            }

            final thumbTop =
                (widget.scrollFraction * usable - thumbH / 2)
                    .clamp(0.0, usable - thumbH);

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: _kScrubberWidth / 2 - 0.5,
                  top: 0,
                  height: usable,
                  width: 1,
                  child: const ColoredBox(color: Color(0xFF333333)),
                ),
                ...markers,
                Positioned(
                  top: thumbTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 6,
                      height: thumbH,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF1A1A1A));
}

class _Tile extends ConsumerStatefulWidget {
  final GalleryItem asset;
  const _Tile({required this.asset});

  @override
  ConsumerState<_Tile> createState() => _TileState();
}

class _TileState extends ConsumerState<_Tile> {
  final _isHovered = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    final all = switch (widget.asset) {
      SingleAsset a => [a.asset],
      StackedAssets a => [a.primary, ...a.children],
    };
    final isSelected = ref.watch(
      selectionProvider.select((s) => s.contains(widget.asset.leadAsset)),
    );
    final inSelectionMode = ref.watch(isSelectionModeProvider);

    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: GestureDetector(
        onTap: () => inSelectionMode
            ? _toggleSelection(all)
            : _showFullscreen(context),
        onLongPress: () => _toggleSelection(all),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: widget.asset.imageSources.contains(ImageSource.immich)
                    ? CachedNetworkImage(
                        imageUrl: widget.asset.thumbnailUrl(),
                        httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: Color(0xFF1A1A1A)),
                      )
                    : LocalAssetTile(asset: widget.asset.leadAsset),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isHovered,
              builder: (context, hovered, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hovered)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: MediaQuery.of(context).size.height / 6,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
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
                      ),
                    if (hovered || inSelectionMode)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: GestureDetector(
                          onTap: () => _toggleSelection(all),
                          child: Icon(
                            Icons.check_circle,
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.white38,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (widget.asset is StackedAssets)
              const Positioned(
                right: 10,
                bottom: 10,
                child: Icon(Icons.filter_none, size: 14, color: Colors.white70),
              ),
            if (widget.asset.isRaw)
              const Positioned(
                top: 10,
                right: 12.5,
                child: Text('RAW',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            if (widget.asset.imageSources.length > 1)
              Positioned(
                bottom: 10,
                left: 12.5,
                child: SvgPicture.asset(
                  switch (widget.asset.imageSources.last) {
                    ImageSource.local => 'assets/icons/local.svg',
                    ImageSource.immich => 'assets/icons/immich.svg',
                  },
                  width: 15,
                  height: 15,
                  colorFilter: ColorFilter.mode(
                      Colors.white.withAlpha(200), BlendMode.srcIn),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(List<ImmichAsset> all) {
    for (final el in all) {
      ref.read(selectionProvider.notifier).toggle(el);
    }
  }

  void _showFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FullscreenView(asset: widget.asset)),
    );
  }
}


class LocalAssetTile extends StatelessWidget {
  final ImmichAsset asset;
  final bool preview;
  final void Function(ImmichAsset asset)? onTap;

  const LocalAssetTile(
      {super.key, required this.asset, this.onTap, this.preview = true});

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

// Shared FutureBuilder body for RAW/video embedded JPEG thumbnails.
class _EmbeddedJpegImage extends StatelessWidget {
  final Future<Uint8List?> future;
  final Object cacheKey;
  final Map exifInfo;
  final int cacheWidth;

  const _EmbeddedJpegImage({
    required this.future,
    required this.cacheKey,
    required this.exifInfo,
    this.cacheWidth = 400,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: future,
      key: ValueKey(cacheKey),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError || snapshot.data == null) {
          return const Icon(Icons.broken_image);
        }
        return RotatedBox(
          quarterTurns: _exifRotation(exifInfo),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            key: ValueKey(cacheKey),
            errorBuilder: (_, error, _) {
              debugPrint('Image decode failed: $error');
              return const Icon(Icons.warning_amber_rounded);
            },
            frameBuilder: (_, child, frame, _) =>
                frame == null ? const ColoredBox(color: Colors.black12) : child,
          ),
        );
      },
    );
  }
}

class LocalImage extends ConsumerStatefulWidget {
  final ImmichAsset asset;
  final bool preview;
  const LocalImage({super.key, required this.asset, this.preview = true});

  @override
  ConsumerState<LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends ConsumerState<LocalImage> {
  Future<Uint8List?>? _rawFuture;

  @override
  void initState() {
    super.initState();
    _maybeLoadRaw();
  }

  @override
  void didUpdateWidget(covariant LocalImage old) {
    super.didUpdateWidget(old);
    if (old.asset.localPath != widget.asset.localPath) _maybeLoadRaw();
  }

  void _maybeLoadRaw() {
    _rawFuture = widget.asset.isRaw
        ? getEmbeddedJpeg(widget.asset.localPath!)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asset.isRaw) {
      return _EmbeddedJpegImage(
        future: _rawFuture!,
        cacheKey: widget.asset.originalUrl,
        exifInfo: widget.asset.exifInfo,
        cacheWidth: widget.preview ? 400 : (widget.asset.exifInfo['exifImageWidth'] ?? 0),
      );
    }

    return RotatedBox(
      quarterTurns: _exifRotation(widget.asset.exifInfo),
      child: Image.file(
        File(widget.asset.localPath!),
        fit: BoxFit.cover,
        cacheWidth: widget.preview ? 200 : null,
        key: ValueKey(widget.asset.originalUrl),
        frameBuilder: (_, child, frame, wasSync) =>
            wasSync || frame != null ? child : const ColoredBox(color: Color(0xFF1A1A1A)),
        errorBuilder: (_, _, _) => const _ErrorTile(),
      ),
    );
  }
}

class _VideoTile extends ConsumerStatefulWidget {
  final ImmichAsset asset;
  const _VideoTile({required this.asset});

  @override
  ConsumerState<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends ConsumerState<_VideoTile> {
  late final Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = getEmbeddedJpeg(widget.asset.localPath!);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: _EmbeddedJpegImage(
            future: _future,
            cacheKey: widget.asset.originalUrl,
            exifInfo: widget.asset.exifInfo,
          ),
        ),
        const Center(child: Icon(Icons.play_circle, color: Colors.white70, size: 30)),
      ],
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2A2A2A),
      child: Column(
        children: [
          Icon(Icons.broken_image, color: Colors.white38),
          Text('broken'),
        ],
      ),
    );
  }
}