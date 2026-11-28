import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/Widgets/date_popup.dart';
import 'package:photo_sync/Widgets/map_view.dart';
import 'package:photo_sync/Widgets/tag_dialogue_popups.dart';
import 'package:photo_sync/Widgets/snack_bars.dart';
import 'package:photo_sync/models/app_settings_models.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/pages/person_page.dart';
import 'package:photo_sync/provider/body_provider.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/provider/ref_providers.dart';
import 'package:intl/intl.dart';
import 'package:photo_sync/provider/people_provider.dart';
import 'package:photo_sync/provider/tag_provider.dart';
import 'package:photo_sync/services/api_service.dart';

final _placeNameProvider = FutureProvider.family<String?, (double, double)>((
  ref,
  coords,
) async {
  final (lat, lng) = coords;
  return getPlaceName(lat, lng);
});

const _referencePanelColor = Color(0xFF1A1A1A);

InputDecoration _referenceInputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Colors.white38),
  isDense: true,
  filled: true,
  fillColor: _referencePanelColor,
  border: const OutlineInputBorder(
    borderSide: BorderSide(color: Colors.white24),
  ),
  enabledBorder: const OutlineInputBorder(
    borderSide: BorderSide(color: Colors.white24),
  ),
);

class InfoPanel extends ConsumerStatefulWidget {
  final ImageAsset? asset;
  final RefItem? referenceItem;
  final ({
    VoidCallback close,
    VoidCallback? addFace,
    void Function(AssetFace?)? onFaceHover,
  })?
  functions;
  final VoidCallback? onClose;

  const InfoPanel({
    super.key,
    required ImageAsset this.asset,
    required this.functions,
  }) : referenceItem = null,
       onClose = null;

  const InfoPanel.reference({
    super.key,
    required RefItem item,
    required this.onClose,
  }) : asset = null,
       referenceItem = item,
       functions = null;

  @override
  ConsumerState<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends ConsumerState<InfoPanel> {
  final _pageController = PageController();
  final _noteController = TextEditingController();
  final _tagController = TextEditingController();
  AssetFace? _selectedFaceId;
  Timer? _noteSaveTimer;
  bool _noteLoaded = false;
  bool _noteDirty = false;

  @override
  initState() {
    super.initState();
    final referenceItem = widget.referenceItem;
    if (referenceItem != null) {
      ref.listenManual(refNoteProvider(referenceItem.id), (_, next) {
        if (!_noteLoaded && next.hasValue) {
          _noteController.text = next.value?.markdown ?? '';
          _noteLoaded = true;
        }
      }, fireImmediately: true);
    } else {
      loadAssetTags();
    }
  }

  void loadAssetTags() async {
    final asset = widget.asset!;
    if (asset.tags.isEmpty && asset.imageSources.contains(ImageSource.immich)) {
      final Set<String>? tags =
          (await ref
                  .read(galleryBucketProvider.notifier)
                  .getAssetTags(asset.id))
              ?.map<String>((t) => t.id)
              .toSet();
      if (tags == null) return;
      ref
          .read(galleryBucketProvider.notifier)
          .updateAsset(asset.id, (a) => a.copyWith(tags: {...a.tags, ...tags}));
    }
  }

  void _onNoteChanged(String _) {
    _noteDirty = true;
    _noteSaveTimer?.cancel();
    _noteSaveTimer = Timer(const Duration(milliseconds: 600), _flushNote);
  }

  Future<void> _flushNote() async {
    if (!_noteDirty) return;
    _noteDirty = false;
    try {
      await ref
          .read(refDaoProvider)
          .saveNote(widget.referenceItem!.id, _noteController.text);
    } catch (e) {
      _noteDirty = true;
      showErrorSnackbar('Could not save note: $e');
    }
  }

  Future<void> _addReferenceTag(String value) async {
    try {
      await ref.read(refDaoProvider).addTag(widget.referenceItem!.id, value);
      if (mounted) _tagController.clear();
    } catch (e) {
      showErrorSnackbar('Could not add tag: $e');
    }
  }

  Future<void> _removeReferenceTag(String tagId) async {
    try {
      await ref.read(refDaoProvider).removeTag(widget.referenceItem!.id, tagId);
    } catch (e) {
      showErrorSnackbar('Could not remove tag: $e');
    }
  }

  @override
  void dispose() {
    _noteSaveTimer?.cancel();
    if (_noteDirty) unawaited(_flushNote());
    _noteController.dispose();
    _tagController.dispose();
    _pageController.dispose();
    super.dispose();
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
    final referenceItem = widget.referenceItem;
    if (referenceItem != null) {
      return LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height,
          child: _ReferenceInfoView(
            item: referenceItem,
            onClose: widget.onClose!,
            noteController: _noteController,
            tagController: _tagController,
            onNoteChanged: _onNoteChanged,
            onAddTag: _addReferenceTag,
            onRemoveTag: _removeReferenceTag,
          ),
        ),
      );
    }

