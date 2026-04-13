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
            data: (data) => Padding(
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
                    centerContent: Text(
                      formatAssetDate(data['fileCreatedAt']),
                    ), 
                    trailingIcon: Icons.edit,
                    data: data, 
                  ),
                  infoBox(
                    leadingIcon: Icons.image_outlined, 
                    centerContent: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['originalFileName'],
                        ),
                        Text('${(data['exifInfo']['exifImageWidth'] * data['exifInfo']['exifImageHeight'] / pow(1000, 2)).toStringAsFixed(1)} MP  ${data['exifInfo']['exifImageWidth']} x ${data['exifInfo']['exifImageHeight']}  ${(data['exifInfo']['fileSizeInByte'] / pow(1024, 2)).toStringAsFixed(2)} MiB')
                      ],
                    ),
                    data: data, 
                  ),
                  infoBox(
                    leadingIcon: Icons.camera_alt, 
                    centerContent: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data['exifInfo']['make']} ${data['exifInfo']['model']}'),
                        Text('${data['exifInfo']['exposureTime']} s  𝑓/${data['exifInfo']['fNumber']}  ISO ${data['exifInfo']['iso']}')
                      ],
                    ),
                    data: data, 
                  ),
                  infoBox(
                    leadingIcon: Icons.camera, 
                    centerContent: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data['exifInfo']['lensModel']}'),
                        Text('${data['exifInfo']['focalLength']} mm')
                      ],
                    ),
                    data: data, 
                  ),
                  infoBox(
                    leadingIcon: Icons.location_on, 
                    centerContent: data['exifInfo']['latitude'] != null? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data['exifInfo']['latitude']} \n ${data['exifInfo']['longitude']}'),
                      ],
                    ) : Text('Add a location'),
                    trailingIcon: Icons.edit,
                    data: data, 
                  ),
                ],
              ),
            )
          )
        ],
      ),
    );
  }

  Widget infoBox({required IconData leadingIcon, required Widget centerContent, IconData? trailingIcon, required Map<String, dynamic> data}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(leadingIcon, color: Color.fromARGB(255, 196, 199, 197),),
          centerContent,
          const Spacer(),
          if (trailingIcon != null)
          Icon(trailingIcon, color: Color.fromARGB(255, 196, 199, 197), size: 20,),
        ],
      ),
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