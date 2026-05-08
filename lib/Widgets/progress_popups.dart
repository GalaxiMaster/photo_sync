import 'package:flutter/material.dart';
import 'package:photo_sync/Widgets/delete_confirmation.dart';
import 'package:photo_sync/services/api_service.dart';

class UploadProgressController {
  final VoidCallback? onComplete;
  
  UploadProgressController({this.onComplete});
  final _notifier = ValueNotifier<_UploadState>(
    _UploadState(filename: '', progress: 0, sent: 0, total: 1),
  );

  void update({required String filename, required int sent, required int total}) {
    _notifier.value = _UploadState(
      filename: filename,
      progress: sent / total,
      sent: sent,
      total: total,
    );
  }
  void complete() => onComplete?.call();

  void dispose() => _notifier.dispose();
}

class _UploadState {
  final String filename;
  final double progress;
  final int sent;
  final int total;
  const _UploadState({required this.filename, required this.progress, required this.sent, required this.total});
}

Future<bool?> showProgressPopup({
  required BuildContext context,
  required GlobalKey anchorKey,
  required UploadProgressController controller,
  Set<ImageSource> sources = const {ImageSource.immich},
}) {
  return showPositionedPopup<bool>(
    context: context,
    anchorKey: anchorKey,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8, left: 8, right: 8),
      child: UploadProgressBar(controller: controller),
    ),
  );
}

class UploadProgressBar extends StatelessWidget {
  final UploadProgressController controller;

  const UploadProgressBar({super.key, required this.controller});

  String _formatBytes(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_UploadState>(
      valueListenable: controller._notifier,
      builder: (context, state, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.filename, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('Uploading to Immich', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                Text('${(state.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: state.progress,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
              minHeight: 4,
            ),
            const SizedBox(height: 8),
            Text('${_formatBytes(state.sent)} of ${_formatBytes(state.total)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}