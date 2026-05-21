import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:photo_sync/services/api_service.dart';

Future<T?> showPositionedPopup<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required Widget child,
  double? width = 280,
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;

  final pos = box.localToGlobal(Offset.zero);
  final size = box.size;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: "dismiss",
    barrierColor: Colors.black54,
    pageBuilder: (context, _, _) {
      final screenWidth = MediaQuery.of(context).size.width;

      return Stack(
        children: [
          Positioned(
            right: screenWidth - (pos.dx + size.width),
            top: pos.dy + size.height + 8,
            child: Material(
              color: const Color(0xFF2B2B2B),
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              child: width != null
                ? SizedBox(width: width, child: child)
                : IntrinsicWidth(child: child),
            ),
          ),
        ],
      );
    },
  );
}

class DeletePopups {
  static Future<bool?> delete({
    required BuildContext context,
    required GlobalKey anchorKey,
    required int itemCount,
    required double spaceSaved,
    Set<ImageSource> sources = const {ImageSource.immich},
    bool isTrashed = false,
  }) {
    return showPositionedPopup<bool>(
      context: context,
      anchorKey: anchorKey,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 8, left: 8, right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                children: [
                  TextSpan(
                    text: "Move $itemCount ${itemCount == 1 ? 'item' : 'items'} to trash?\n\n",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  if (sources.contains(ImageSource.immich))
                  const TextSpan(text: "Remove from your Immich server and linked devices?"),
                  if (sources.contains(ImageSource.local))
                  const TextSpan(text: "Remove from your local storage?                   "),
                  TextSpan(
                    text: "\n\nYou will recover ${spaceSaved.toStringAsFixed(1)} MB.",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(isTrashed ? "Delete permanently" : "Move to trash"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<int?> deleteStack({
    required int stackSize,
    required BuildContext context,
    required GlobalKey anchorKey,
    Set<ImageSource> sources = const {ImageSource.immich},
    bool isTrashed = false,
  }) {
    Widget optionBox(String label, int value) {
      return SizedBox(
        height: 50,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context, value),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            mouseCursor: SystemMouseCursors.click,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  label,
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return showPositionedPopup<int>(
      context: context,
      anchorKey: anchorKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                children: [
                  if (sources.contains(ImageSource.immich))
                  const TextSpan(text: "Remove from your Immich server and linked devices?"),
                  if (sources.contains(ImageSource.local))
                  const TextSpan(text: "Remove from your local storage?                   "),
                ],
              ),
            ),
          ),
          if (stackSize > 1)...[
            optionBox('Delete all $stackSize photos', 1),
            optionBox('Delete current photo only', 2)
          ] else optionBox('Confirm delete photo', 2),
        ],
      ),
    );
  }
}

Future<List<ImmichAsset>> confirmExternalSourceDelete(
  BuildContext context,
  List<ImmichAsset> assetsFound,
) async {
  final result = await showDialog<List<ImmichAsset>>(
    context: context,
    builder: (_) => _ExternalDeleteDialog(assets: assetsFound),
  );
  return result ?? [];
}

class _ExternalDeleteDialog extends StatefulWidget {
  final List<ImmichAsset> assets;
  const _ExternalDeleteDialog({required this.assets});

  @override
  State<_ExternalDeleteDialog> createState() => _ExternalDeleteDialogState();
}

class _ExternalDeleteDialogState extends State<_ExternalDeleteDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.assets.map((a) => a.localPath!).toSet();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(560, MediaQuery.sizeOf(context).width * 0.85),
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete from external source?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'These local ImmichAssets will be permanently removed.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),

              // Asset list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.assets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final asset = widget.assets[i];
                    final isSelected = _selected.contains(asset.localPath!);
                    final ext = extension(asset.localPath!).toUpperCase().replaceFirst('.', '');
                    final name = basename(asset.localPath!);

                    return GestureDetector(
                      onTap: () => setState(() {
                        isSelected ? _selected.remove(asset.localPath!) : _selected.add(asset.localPath!);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.red.withAlpha(20)
                              : Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Colors.redAccent.withAlpha(80) : Colors.white10,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              // Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: CachedNetworkImage(
                                    imageUrl: asset.thumbnailUrl(),
                                    httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => const ColoredBox(color: Color(0xFF1A1A1A)),
                                    errorWidget: (_, _, _) => _ImmichAssetTypeBadge(ext: ext),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // ImmichAsset info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    // Text(
                                    //   dir,
                                    //   style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    //   overflow: TextOverflow.ellipsis,
                                    // ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Checkbox
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.redAccent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSelected ? Colors.redAccent : Colors.white30,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selected.length} of ${widget.assets.length} selected',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, <ImmichAsset>[]),
                        child: const Text('Keep', style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _selected.isEmpty ? null : () => Navigator.pop(
                          context,
                          widget.assets.where((a) => _selected.contains(a.localPath)).toList(),
                        ),
                        child: const Text('Delete Selected'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImmichAssetTypeBadge extends StatelessWidget {
  final String ext;
  const _ImmichAssetTypeBadge({required this.ext});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A2A3E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_camera_outlined, color: Colors.white24, size: 18),
            const SizedBox(height: 4),
            Text(
              ext,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}