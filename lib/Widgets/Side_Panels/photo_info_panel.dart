import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/date_popup.dart';
import 'package:photo_sync/Widgets/map_view.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:intl/intl.dart';

final _placeNameProvider = FutureProvider.family<String?, (double, double)>((ref, coords) async {
  final (lat, lng) = coords;
  return getPlaceName(lat, lng);
});

class InfoPanel extends ConsumerStatefulWidget {
  final ImmichAsset asset;
  final ({VoidCallback close, VoidCallback addFace}) functions;
  const InfoPanel({super.key, required this.asset, required this.functions});

  @override
  ConsumerState<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends ConsumerState<InfoPanel> {
  final _pageController = PageController();

  void _goTo(int index) => _pageController.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeInOutCubic,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromRGBO(19, 19, 20, 1),
      padding: const EdgeInsets.all(8),
      width: 400,
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _InfoView(
            asset: widget.asset,
            functions: widget.functions,
            onEditPeople: () => _goTo(1),
          ),
          EditPeoplePanel(
            asset: widget.asset,
            onBack: () => _goTo(0),
          ),
        ],
      ),
    );
  }
}

class _InfoView extends ConsumerWidget {
  final ImmichAsset asset;
  final ({VoidCallback close, VoidCallback addFace}) functions;
  final VoidCallback onEditPeople;
  const _InfoView({required this.asset, required this.functions, required this.onEditPeople});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exif = asset.exifInfo;
    final mp = (exif['exifImageWidth'] * exif['exifImageHeight'] / pow(1000, 2)).toStringAsFixed(1);
    final sizeMiB = (exif['fileSizeInByte'] / pow(1024, 2)).toStringAsFixed(2);
    final placeName = ref.watch(_placeNameProvider((exif['latitude'] ?? 0, exif['longitude'] ?? 0)));

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
                onPressed: functions.close,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(),
                Row(
                  children: [
                    Text('People'),
                    Spacer(),
                    IconButton(onPressed: () => functions.addFace(), icon: Icon(Icons.add)),
                    if (asset.people.isNotEmpty)
                    IconButton(onPressed: () => onEditPeople(), icon: Icon(Icons.edit))
                  ],
                ),
                if (asset.people.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: asset.people.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final ImmichPerson person = asset.people.elementAt(index);
                        final String url = person.thumbnailUrl(ImmichConfig.baseUrl);
                  
                        return Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      color: Theme.of(context).colorScheme.error,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Text(person.name)
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Text('Details'),
                infoBox(
                  leadingIcon: Icons.calendar_month_outlined,
                  centerContent: _infoColumn(context, formatAssetDate(asset.fileCreatedAt.toLocal())),
                  trailingIcon: Icons.edit,
                  onClick: () async {
                    final picked = await showEditDateTimeDialog(context, asset.fileCreatedAt.toLocal());
                    if (picked != null) {
                      await ref.read(galleryBucketProvider.notifier).changeAssetDate(asset, picked.toUtc().toIso8601String());
                    }
                  },
                ),
                infoBox(
                  leadingIcon: Icons.image_outlined,
                  centerContent: _infoColumn(
                    context,
                    [
                      asset.originalFileName,
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
                      ? placeName.when(
                        data: (name) => Text(name ?? 'Unknown location'),
                        loading: () => const Text('Loading...'),
                        error: (e, _) => const Text('Unknown location'),
                      )
                      : const Text('Add a location'),
                  trailingIcon: Icons.edit,
                ),
              ],
            ),
          ),
          if (exif['latitude'] != null) 
            AspectRatio(
              aspectRatio: 1, 
              child: ClipRRect(
                borderRadius: BorderRadiusGeometry.circular(20),
                child: PhotoMapView(
                  lat: exif['latitude'], lng: exif['longitude'],
                ),
              )
            )
        ],
      ),
    );
  }
  Widget infoBox({
    required IconData leadingIcon,
    required Widget centerContent,
    IconData? trailingIcon,
    VoidCallback? onClick,
  }) {
    final bool isClickable = onClick != null;
    final cursor = isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SelectionArea(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onClick,
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            mouseCursor: cursor,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
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
            ),
          ),
        ),
      ),
    );
  }
  Widget _infoColumn(BuildContext context, List<String> lines) {
    final baseStyle = DefaultTextStyle.of(context).style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lines.indexed.map((entry) => Text(
        entry.$2,
        style: entry.$1 == 0
            ? baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) + 2)
            : baseStyle,
      )).toList(),
    );
  }
}
List<String> formatAssetDate(DateTime date) {
  final offset = date.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');

  final dateLine = DateFormat('MMM d, y').format(date);
  final timeLine = DateFormat('EEE, h:mm:ss a').format(date);

  return [dateLine, '$timeLine GMT$sign$hours:$minutes'];
}


class EditPeoplePanel extends ConsumerWidget {
  final ImmichAsset asset;
  final VoidCallback onBack;
  const EditPeoplePanel({super.key, required this.asset, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 10,
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const Text('Edit People', style: TextStyle(fontSize: 24)),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: asset.people.length,
            itemBuilder: (context, i) {
              final person = asset.people.elementAt(i);
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(
                    person.thumbnailUrl(ImmichConfig.baseUrl),
                    headers: {'x-api-key': ImmichConfig.apiKey},
                  ),
                ),
                title: Text(person.name),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // inline rename, show dialog, etc.
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}