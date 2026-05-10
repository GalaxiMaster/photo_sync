import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/delete_confirmation.dart';
import 'package:photo_sync/Widgets/progress_popups.dart';
import 'package:photo_sync/Widgets/side_panels.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/pages/gallary_screen.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';
// import 'package:open_file/open_file.dart';

class FullscreenView extends ConsumerStatefulWidget {
  final GalleryItem asset;
  
  const FullscreenView({super.key, required this.asset});

  @override
  ConsumerState<FullscreenView> createState() => _FullscreenViewState();
}

class _FullscreenViewState extends ConsumerState<FullscreenView> {
  final _focusNode = FocusNode();
  late int _index;
  String? _currentImageId;
  bool _hoverLeft = false;
  bool _hoverRight = false;
  final double iconSize = 24;
  bool _showInfo = false;
  final GlobalKey deleteKey = GlobalKey();
  final GlobalKey uploadKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final assets = ref.read(galleryProvider).value ?? [];
    _index = assets.indexOf(widget.asset);
    if (_index < 0) _index = 0;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void switchPhoto(int delta, List<GalleryItem> assets) {
    final next = _index + delta;
    if (next < 0 || next >= assets.length) return;
    setState(() {
      _index = next;
      _currentImageId = null;
    });
  }

  void _onAfterDelete(List<GalleryItem> updatedAssets) {
    _currentImageId = null;
    if (updatedAssets.isEmpty) return;
    if (_index >= updatedAssets.length) {
      _index = updatedAssets.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(galleryProvider).value ?? [];
    if (assets.isEmpty) return const Scaffold(backgroundColor: Colors.black);

    if (_index >= assets.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _index = assets.length - 1;
            _currentImageId = null;
          });
        }
      });
    }

    final safeIndex = _index.clamp(0, assets.length - 1);
    final active = assets[safeIndex];

    final all = switch (active) {
      SingleAsset a => [a.asset],
      StackedAssets a => [a.primary, ...a.children],
    };

    final ImmichAsset currentImage = _currentImageId != null
        ? all.firstWhere((a) => a.id == _currentImageId,
            orElse: () => active.leadAsset)
        : active.leadAsset;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowLeft:
              switchPhoto(-1, assets);
            case LogicalKeyboardKey.arrowRight:
              switchPhoto(1, assets);
            case LogicalKeyboardKey.escape:
              Navigator.of(context).pop();
          }
        },
        child: Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.85,
                              ),
                              child: !widget.asset.isLocal ? CachedNetworkImage(
                                imageUrl: currentImage.thumbnailUrl(size: 'preview'),
                                httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                fit: BoxFit.contain,
                                placeholder: (_, _) => CachedNetworkImage(
                                  imageUrl: currentImage.thumbnailUrl(size: 'preview'),
                                  httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      const Icon(Icons.broken_image, color: Colors.white38, size: 32),
                                ),
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.broken_image, color: Colors.white38, size: 64),
                              ) : LocalAssetTile(
                                key: ValueKey(currentImage.id),
                                asset: currentImage, 
                                preview: false,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0, bottom: 0, right: 10,
                          child: safeIndex < assets.length - 1
                            ? MouseRegion(
                                onEnter: (_) => setState(() => _hoverRight = true),
                                onExit: (_) => setState(() => _hoverRight = false),
                                child: GestureDetector(
                                  onTap: () => switchPhoto(1, assets),
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
                          top: 0, bottom: 0, left: 10,
                          child: safeIndex > 0
                            ? MouseRegion(
                                onEnter: (_) => setState(() => _hoverLeft = true),
                                onExit: (_) => setState(() => _hoverLeft = false),
                                child: GestureDetector(
                                  onTap: () => switchPhoto(-1, assets),
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

                        if (active is StackedAssets)
                          Positioned(
                            bottom: 15, right: 0, left: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: all.map((a) {
                                final isActive = a.id == currentImage.id;
                                return GestureDetector(
                                  onTap: () => setState(() => _currentImageId = a.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    width: isActive ? 65 : 45,
                                    height: isActive ? 65 : 45,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isActive
                                            ? Colors.white
                                            : Colors.white.withAlpha((255 * 0.4).round()),
                                        width: isActive ? 2 : 0,
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
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    left: 0,
                    child: SizedBox(
                      height: 55,
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          const SizedBox(width: 5),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            mouseCursor: SystemMouseCursors.click,
                            iconSize: iconSize,
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          const Spacer(),
                          IconButton(onPressed: () {}, mouseCursor: SystemMouseCursors.click, iconSize: iconSize, icon: const Icon(Icons.share, color: Colors.white)),
                          IconButton(
                            onPressed: () => setState(() => _showInfo = !_showInfo),
                            mouseCursor: SystemMouseCursors.click,
                            iconSize: iconSize,
                            icon: const Icon(Icons.info_outline, color: Colors.white),
                          ),
                          IconButton(
                            onPressed: () {
                              if (currentImage.localPath == null) {
                                showErrorSnackbar('No local path available for this asset');
                                return;
                              }
                              openWithDialog(currentImage.localPath!);
                            }, 
                            mouseCursor: SystemMouseCursors.click, 
                            iconSize: iconSize, 
                            icon: const Icon(
                              Icons.tune, 
                              color: Colors.white
                            )
                          ),

                          if (currentImage.imageSources.contains(ImageSource.immich))
                          IconButton(
                            onPressed: () {
                              ref.read(galleryProvider.notifier).toggleFavorite(currentImage);
                            }, 
                            mouseCursor: SystemMouseCursors.click, 
                            iconSize: iconSize, 
                            icon: Icon(
                              currentImage.isFavorite ? Icons.favorite : Icons.favorite_border, 
                              color: Colors.white
                            )
                          ),

                          if (!currentImage.imageSources.contains(ImageSource.immich))
                          IconButton(
                            key: uploadKey,
                            onPressed: () async {
                              final uploadController = UploadProgressController(
                                onComplete: () => Navigator.pop(context),
                              );

                              showProgressPopup(
                                context: context,
                                anchorKey: uploadKey,
                                controller: uploadController,
                              );
                              await ref.read(galleryProvider.notifier).uploadToImmich(currentImage, popupController: uploadController);
                              uploadController.complete();
                              uploadController.dispose();
                            },
                            mouseCursor: SystemMouseCursors.click, 
                            iconSize: iconSize, 
                            icon: Icon(
                              Icons.upload_sharp, 
                              color: Colors.white
                            )
                          ),
                          IconButton(
                            key: deleteKey,
                            onPressed: () async {
                              final int? option = await DeletePopups.deleteStack(
                                stackSize: all.length,
                                context: context,
                                anchorKey: deleteKey,
                                sources: currentImage.imageSources,
                              );

                              if ((option ?? 0) <= 0) return;

                              try {
                                if (option == 1) {
                                  // Delete full stack
                                  await ref.read(galleryProvider.notifier)
                                      .deleteAssets(all.map((e) => e.id).toList());
                                } else if (option == 2) {
                                  // Delete single asset
                                  await ref.read(galleryProvider.notifier)
                                      .deleteAssets([currentImage.id]);
                                }

                                if (!context.mounted) return;

                                final updatedAssets = ref.read(galleryProvider).value ?? [];

                                if (updatedAssets.isEmpty) {
                                  Navigator.pop(context);
                                  return;
                                }

                                setState(() => _onAfterDelete(updatedAssets));

                                showSuccessSnackbar('Successfully sent selected asset(s) to the trash');
                              } catch (e) {
                                if (context.mounted) {
                                  showErrorSnackbar('Delete failed: $e');
                                }
                              }
                            }, 
                            mouseCursor: SystemMouseCursors.click,
                            iconSize: iconSize,
                            icon: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          IconButton(onPressed: () {}, mouseCursor: SystemMouseCursors.click, iconSize: iconSize, icon: const Icon(Icons.more_vert, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _showInfo ? 400 : 0.0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: InfoPanel(
                asset: currentImage,
                close: () => setState(() => _showInfo = false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openWithDialog(String filePath) async {
  if (Platform.isWindows) {
    // await OpenFile.open(absolutePath);
    final cleanPath = filePath.replaceAll(r'\\', r'\');

    await Process.run(
      'rundll32',
      ['shell32.dll,OpenAs_RunDLL', cleanPath],
      runInShell: true,
    );
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [filePath]);
  }
}