    final asset =
        ref.watch(
          galleryBucketProvider.select(
            (state) => state.buckets
                .expand((b) => b.assets ?? [])
                .expand((a) => (a as GalleryItem).list)
                .firstWhereOrNull((a) => a.id == widget.asset!.id),
          ),
        ) ??
        widget.asset!;

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
            functions: widget.functions!,
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
  final ImageAsset asset;
  final ({
    VoidCallback close,
    VoidCallback? addFace,
    void Function(AssetFace?)? onFaceHover,
  })
  functions;
  final VoidCallback onEditPeople;
  const _InfoView({
    required this.asset,
    required this.functions,
    required this.onEditPeople,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exif = asset.exifInfo;
    final mp =
        ((exif['exifImageWidth'] ?? 0) *
                (exif['exifImageHeight'] ?? 0) /
                pow(1000, 2))
            .toStringAsFixed(1);
    final sizeMiB = ((exif['fileSizeInByte'] ?? 0) / pow(1024, 2))
        .toStringAsFixed(2);
    final placeName = ref.watch(
      _placeNameProvider((exif['latitude'] ?? 0, exif['longitude'] ?? 0)),
    );
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
            _header(),
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
                      IconButton(
                        onPressed: () => functions.addFace?.call(),
                        icon: Icon(Icons.add),
                      ),
                      if (asset.people.isNotEmpty)
                        IconButton(
                          onPressed: () => onEditPeople(),
                          icon: Icon(Icons.edit),
                        ),
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
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final String personId = asset.people.elementAt(
                              index,
                            );
                            final personAsync = ref.watch(
                              personByIdProvider(personId),
                            );
                            return personAsync.when(
                              data: (person) {
                                if (person == null) {
                                  return const SizedBox.shrink();
                                }
                                return GestureDetector(
                                  onTap: () {
                                    ref
                                        .read(selectedPersonProvider.notifier)
                                        .select(person);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => Scaffold(
                                          appBar: AppBar(
                                            title: Text(person.name),
                                          ),
                                          body: PersonPage(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: MouseRegion(
                                    onHover: (_) {
                                      final face = assetFaces.value
                                          ?.firstWhereOrNull(
                                            (f) => f.personId == person.id,
                                          );
                                      if (face == null) return;
                                      functions.onFaceHover?.call(face);
                                    },
                                    onExit: (event) =>
                                        functions.onFaceHover?.call(null),
                                    cursor: SystemMouseCursors.click,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                          ),
                                          child: ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: person.thumbnailUrl(
                                                ImmichConfig.baseUrl,
                                              ),
                                              httpHeaders: {
                                                'x-api-key':
                                                    ImmichConfig.apiKey,
                                              },
                                              fit: BoxFit.contain,
                                              placeholder: (context, url) =>
                                                  const Padding(
                                                    padding: EdgeInsets.all(
                                                      16.0,
                                                    ),
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Center(
                                                        child: Icon(
                                                          Icons.error_outline,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                          size: 24,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        ),
                                        Text(person.name),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              error: (error, stack) => const SizedBox.shrink(),
                              loading: () => const SizedBox.shrink(),
                            );
                          },
                        ),
                      ),
                    ),
                  Text('Details'),
                  _infoBox(
                    leadingIcon: Icons.calendar_month_outlined,
                    centerContent: _infoColumn(
                      context,
                      formatAssetDate(asset.fileCreatedAt.toLocal()),
                    ),
                    trailingIcon: Icons.edit,
                    onClick: () async {
                      final picked = await showEditDateTimeDialog(
                        context,
                        asset.fileCreatedAt.toLocal(),
                      );
                      if (picked != null) {
                        await ref
                            .read(galleryBucketProvider.notifier)
                            .changeAssetDate(
                              asset,
                              picked.toUtc().toIso8601String(),
                            );
                      }
                    },
                  ),
                  _infoBox(
                    leadingIcon: Icons.image_outlined,
                    centerContent: _infoColumn(context, [
                      asset.originalFileName,
                      '$mp MP  ${exif['exifImageWidth']} x ${exif['exifImageHeight']}  $sizeMiB MiB',
                    ]),
                  ),
                  if (exif['make'] != null)
                    _infoBox(
                      leadingIcon: Icons.camera_alt,
                      centerContent: _infoColumn(context, [
                        '${exif['make']} ${exif['model']}',
                        if (exif['exposureTime'] != null)
                          '${exif['exposureTime']} s  𝑓/${exif['fNumber']}  ISO ${exif['iso']}',
                      ]),
                    ),
                  if (exif['lensModel'] != null)
                    _infoBox(
                      leadingIcon: Icons.camera,
                      centerContent: _infoColumn(context, [
                        '${exif['lensModel']}',
                        if (exif['focalLength'] != null)
                          '${exif['focalLength']} mm',
                      ]),
                    ),
                  _infoBox(
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
                    lat: exif['latitude'],
                    lng: exif['longitude'],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tags', style: TextStyle(fontSize: 18)),
                  Wrap(
                    children: [
                      ...tagList.maybeWhen(
                        data: (_) {
                          final flat = ref.read(tagStoreProvider.notifier).flat;
                          return asset.tags.map(
                            (tag) => Chip(
                              label: Text(
                                flat.firstWhere((t) => t.id == tag).name,
                              ),
                            ),
                          );
                        },
                        orElse: () => [],
                      ),
                      Material(
                        child: InkWell(
                          onTap: () async {
                            final tagList = await showDialog(
                              context: context,
                              builder: (context) => AddTagPopup(),
                            );
                            if (tagList != null) {
                              final allTags = ref
                                  .read(tagStoreProvider.notifier)
                                  .flat;
                              if (allTags.isEmpty)
                                return; // todo visible error messages one day

                              final Set<String> tagIds = tagList
                                  .map<String>(
                                    (tag) => allTags
                                        .firstWhere((t) => t.value == tag)
                                        .id,
                                  )
                                  .toSet();
                              await ref
                                  .read(galleryBucketProvider.notifier)
                                  .addAssetTags({asset.id}, tagIds);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 10,
                              children: [
                                Icon(Icons.sell_outlined, size: 20),
                                Text('Add tag', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    spacing: 10,
    children: [
      IconButton(
        onPressed: functions.close,
        mouseCursor: SystemMouseCursors.click,
        icon: const Icon(Icons.close),
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text('Info', style: TextStyle(fontSize: 24)),
      ),
    ],
  );
}

Widget _infoBox({
  required IconData leadingIcon,
  required Widget centerContent,
  IconData? trailingIcon,
  VoidCallback? onClick,
}) {
  final cursor = onClick != null
      ? SystemMouseCursors.click
      : SystemMouseCursors.basic;

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
                Icon(
                  leadingIcon,
                  color: const Color.fromARGB(255, 196, 199, 197),
                ),
                Expanded(child: centerContent),
                if (trailingIcon != null)
                  Icon(
                    trailingIcon,
                    color: const Color.fromARGB(255, 196, 199, 197),
                    size: 20,
                  ),
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
    children: lines.indexed
        .map(
          (entry) => Text(
            entry.$2,
            style: entry.$1 == 0
                ? baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) + 2)
                : baseStyle,
          ),
        )
        .toList(),
  );
}

class _ReferenceInfoView extends ConsumerWidget {
  final RefItem item;
  final VoidCallback onClose;
  final TextEditingController noteController;
  final TextEditingController tagController;
  final ValueChanged<String> onNoteChanged;
  final Future<void> Function(String) onAddTag;
  final Future<void> Function(String) onRemoveTag;

  const _ReferenceInfoView({
    required this.item,
    required this.onClose,
    required this.noteController,
    required this.tagController,
    required this.onNoteChanged,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  Future<void> _promptAddTag(BuildContext context) async {
    tagController.clear();
    final tag = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color.fromRGBO(19, 19, 20, 1),
        title: const Text('Add tag'),
        content: TextField(
          controller: tagController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _referenceInputDecoration('Tag name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(tagController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (tag != null && context.mounted) await onAddTag(tag);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(refItemTagsProvider(item.id));
    final note = ref.watch(refNoteProvider(item.id));

    return Container(
      color: const Color.fromRGBO(19, 19, 20, 1),
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
                  onPressed: onClose,
                  mouseCursor: SystemMouseCursors.click,
                  icon: const Icon(Icons.close),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('Info', style: TextStyle(fontSize: 24)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Details'),
                  if (item.sourceUrl != null) ...[
                    _infoBox(
                      leadingIcon: Icons.link,
                      centerContent: SelectableText(
                        item.sourceUrl!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                  if (item.bodyText != null) ...[
                    _infoBox(
                      leadingIcon: Icons.notes,
                      centerContent: SelectableText(item.bodyText!),
                    ),
                  ],
                  _infoBox(
                    leadingIcon: Icons.image_outlined,
                    centerContent: _infoColumn(context, [
                      item.itemType ?? item.kind,
                      if (item.mime != null) item.mime!,
                      if (item.width != null && item.height != null)
                        '${item.width} × ${item.height}',
                      'Added ${item.createdAt.toLocal().toString().split(' ').first}',
                      if (item.syncState == 'local_only') 'Not synced yet',
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tags'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...tags.when(
                        data: (items) => items
                            .map(
                              (tag) => Chip(
                                label: Text(tag.name),
                                onDeleted: () => onRemoveTag(tag.id),
                              ),
                            )
                            .toList(),
                        loading: () => [const CircularProgressIndicator()],
                        error: (error, _) => [
                          Text(
                            'Could not load tags: $error',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _promptAddTag(context),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 10,
                              children: [
                                Icon(Icons.sell_outlined, size: 20),
                                Text('Add tag', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Notes'),
                  if (note.hasError) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Could not load note: ${note.error}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    minLines: 5,
                    maxLines: 14,
                    onChanged: onNoteChanged,
                    decoration: _referenceInputDecoration(
                      'Why you saved this, what to study…',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
  final ImageAsset asset;
  final VoidCallback onBack;
  final void Function(AssetFace face) onEditPerson;
  const EditPeoplePanel({
    super.key,
    required this.asset,
    required this.onBack,
    required this.onEditPerson,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetFaces = ref.watch(assetFacesProvider(asset.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 10,
          children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
            const Text('Edit People', style: TextStyle(fontSize: 24)),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: asset.people.length,
            itemBuilder: (context, i) {
              final personAsync = ref.watch(
                personByIdProvider(asset.people.elementAt(i)),
              );
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
                    title: Text(
                      person.name,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            final face = assetFaces.value?.firstWhereOrNull(
                              (f) => f.personId == person.id,
                            );
                            if (face != null) onEditPerson(face);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            final face = assetFaces.value?.firstWhereOrNull(
                              (f) => f.personId == person.id,
                            );
                            if (face != null) {
                              ref
                                  .read(galleryBucketProvider.notifier)
                                  .removeFace(assetId: asset.id, face: face);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
                error: (error, stack) => const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PeopleListPanel extends ConsumerWidget {
  final ImageAsset asset;
  final VoidCallback onBack;
  final AssetFace? face;
  const PeopleListPanel({
    super.key,
    required this.asset,
    required this.onBack,
    required this.face,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleStoreProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          spacing: 10,
          children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
            Text('Edit People', style: TextStyle(fontSize: 24)),
          ],
        ),
        Expanded(
          child: peopleAsync.when(
            data: (people) {
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: .9,
                ),
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];
                  return GestureDetector(
                    onTap: () {
                      if (face == null) return;
                      ref
                          .read(galleryBucketProvider.notifier)
                          .reAssignFace(
                            assetId: asset.id,
                            face: face!,
                            newPersonId: person.id,
                          );
                      onBack();
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          child: ClipOval(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: CachedNetworkImage(
                                imageUrl: person.thumbnailUrl(
                                  ImmichConfig.baseUrl,
                                ),
                                httpHeaders: {'x-api-key': ImmichConfig.apiKey},
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                          child: Text(person.name),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            error: (error, stack) => const SizedBox.shrink(),
            loading: () => const CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }
}
