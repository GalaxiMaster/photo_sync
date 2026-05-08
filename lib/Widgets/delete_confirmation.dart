import 'package:flutter/material.dart';
import 'package:photo_sync/services/api_service.dart';

Future<T?> showPositionedPopup<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required Widget child,
  double width = 280,
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
      return Stack(
        children: [
          Positioned(
            left: pos.dx - width + size.width,
            top: pos.dy + size.height + 8,
            child: Material(
              color: const Color(0xFF2B2B2B),
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              child: SizedBox(
                width: width,
                child: child,
              ),
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
                  child: const Text("Move to trash"),
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