import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:intl/intl.dart';

final assetMetadataProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, assetId) => ref.read(immichServiceProvider).getAssetMetadata(assetId),
);

class InfoPanel extends ConsumerWidget {
  final ImmichAsset asset;
  final VoidCallback close;
  const InfoPanel({super.key, required this.asset, required this.close});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(assetMetadataProvider(asset.id));
    return Container(
      color: Color.fromRGBO(19, 19, 20, 1),
      padding: const EdgeInsets.all(8),
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10,
            children: [
              IconButton(
                onPressed: close,
                mouseCursor: SystemMouseCursors.click, 
                icon: Icon(Icons.close)
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Info',
                  style: TextStyle(
                    fontSize: 24,
                  ),
                ),
              ),
            ],
          ),
          metadata.when(
            loading: () => const CircularProgressIndicator(color: Colors.white),
            error: (e, _) => Text('Error: $e'),
            data: (data) {
              final exif = data['exifInfo'];
              final mp = (exif['exifImageWidth'] * exif['exifImageHeight'] / pow(1000, 2)).toStringAsFixed(1);
              final sizeMiB = (exif['fileSizeInByte'] / pow(1024, 2)).toStringAsFixed(2);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('People'),
                        IconButton(onPressed: (){}, icon: Icon(Icons.add))
                      ],
                    ),
                    Text('Details'),
                    infoBox(
                      leadingIcon: Icons.calendar_month_outlined,
                      centerContent: SelectableText(formatAssetDate(data['fileCreatedAt'])),
                      trailingIcon: Icons.edit,
                    ),
                    infoBox(
                      leadingIcon: Icons.image_outlined,
                      centerContent: _infoColumn(
                        context,
                        [
                          data['originalFileName'],
                          '$mp MP  ${exif['exifImageWidth']} x ${exif['exifImageHeight']}  $sizeMiB MiB',
                        ]
                      ),
                    ),
                    infoBox(
                      leadingIcon: Icons.camera_alt,
                      centerContent: _infoColumn(
                        context,
                        [
                          '${exif['make']} ${exif['model']}',
                          '${exif['exposureTime']} s  𝑓/${exif['fNumber']}  ISO ${exif['iso']}',
                        ]
                      ),
                    ),
                    infoBox(
                      leadingIcon: Icons.camera,
                      centerContent: _infoColumn(
                        context,
                        [
                          '${exif['lensModel']}',
                          '${exif['focalLength']} mm',
                        ]
                      ),
                    ),
                    infoBox(
                      leadingIcon: Icons.location_on,
                      centerContent: exif['latitude'] != null
                          ? _infoColumn(
                            context,
                            ['${exif['latitude']}', '${exif['longitude']}']
                          )
                          : const Text('Add a location'),
                      trailingIcon: Icons.edit,
                    ),
                  ],
                ),
              );
            }
          )
        ],
      ),
    );
  }

  Widget infoBox({
    required IconData leadingIcon,
    required Widget centerContent,
    IconData? trailingIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(leadingIcon, color: const Color.fromARGB(255, 196, 199, 197)),
          Expanded(child: centerContent),
          if (trailingIcon != null)
            Icon(trailingIcon, color: const Color.fromARGB(255, 196, 199, 197), size: 20),
        ],
      ),
    );
  }

  Widget _infoColumn(BuildContext context, List<String> lines) {
    final baseStyle = DefaultTextStyle.of(context).style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lines.indexed.map((entry) => SelectableText(
        entry.$2,
        style: entry.$1 == 0 
            ? baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) + 2)
            : baseStyle,
      )).toList(),
    );
  }
}
String formatAssetDate(String isoString) {
  final utc = DateTime.parse(isoString);
  final local = utc.toLocal();

  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');

  final dateLine = DateFormat('MMM d, y').format(local);
  final timeLine = DateFormat('EEE, h:mm:ss a').format(local);

  return '$dateLine\n$timeLine GMT$sign$hours:$minutes';
}