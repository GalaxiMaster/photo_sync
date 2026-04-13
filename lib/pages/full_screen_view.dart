import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';

class FullscreenView extends ConsumerStatefulWidget {
  final GalleryItem asset;
  
  const FullscreenView({super.key, required this.asset});

  @override
  ConsumerState<FullscreenView> createState() => _FullscreenViewState();
}

class _FullscreenViewState extends ConsumerState<FullscreenView> {
  late GalleryItem _active;
  late ImmichAsset _currentImage;
  final _focusNode = FocusNode();
  late int _index;
  bool _hoverLeft = false;
  bool _hoverRight = false;

  @override
  void initState() {
    super.initState();
    final assets = ref.read(galleryProvider).value ?? [];
    _index = assets.indexOf(widget.asset);
    _active = widget.asset;
    _currentImage = _active.leadAsset;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void switchPhoto(int delta) {
    final assets = ref.read(galleryProvider).value ?? [];
    final next = _index + delta;
    if (next < 0 || next >= assets.length) return;
    setState(() {
      _index = next;
      _active = assets[_index];
      _currentImage = _active.leadAsset;
    });
  }
  
  List<ImmichAsset> get _all => switch (_active) {
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
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is! KeyDownEvent) return;

          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowLeft:
              switchPhoto(-1);
            case LogicalKeyboardKey.arrowRight:
              switchPhoto(1);
            case LogicalKeyboardKey.escape:
              Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: _currentImage.thumbnailUrl(size: 'preview'),
                  httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                  fit: BoxFit.contain,
                  placeholder: (_, _) =>
                      const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.broken_image, color: Colors.white38, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 10,
              child: _index < (ref.read(galleryProvider).value?.length ?? 0) - 1
                ? MouseRegion(
                  onEnter: (_) => setState(() => _hoverRight = true),
                  onExit: (_) => setState(() => _hoverRight = false),
                  child: GestureDetector(
                    onTap: () => switchPhoto(1),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * (1 / 5),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _hoverRight ? 1.0 : 0.0,
                          child: const Icon(Icons.arrow_forward_ios, size: 32, color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                )
                : const SizedBox.shrink(),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 10,
              child: _index > 0
                ? MouseRegion(
                  onEnter: (_) => setState(() => _hoverLeft = true),
                  onExit: (_) => setState(() => _hoverLeft = false),
                  child: GestureDetector(
                    onTap: () => switchPhoto(-1),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * (1 / 5),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _hoverLeft ? 1.0 : 0.0,
                          child: const Icon(Icons.arrow_back_ios_new, size: 32, color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                )
                : const SizedBox.shrink(),
            ),

            // Bottom Stack thumbnails
            if (widget.asset is StackedAssets)
              Positioned(
                bottom: 15,
                right: 0,
                left: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _all.map((a) {
                    final isActive = a == _currentImage;
                    return GestureDetector(
                      onTap: () => setState(() => _currentImage = a),
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
      )
    );
  }
}