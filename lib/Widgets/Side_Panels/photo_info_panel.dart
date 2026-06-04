import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/date_popup.dart';
import 'package:photo_sync/Widgets/map_view.dart';
import 'package:photo_sync/Widgets/tag_dialogue_popups.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/pages/person_page.dart';
import 'package:photo_sync/provider/body_provider.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:intl/intl.dart';
import 'package:photo_sync/provider/people_provider.dart';
import 'package:photo_sync/provider/tag_provider.dart';
import 'package:photo_sync/services/api_service.dart';

final _placeNameProvider = FutureProvider.family<String?, (double, double)>((ref, coords) async {
  final (lat, lng) = coords;
  return getPlaceName(lat, lng);
});

class InfoPanel extends ConsumerStatefulWidget {
  final ImmichAsset asset;
  final ({VoidCallback close, VoidCallback addFace, void Function(AssetFace?) onFaceHover}) functions;
  const InfoPanel({super.key, required this.asset, required this.functions});

  @override
  ConsumerState<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends ConsumerState<InfoPanel> {
  final _pageController = PageController();
  AssetFace? _selectedFaceId;

  @override
  initState() {
    super.initState();
    loadAssetTags();
  }
  void loadAssetTags() async {
    if (widget.asset.tags.isEmpty) {
      final Set<String>? tags = (await ref.read(galleryBucketProvider.notifier).getAssetTags(widget.asset.id))?.map<String>((t) => t.id).toSet();
      if (tags == null) return;
      ref.read(galleryBucketProvider.notifier).updateAsset(widget.asset.id, (a) => a.copyWith(
        tags: {...a.tags, ...tags},
      ));
    }
  }

  void _goTo(int index) => _pageController.animateToPage( 
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeInOutCubic,
  );

  void _goToPersonList(AssetFace faceId) {
    setState(() {
      _selectedFaceId = faceId;
    });
    _goTo(2);
  }

  @override
  Widget build(BuildContext context) {
    final asset = ref.watch(galleryBucketProvider.select((state) => state.buckets
      .expand((b) => b.assets ?? [])
      .expand((a) => (a as GalleryItem).list)
      .firstWhereOrNull((a) => a.id == widget.asset.id)
    )) ?? widget.asset;
    return Container(
      color: const Color.fromRGBO(19, 19, 20, 1),
      padding: const EdgeInsets.all(8),
      width: 400,
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _InfoView(
            asset: asset,
            functions: widget.functions,
            onEditPeople: () => _goTo(1),
          ),
          EditPeoplePanel(
            asset: asset,
            onBack: () => _goTo(0),
            onEditPerson: (faceId) => _goToPersonList(faceId),
          ),
          PeopleListPanel(
            asset: asset,
            face: _selectedFaceId,
            onBack: () => _goTo(1),
          ),
        ],
      ),
    );
  }
}

class _InfoView extends ConsumerWidget {
  final ImmichAsset asset;
  final ({VoidCallback close, VoidCallback addFace, void Function(AssetFace?) onFaceHover}) functions;
  final VoidCallback onEditPeople;
  const _InfoView({required this.asset, required this.functions, required this.onEditPeople});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exif = asset.exifInfo;
    final mp = (exif['exifImageWidth'] * exif['exifImageHeight'] / pow(1000, 2)).toStringAsFixed(1);
    final sizeMiB = (exif['fileSizeInByte'] / pow(1024, 2)).toStringAsFixed(2);
    final placeName = ref.watch(_placeNameProvider((exif['latitude'] ?? 0, exif['longitude'] ?? 0)));
    final assetFaces = ref.watch(assetFacesProvider(asset.id));
    final tagList = ref.watch(tagStoreProvider);

