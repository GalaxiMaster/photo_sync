import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/date_popup.dart';
import 'package:photo_sync/Widgets/map_view.dart';
import 'package:photo_sync/Widgets/search_popup.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:photo_sync/services/win_drives.dart';

final placeNameProvider = FutureProvider.family<String?, (double, double)>((ref, coords) async {
  final (lat, lng) = coords;
  return getPlaceName(lat, lng);
});

class InfoPanel extends ConsumerWidget {
  final ImmichAsset asset;
  final VoidCallback close;
  const InfoPanel({super.key, required this.asset, required this.close});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exif = asset.exifInfo;
    final mp = (exif['exifImageWidth'] * exif['exifImageHeight'] / pow(1000, 2)).toStringAsFixed(1);
    final sizeMiB = (exif['fileSizeInByte'] / pow(1024, 2)).toStringAsFixed(2);
    final placeName = ref.watch(placeNameProvider((exif['latitude'] ?? 0, exif['longitude'] ?? 0)));

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  centerContent: _infoColumn(context, formatAssetDate(asset.fileCreatedAt.toLocal())),
                  trailingIcon: Icons.edit,
                  onClick: () async {
                    final picked = await showEditDateTimeDialog(context, asset.fileCreatedAt.toLocal());
                    if (picked != null) {
                      await ref.read(galleryProvider.notifier).changeAssetDate(asset, picked.toUtc().toIso8601String());
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

// ------ Gallery screen sidebar

class SidebarOverlay {
  OverlayEntry? _entry;
  final _key = GlobalKey<_SidebarSheetState>();
  final _offstage = ValueNotifier<bool>(true);

  void show(BuildContext context, Widget content) {
    if (_entry == null) {
      _entry = OverlayEntry(
        builder: (_) => ValueListenableBuilder(
          valueListenable: _offstage,
          builder: (_, hidden, child) => Offstage(offstage: hidden, child: child),
          child: _SidebarSheet(
            key: _key,
            onDismiss: _removeEntry,
            child: content,
          ),
        ),
      );
      Overlay.of(context).insert(_entry!);
    }
    _offstage.value = false;
    _key.currentState?.animateIn();
  }

  Future<void> hide() async {
    await _key.currentState?._dismiss();
  }

  void _removeEntry() {
    _offstage.value = true;
  }
}

class _SidebarSheet extends StatefulWidget {
  final VoidCallback onDismiss;
  final Widget child;
  const _SidebarSheet({required this.onDismiss, required this.child, super.key});

  @override
  State<_SidebarSheet> createState() => _SidebarSheetState();
}

class _SidebarSheetState extends State<_SidebarSheet>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  late final _slide = Tween<Offset>(
    begin: const Offset(-1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final _fade = Tween<double>(begin: 0, end: 0.4)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }
  void animateIn() {
    _controller.forward(from: 0);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // greyed barrier
        FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(color: Colors.black),
          ),
        ),
        // sidebar panel
        Align(
          alignment: Alignment.centerLeft,
          child: SlideTransition(
            position: _slide,
            child: Container(
              width: 320,
              height: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

class SideBarContent extends ConsumerStatefulWidget {
  final SidebarOverlay? overlayController;
  const SideBarContent({super.key, this.overlayController});
  @override
  // ignore: library_private_types_in_public_api
  _SideBarContentState createState() => _SideBarContentState();
}

class _SideBarContentState extends ConsumerState<SideBarContent> {
  final drives = getRemovableDrives();
  List<ImmichAsset> _localAssets = [];
  bool _isScanning = false;
  String _scanStatus = '';
  String selectedTab = 'Photos';

  Future<void> scanDrive(String driveLetter) async {
    setState(() => _isScanning = true);

    final assets = await scanDriveAssets( // todo make this cancellable
      '$driveLetter\\',
      onProgress: (path, found) {
        setState(() => _scanStatus = 'Found $found files... $path');
      },
    );

    setState(() {
      _localAssets = assets;
      _isScanning = false;
      _scanStatus = 'Done — ${assets.length} files found';
    });
    ref.read(galleryProvider.notifier).loadLocal(_localAssets);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(right: 50, top: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            menuItem('Photos', Icons.photo_library_rounded, onClick: () => ref.read(galleryProvider.notifier).loadCloud()),
            menuItem('Explore', Icons.search),
            menuItem('Map', Icons.map),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Library'),
            ),
            menuItem('Favorites', Icons.favorite_outline, onClick: () {
              final searchOptions = SearchOptions(
                query: '',
                searchType: SearchType.fileName,
                favorited: true,
              );
              ref.read(galleryProvider.notifier).searchFromOptions(searchOptions, force: true);
            }),
            menuItem('Albums', Icons.photo_album_rounded),
            menuItem('Tags', Icons.label),
            menuItem('Trash', Icons.delete_outline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Computer'),
                  Text(_scanStatus)
                ],
              ),
            ),
            for (final drive in drives)
              menuItem(drive['label']!, Icons.usb, onClick: () => scanDrive(drive['letter']!)),
          ]
        ),
      )
    );
  }
  Widget menuItem(String label, IconData icon, {Function? onClick}) {
    final bool selected = label == selectedTab;
    return ClipRRect(
      borderRadius: BorderRadius.only(topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
      child: Material(
        color: selected ? Color.fromARGB(200, 17, 20, 25) : Colors.transparent,
        child: InkWell(
          onTap: () async {
            await onClick?.call();
            setState(() => selectedTab = label);
            widget.overlayController?.hide();
          },
          hoverColor: Colors.white.withValues(alpha: 0.05),
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            child: Row(
              spacing: 15,
              children: [
                Icon(icon, color: selected ? Color.fromARGB(255, 169, 204, 248) : Color.fromARGB(200, 218, 219, 219),),
                Text(label)
              ],
            ),
          )
        ),
      ),
    );
  }
}