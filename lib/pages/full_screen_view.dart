import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/Side_Panels/photo_info_panel.dart';
import 'package:photo_sync/Widgets/delete_confirmation.dart';
import 'package:photo_sync/Widgets/face_box_painter_overlay.dart';
import 'package:photo_sync/Widgets/face_tagging.dart';
import 'package:photo_sync/Widgets/progress_popups.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/pages/gallary_screen.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';

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
  final GlobalKey downloadKey = GlobalKey();
  final _imageKey = GlobalKey();
  bool _tagging = false;
  AssetFace? _hoveredFace;
  List<GalleryItem> _flatAssets(GalleryBucketState state) {
    return [
      for (final bucket in state.buckets)
        if (bucket.assets != null) ...bucket.assets!,
    ];
  }

  @override
  void initState() {
    super.initState();
    final assets = _flatAssets(ref.read(galleryBucketProvider));
    _index = assets.indexWhere((a) => a.leadAsset.id == widget.asset.leadAsset.id);
    if (_index < 0) _index = 0;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _switchPhoto(int delta, List<GalleryItem> assets) {
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
    final bucketState = ref.watch(galleryBucketProvider);
    final assets = _flatAssets(bucketState);

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
        ? all.firstWhere(
            (a) => a.id == _currentImageId,
            orElse: () => active.leadAsset,
          )
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
              _switchPhoto(-1, assets);
            case LogicalKeyboardKey.arrowRight:
              _switchPhoto(1, assets);
            case LogicalKeyboardKey.escape:
              if (_tagging) {
                setState(() => _tagging = false);
              } else{
                Navigator.of(context).pop();
              }
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
                              child: active.imageSources.contains(ImageSource.immich)
                                ? CachedNetworkImage(
                                  key: _imageKey,
                                  imageUrl: currentImage.thumbnailUrl(size: 'preview'),
                                  httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                  fit: BoxFit.contain,
                                  placeholder: (_, _) => CachedNetworkImage(
                                    imageUrl: currentImage.thumbnailUrl(size: 'preview'),
                                    httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.white38,
                                      size: 32,
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white38,
                                    size: 64,
                                  ),
                                )
                              : LocalAssetTile(
                                key: _imageKey,
                                asset: currentImage,
                                preview: false,
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 10,
                          child: safeIndex < assets.length - 1
                            ? MouseRegion(
                                onEnter: (_) => setState(() => _hoverRight = true),
                                onExit: (_) => setState(() => _hoverRight = false),
                                child: GestureDetector(
                                  onTap: () => _switchPhoto(1, assets),
                                  behavior: HitTestBehavior.opaque,
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width * (1 / 5),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: AnimatedOpacity(
                                        duration: const Duration(milliseconds: 200),
                                        opacity: _hoverRight ? 1.0 : 0.0,
                                        child: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 32,
                                          color: Colors.white70,
                                        ),
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
                          child: safeIndex > 0
                            ? MouseRegion(
                                onEnter: (_) => setState(() => _hoverLeft = true),
                                onExit: (_) => setState(() => _hoverLeft = false),
                                child: GestureDetector(
                                  onTap: () => _switchPhoto(-1, assets),
                                  behavior: HitTestBehavior.opaque,
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width * (1 / 5),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: AnimatedOpacity(
                                        duration: const Duration(milliseconds: 200),
                                        opacity: _hoverLeft ? 1.0 : 0.0,
                                        child: const Icon(
                                          Icons.arrow_back_ios_new,
                                          size: 32,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        ),
                        if (active is StackedAssets)
                          Positioned(
                            bottom: 15,
                            right: 0,
                            left: 0,
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
                                              child: active.isLocal
                                                ? LocalAssetTile(
                                                    key: ValueKey(a.id),
                                                    asset: a,
                                                    preview: true,
                                                  )
                                                : CachedNetworkImage(
                                                    imageUrl: a.thumbnailUrl(size: 'preview'),
                                                    httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, _, _) => const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.white38,
                                                      size: 32,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          if (a.isRaw)
                                            Center(
                                              child: Text(
                                                'RAW',
                                                style: TextStyle(
                                                  color: Colors.white.withAlpha(
                                                      (255 * 0.6).round()),
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
                        if (_tagging)
                          FaceTagOverlay(
                            imageKey: _imageKey,
                            assetId: currentImage.id,
                            onClose: () => setState(() => _tagging = false),
                            imageSize: (currentImage.exifInfo['exifImageWidth'], currentImage.exifInfo['exifImageHeight']),
                          ),
                      ],
                    ),
                  ),
                  if (_hoveredFace != null)
                    Positioned.fill(
                      child: FaceHoverOverlay(
                        imageKey: _imageKey,
                        normalizedBox: _hoveredFace!.toNormalizedRect(),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    left: 0,
                    child: SizedBox(
                      height: 55,
                      child: Row(
                        children: [
                          const SizedBox(width: 5),
                          if (_tagging)
                            IconButton(
                              onPressed: () => setState(() => _tagging = false),
                              mouseCursor: SystemMouseCursors.click,
                              iconSize: iconSize,
                              icon: const Icon(Icons.close, color: Colors.white),
                            )
                          else
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              mouseCursor: SystemMouseCursors.click,
                              iconSize: iconSize,
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {},
                            mouseCursor: SystemMouseCursors.click,
                            iconSize: iconSize,
                            icon: const Icon(Icons.share, color: Colors.white),
                          ),
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
                            icon: const Icon(Icons.tune, color: Colors.white),
                          ),

                          if (currentImage.isTrashed ?? false)
                            IconButton(
                              onPressed: () async {
                                final result = await ref.read(galleryBucketProvider.notifier).restoreFromTrash(currentImage);
                                if (result) {
                                  showSuccessSnackbar('Asset restored successfully');
                                } else {
                                  showErrorSnackbar('Failed to restore asset');
                                }
                              },
                              mouseCursor: SystemMouseCursors.click,
                              iconSize: iconSize,
                              icon: const Icon(Icons.restore, color: Colors.white),
                            ),

                          if (currentImage.imageSources.contains(ImageSource.immich))
                            IconButton(
                              onPressed: () {
                                ref.read(galleryBucketProvider.notifier).toggleFavorite(currentImage);
                              },
                              mouseCursor: SystemMouseCursors.click,
                              iconSize: iconSize,
                              icon: Icon(
                                currentImage.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                                color: Colors.white,
                              ),
                            ),

                          if (!currentImage.imageSources.contains(ImageSource.immich))
                            IconButton(
                              key: uploadKey,
                              onPressed: () async {
                                final uploadController = ProgressController(
                                  onComplete: () => Navigator.pop(context),
                                );
                                showProgressPopup(
                                  context: context,
                                  anchorKey: uploadKey,
                                  controller: uploadController,
                                  downloadMode: false,
                                );
                                await ref.read(galleryBucketProvider.notifier).uploadToImmich(
                                  currentImage,
                                  popupController: uploadController,
                                );
                                uploadController.complete();
                                uploadController.dispose();
                              },
                              mouseCursor: SystemMouseCursors.click,
                              iconSize: iconSize,
                              icon: const Icon(Icons.upload_sharp, color: Colors.white),
                            ),

                          IconButton(
                            key: deleteKey,
                            onPressed: () async {
                              final int? option = await DeletePopups.deleteStack(
                                stackSize: all.length,
                                context: context,
                                anchorKey: deleteKey,
                                sources: currentImage.imageSources,
                                isTrashed: all.every((a) => a.isTrashed ?? false),
                              );

                              if ((option ?? 0) <= 0) return;

                              try {
                                final toDelete = option == 1
                                    ? all.toSet() // full stack
                                    : {currentImage}; // single asset

                                await ref.read(galleryBucketProvider.notifier).deleteAssets(
                                  toDelete,
                                  isTrashed: option == 1
                                      ? all.every((a) => a.isTrashed ?? false)
                                      : (currentImage.isTrashed ?? false),
                                  deleteFromExternalSource: (assetsFound) =>
                                      confirmExternalSourceDelete(context, assetsFound),
                                );

                                ref.read(galleryBucketProvider.notifier).removeAssets(toDelete);

                                if (!context.mounted || !mounted) return;

                                final updatedAssets = _flatAssets(ref.read(galleryBucketProvider));

                                if (updatedAssets.isEmpty) {
                                  Navigator.pop(context);
                                  return;
                                }

                                setState(() => _onAfterDelete(updatedAssets));
                                showSuccessSnackbar('Successfully sent selected asset(s) to the trash');
                              } catch (e, st) {
                                debugPrint('Delete error: $e\n$st');
                                if (mounted) showErrorSnackbar('Delete failed: $e');
                              }
                            },
                            mouseCursor: SystemMouseCursors.click,
                            iconSize: iconSize,
                            icon: const Icon(Icons.delete_outline, color: Colors.white),
                          ),

                          IconButton(
                            key: downloadKey,
                            onPressed: () async {
                              final options = [
                                if (currentImage.imageSources.contains(ImageSource.immich) && currentImage.localPath == null)
                                const PopupMenuItem(
                                  value: 'download',
                                  child: Text('Download Photo'),
                                ),
                              ];
                              if (options.isEmpty) {
                                showErrorSnackbar('No available options');
                                return;
                              }
                              final selected = await showMenu(
                                context: context,
                                position: const RelativeRect.fromLTRB(100, 50, 0, 0),
                                items: options,
                              );
                              if (selected == 'download') {
                                final downloadController = ProgressController(
                                  onComplete: () => Navigator.pop(context),
                                );
                                if (!context.mounted) return;
                                showProgressPopup(
                                  context: context,
                                  anchorKey: downloadKey,
                                  controller: downloadController,
                                  downloadMode: true,
                                );
                                await ref.read(galleryBucketProvider.notifier).downloadAsset(currentImage, downloadController);

                                downloadController.complete();
                                downloadController.dispose();
                              }
                            },
                            mouseCursor: SystemMouseCursors.click,
                            iconSize: iconSize,
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                          ),
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
                functions:(
                  close: () => setState(() => _showInfo = false), 
                  addFace: () => setState(() => _tagging = true),
                  onFaceHover: (AssetFace? face) => setState(() => _hoveredFace = face),
                ),
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