    return Container(
      color: Color.fromRGBO(19, 19, 20, 1),
      padding: const EdgeInsets.all(8),
      width: 400,
      child: SingleChildScrollView(
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
                          final String personId = asset.people.elementAt(index);
                          final personAsync = ref.watch(personByIdProvider(personId));
                          return personAsync.when(
                            data: (person) {
                              if (person == null) return const SizedBox.shrink();
                              return GestureDetector(
                                onTap: () {
                                  ref.read(selectedPersonProvider.notifier).select(person);
                                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => Scaffold(
                                    appBar: AppBar(title: Text(person.name)),
                                    body: PersonPage(),
                                  )));
                                },
                                child: MouseRegion(
                                  onHover: (_) {
                                    final face = assetFaces.value?.firstWhereOrNull((f) => f.personId == person.id);
                                    if (face == null) return;
                                    functions.onFaceHover(face);
                                  },
                                  onExit: (event) => functions.onFaceHover(null),
                                  cursor: SystemMouseCursors.click,
                                  child: Column(
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
                                            imageUrl: person.thumbnailUrl(ImmichConfig.baseUrl),
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
                                  ),
                                ),
                              );
                            }, 
                            error: (error, stack) => const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink()
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
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tags', style: TextStyle(fontSize: 18),),
                  Wrap(
                    children: [
                      ...tagList.maybeWhen(
                        data: (_) {
                          final flat = ref.read(tagStoreProvider.notifier).flat;
                          return asset.tags.map((tag)=> Chip(label: Text(flat.firstWhere((t) => t.id == tag).name),));
                        },
                        orElse: ()=> [],
                      ),
                      Material(
                        child: InkWell(
                          onTap: () async {
                            final tagList = await showDialog(context: context, builder: (context) => AddTagPopup());
                            if (tagList != null) {
                              final allTags = ref.read(tagStoreProvider.notifier).flat;
                              if (allTags.isEmpty) return; // todo visible error messages one day

                              final Set<String> tagIds = tagList.map<String>((tag) => allTags.firstWhere((t) => t.value == tag).id).toSet();
                              await ref.read(galleryBucketProvider.notifier).addAssetTags({asset.id}, tagIds);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 10,
                              children: [
                                Icon(Icons.sell_outlined, size: 20,),
                                Text('Add tag', style: TextStyle(fontSize: 16),),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
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
  final void Function(AssetFace face) onEditPerson;
  const EditPeoplePanel({super.key, required this.asset, required this.onBack, required this.onEditPerson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetFaces = ref.watch(assetFacesProvider(asset.id));

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
              final personAsync = ref.watch(personByIdProvider(asset.people.elementAt(i)));
              return personAsync.when(
                data: (person) {
                  if (person == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(
                        person.thumbnailUrl(ImmichConfig.baseUrl),
                        headers: {'x-api-key': ImmichConfig.apiKey},
                      ),
                    ),
                    title: Text(person.name, style: TextStyle(fontSize: 18, color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            final face = assetFaces.value?.firstWhereOrNull((f) => f.personId == person.id);
                            if (face != null) onEditPerson(face);
                          }
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                            final face = assetFaces.value?.firstWhereOrNull((f) => f.personId == person.id);
                            if (face != null) {
                              ref.read(galleryBucketProvider.notifier).removeFace(
                                assetId: asset.id, 
                                face: face
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }, 
                error: (error, stack) => const SizedBox.shrink(),
                loading: () => const SizedBox.shrink()
              );
            },
          ),
        ),
      ],
    );
  }
}

class PeopleListPanel extends ConsumerWidget {
  final ImmichAsset asset;
  final VoidCallback onBack;
  final AssetFace? face;
  const PeopleListPanel({super.key, required this.asset, required this.onBack, required this.face});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleStoreProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          spacing: 10,
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            Text('Edit People', style: TextStyle(fontSize: 24)),
          ],
        ),
        Expanded(
          child: peopleAsync.when(
            data: (people) {
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .9),
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];
                  return GestureDetector(
                    onTap: () {
                      if (face == null) return;
                      ref.read(galleryBucketProvider.notifier).reAssignFace(assetId: asset.id, face: face!, newPersonId: person.id);
                      onBack();
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: ClipOval(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: CachedNetworkImage(
                                imageUrl: person.thumbnailUrl(ImmichConfig.baseUrl),
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
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Text(person.name)
                        )
                      ],
                    ),
                  );
                }
              );
            }, 
            error: (error, stack) => const SizedBox.shrink(),
            loading: () => const CircularProgressIndicator()
            ),
        ),
      ],
    );
  }
}