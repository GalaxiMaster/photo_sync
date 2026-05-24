import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/body_provider.dart';
import 'package:photo_sync/provider/database_providers.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/win_drives.dart';

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
  List drives = getRemovableDrives();
  List<ImmichAsset> _localAssets = [];
  bool _isScanning = false;
  String _scanStatus = '';
  String selectedTab = 'Photos';
  Timer? _timer;

  @override
  initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) { 
      if (mounted) refreshDrives(); 
    });
  }

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
    ref.read(galleryBucketProvider.notifier).loadLocal(_localAssets);
  }

  void refreshDrives() {
    setState(() => drives = getRemovableDrives());
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final storageAsync = ref.watch(serverInfoProvider);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(right: 35, top: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            menuItem(
              'Photos', 
              Icons.photo_library_rounded, 
              onClick: () {
                ref.read(appBodyProvider.notifier).switchTo(AppBody.gallery);
                ref.read(galleryBucketProvider.notifier).loadCloud();
              }
            ),
            menuItem('Explore', Icons.search, onClick: () {
              ref.read(appBodyProvider.notifier).switchTo(AppBody.explore);
            }),
            menuItem('Map', Icons.map),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Library'),
            ),
            menuItem('Favorites', Icons.favorite_outline, onClick: () async{
              ref.read(appBodyProvider.notifier).switchTo(AppBody.gallery);
              await ref.read(galleryBucketProvider.notifier).loadCloud(isFavorite: true);
            }),
            menuItem('Albums', Icons.photo_album_rounded),
            menuItem('Tags', Icons.label, onClick: () {
              ref.read(appBodyProvider.notifier).switchTo(AppBody.tags);
            }),
            menuItem('Trash', Icons.delete_outline, onClick: () async{
              ref.read(appBodyProvider.notifier).switchTo(AppBody.gallery);
              await ref.read(galleryBucketProvider.notifier).loadCloud(isTrashed: true);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Computer $_scanStatus',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  // Text(_scanStatus)
                  if (_isScanning)
                  SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator()
                  )
                ],
              ),
            ),
            for (final drive in drives)
              menuItem(
                drive['label']!, 
                Icons.usb, 
                onClick: () {
                  ref.read(appBodyProvider.notifier).switchTo(AppBody.gallery);
                  scanDrive(drive['letter']!);
                }
              ),
            Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 17, 20, 25),
                  borderRadius: BorderRadius.circular(10)
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5,
                  children: [
                    Text('Storage Space', style: TextStyle(fontSize: 14, color: Color.fromARGB(255, 218, 219, 219), fontWeight: FontWeight.bold)),
                    ...storageAsync.when(
                      data: (storage) {
                        final usedPercent = storage.diskUsedRaw / storage.diskSizeRaw;
                        return [
                          Text('${storage.diskUsed} / ${storage.diskSize}', style: TextStyle(color: Color.fromARGB(255, 218, 219, 219))),
                          SizedBox(height: 5),
                          SizedBox(
                            height: 7.5,
                            child: LinearProgressIndicator(
                              value: usedPercent,
                              color: usedPercent > 0.9 ? Colors.red : Color.fromARGB(255, 169, 204, 248),
                              backgroundColor: Color.fromARGB(255, 54, 65, 83),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          SizedBox(height: 5),
                        ];
                      },
                      loading: () => [CircularProgressIndicator()], 
                      error: (e, st) => [Text('Error loading storage info $e')]
                    )
                  ],
                ),
              ),
            )
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