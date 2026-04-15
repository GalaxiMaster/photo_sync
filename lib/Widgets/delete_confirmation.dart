import 'package:flutter/material.dart';

Future<bool?> showDeleteConfirmationPopup(int itemCount, double spaceSaved, BuildContext context, GlobalKey key) async {
  final box = key.currentContext!.findRenderObject() as RenderBox;
  final pos = box.localToGlobal(Offset.zero);
  final size = box.size;

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: "dismiss",
    barrierColor: Colors.black54,
    pageBuilder: (_, _, _) {
      return Stack(
        children: [
          Positioned(
            left: pos.dx- 280 + size.width,
            top: pos.dy + size.height + 8,
            child: Material(
              color: const Color(0xFF2B2B2B),
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 280,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                            children: [
                              TextSpan(
                                text: "Move $itemCount ${itemCount == 1 ? 'item' : 'items'} to trash?\n\n",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const TextSpan(
                                text: "Remove from your Immich server,\n"
                                      "linked devices with backup enabled, and\n"
                                      "shared albums or partner sharing?\n\n",
                              ),
                              TextSpan(
                                text: "You will recover ${spaceSaved.toStringAsFixed(1)} MB from your\n"
                                      "server storage.",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}