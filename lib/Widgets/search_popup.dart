import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/provider/tag_provider.dart';

enum SearchType {
  context('Context', false),
  fileName('File name or extension', true),
  description('Description', true),
  ocr('OCR', false);

  const SearchType(this.label, this.localSearchSafe);
  final String label;
  final bool localSearchSafe;
}

enum MediaType {
  all('All'),
  image('Image'),
  video('Video');

  const MediaType(this.label);
  final String label;
}

enum DisplayOption {
  notInAlbum('Not in any album'),
  archive('Archive'),
  favorites('Favorites');

  const DisplayOption(this.label);
  final String label;
}

class PlaceFilter {
  final String? country;
  final String? state;
  final String? city;

  const PlaceFilter({this.country, this.state, this.city});

  PlaceFilter copyWith({
    String? country,
    String? state,
    String? city,
  }) => PlaceFilter(
    country: country ?? this.country,
    state: state ?? this.state,
    city: city ?? this.city,
  );

  bool isEmpty() {
    return country == null && state == null && city == null;
  }

  PlaceFilter clearCountry() => PlaceFilter(state: state, city: city);
  PlaceFilter clearState() => PlaceFilter(country: country, city: city);
  PlaceFilter clearCity() => PlaceFilter(country: country, state: state);
}

class CameraFilter {
  final String? make;
  final String? model;
  final String? lens;

  const CameraFilter({this.make, this.model, this.lens});

  CameraFilter copyWith({
    String? make,
    String? model,
    String? lens,
  }) => CameraFilter(
    make: make ?? this.make,
    model: model ?? this.model,
    lens: lens ?? this.lens,
  );

  bool isEmpty() {
    return lens == null && model == null && make == null;
  }

  CameraFilter clearMake() => CameraFilter(model: model, lens: lens);
  CameraFilter clearModel() => CameraFilter(make: make, lens: lens);
  CameraFilter clearLens() => CameraFilter(make: make, model: model);
}

enum SortOrder {
  desc('Descending'),
  asc('Ascending');

  const SortOrder(this.label);
  final String label;
}

class SearchOptions { // todo add device ID & image source
  final String query;
  final SearchType searchType;
  final MediaType? mediaType;
  final bool? untagged;
  final Set<DisplayOption>? display;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> tags;
  final PlaceFilter placeFilter;
  final CameraFilter cameraFilter;
  final bool? isFavorite;
  final SortOrder sortOrder;
  final bool? isTrashed;
  final Set<String> personIds;

  SearchOptions({
    this.query = '',
    this.searchType = SearchType.fileName, 
    this.sortOrder = SortOrder.desc,
    this.mediaType, 
    this.untagged, 
    this.display, 
    this.startDate, 
    this.endDate, 
    this.placeFilter = const PlaceFilter(),
    this.cameraFilter = const CameraFilter(), 
    this.isFavorite, 
    this.isTrashed, 
    this.tags = const {}, 
    this.personIds = const {},
  });

  bool isEmpty() {
    return query.isEmpty &&
      mediaType == null &&
      untagged != true &&
      (display == null || display!.isEmpty) &&
      startDate == null &&
      endDate == null &&
      tags.isEmpty &&
      placeFilter.isEmpty() &&
      cameraFilter.isEmpty() &&
      isFavorite != true &&
      isTrashed != true;
  }

  SearchOptions copyWith({
    String? query,
    SearchType? searchType,
    MediaType? mediaType,
    bool? untagged,
    Set<DisplayOption>? display,
    DateTime? startDate,
    DateTime? endDate,
    Set<String>? tags,
    PlaceFilter? placeFilter,
    CameraFilter? cameraFilter,
    bool? isFavorite,
    SortOrder? sortOrder,
    bool? isTrashed,
    Set<String>? personIds,
  }) => SearchOptions(
    query: query ?? this.query,
    searchType: searchType ?? this.searchType,
    mediaType: mediaType ?? this.mediaType,
    untagged: untagged ?? this.untagged,
    display: display ?? this.display,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    tags: tags ?? this.tags,
    placeFilter: placeFilter ?? this.placeFilter,
    cameraFilter: cameraFilter ?? this.cameraFilter,
    isFavorite: isFavorite ?? this.isFavorite,
    sortOrder: sortOrder ?? this.sortOrder,
    isTrashed: isTrashed ?? this.isTrashed,
    personIds: personIds ?? this.personIds,
  );
}



final searchSuggestionsProvider = FutureProvider<SearchSuggestions>((ref) async {
  final repo = ref.read(immichServiceProvider);
  return repo.getSearchSuggestions();
});



Future<SearchOptions?> showSearchOptionsDialog(BuildContext context, {SearchOptions? initialSettings, bool localSearch = false}) async {
  final SearchOptions? searchOptions = await showDialog(
    context: context,
    builder: (context) => SearchOptionsDialog(initialSettings: initialSettings, localSearch: localSearch),
  );
  return searchOptions;
}


class SearchOptionsDialog extends ConsumerStatefulWidget {
  final SearchOptions? initialSettings;
  final bool localSearch;
  const SearchOptionsDialog({super.key, this.initialSettings, this.localSearch = false});

  @override
  ConsumerState<SearchOptionsDialog> createState() => _SearchOptionsDialogState();
}

class _SearchOptionsDialogState extends ConsumerState<SearchOptionsDialog> {
  SearchType _searchType = SearchType.context;
  MediaType _mediaType = MediaType.all;
  SortOrder _sortOrder = SortOrder.desc;
  bool _untagged = false;
  Set<DisplayOption> _displayOptions = {};
  PlaceFilter _placeFilter = const PlaceFilter();
  CameraFilter _cameraFilter = const CameraFilter();
  Set<String> _tags = {};

  // Date controllers
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchType = widget.initialSettings?.searchType ?? (widget.localSearch ? SearchType.fileName : _searchType);
    _mediaType = widget.initialSettings?.mediaType ?? _mediaType;
    _untagged = widget.initialSettings?.untagged ?? _untagged;
    _displayOptions = widget.initialSettings?.display ?? _displayOptions;
    _placeFilter = widget.initialSettings?.placeFilter ?? _placeFilter;
    _cameraFilter = widget.initialSettings?.cameraFilter ?? _cameraFilter;
    _sortOrder = widget.initialSettings?.sortOrder ?? _sortOrder;
    _tags = _tags = Set<String>.from(widget.initialSettings?.tags ?? _tags);


    if (widget.initialSettings?.startDate != null) {
      _startDateController.text = DateFormat("dd / mm / yyyy").format(widget.initialSettings!.startDate!);
    }
    if (widget.initialSettings?.endDate != null) {
      _endDateController.text = DateFormat("dd / mm / yyyy").format(widget.initialSettings!.endDate!);
    }
    _queryController.text = widget.initialSettings?.query ?? '';
  }
  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2023),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.localSearch) ...[
                      _buildPeopleSection(),
                      const Divider(color: Colors.white12),
                    ],
                    _buildSearchTypeSection(),
                    const Divider(color: Colors.white12),
                    if (!widget.localSearch) ...[
                      _buildTagsSection(),
                      const Divider(color: Colors.white12),
                    ],
                    if (!widget.localSearch) ...[
                      _buildPlaceSection(),
                      const Divider(color: Colors.white12),
                    ],
                    _buildCameraSection(),
                    const Divider(color: Colors.white12),
                    _buildDateSection(),
                    const Divider(color: Colors.white12),
                    _buildMediaAndDisplaySection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          const Icon(Icons.tune, color: Colors.white),
          const SizedBox(width: 12),
          const Text(
            'Search options',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'People',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.search, size: 16, color: Colors.white54),
              label: const Text(
                'Filter people',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        // Add people chips here
        TextButton(
          onPressed: () {},
          child: const Text(
            '→ See all people',
            style: TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Search type',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          children: (widget.localSearch ? SearchType.values.where((t) => t.localSearchSafe) : SearchType.values).map((type) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<SearchType>(
                  value: type,
                  groupValue: _searchType,
                  onChanged: (v) => setState(() => _searchType = v!),
                  activeColor: Colors.blue,
                ),
                Text(type.label, style: const TextStyle(color: Colors.white70)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        const Text(
          'Search by context',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          _queryController, 
          switch (_searchType) {
            SearchType.context => 'Sunrise on the beach',
            SearchType.fileName => 'i.e. IMG_1234.JPG or PNG',
            SearchType.description => 'Hiking day to chinamans cave',
            SearchType.ocr => 'Burger',
          }
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTagsSection() {
    final tagsAsync = ref.watch(tagStoreProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Tags',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2F33),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildDropdown(
            'Search tags...', 
            items: tagsAsync.asData?.value.expand((t) => t.flatten()).map((tag)=> tag.value).toList(),
            onChange: (tag) {
              if (tag != null) {
                setState(() {
                  if (_tags.contains(tag)) {
                    _tags.remove(tag);
                  } else {
                    _tags.add(tag);
                  }
                });
              }
            }
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            children: _tags.map((tag) {
              return TagChip(tag: tag, onDelete: ()=> setState(()=>_tags.remove(tag)));
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _untagged,
              onChanged: (v) => setState(() => _untagged = v!),
              side: const BorderSide(color: Colors.white54),
              activeColor: Colors.blue,
            ),
            const Text('Untagged', style: TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlaceSection() {
    final suggestionsAsync = ref.watch(
      searchSuggestionsProvider.select((value) => value.whenData((s) => [s.countries, s.states, s.cities])),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Place',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                'Search country...', 
                items: suggestionsAsync.value?[0],
                intialValue: _placeFilter.country,
                onChange: (value) {
                  if (value != null) {
                    _placeFilter = _placeFilter.copyWith(country: value);
                  } else {
                    _placeFilter = _placeFilter.clearCountry();
                  }
                }
              )
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdownField(
                'Search state...', 
                items: suggestionsAsync.value?[1],
                intialValue: _placeFilter.state,
                onChange: (value) {
                  if (value != null) {
                    _placeFilter = _placeFilter.copyWith(state: value);
                  } else {
                    _placeFilter = _placeFilter.clearState();
                  }
                }
              )
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdownField(
                'Search city...', items: suggestionsAsync.value?[2],
                intialValue: _placeFilter.city,
                onChange: (value) {
                  if (value != null) {
                    _placeFilter = _placeFilter.copyWith(city: value);
                  } else {
                    _placeFilter = _placeFilter.clearCity();
                  }
                }
              )
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCameraSection() {
    final suggestionsAsync = ref.watch(
      searchSuggestionsProvider.select((value) => value.whenData((s) => [s.cameraMakes, s.cameraModels, s.lensModels])),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Camera',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                'Search camera make...', 
                items: suggestionsAsync.value?[0],
                intialValue: _cameraFilter.make,
                onChange: (value) {
                  if (value != null) {
                    _cameraFilter = _cameraFilter.copyWith(make: value);
                  } else {
                    _cameraFilter = _cameraFilter.clearMake();
                  }
                },
              )
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdownField(
                'Search camera model...', 
                items: suggestionsAsync.value?[1],
                intialValue: _cameraFilter.model,
                onChange: (value) {
                  if (value != null) {
                    _cameraFilter = _cameraFilter.copyWith(model: value);
                  } else {
                    _cameraFilter = _cameraFilter.clearModel();
                  }
                }
              )
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdownField(
                'Search lens model...', 
                items: suggestionsAsync.value?[2],
                intialValue: _cameraFilter.lens,
                onChange: (value) {
                  if (value != null) {
                    _cameraFilter = _cameraFilter.copyWith(lens: value);
                  } else {
                    _cameraFilter = _cameraFilter.clearLens();
                  }
                }
              )
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start date',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDateField(_startDateController),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'End date',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDateField(_endDateController),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMediaAndDisplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column( // todo make wrap if display settings arent there due to local search
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Media type',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    children: MediaType.values.map((type) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<MediaType>(
                            value: type,
                            groupValue: _mediaType,
                            onChanged: (v) => setState(() => _mediaType = v!),
                            activeColor: Colors.blue,
                          ),
                          Text(
                            type.label,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 4),
                        ],
                      );
                    }).toList(),
                  ),
                  const Text(
                    'Sort order',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    children: SortOrder.values.map((order) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<SortOrder>(
                            value: order,
                            groupValue: _sortOrder,
                            onChanged: (v) => setState(() => _sortOrder = v!),
                            activeColor: Colors.blue,
                          ),
                          Text(
                            order.label,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 4),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Display options
            if (!widget.localSearch)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Display options',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    children: DisplayOption.values.map((opt) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _displayOptions.contains(opt),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _displayOptions.add(opt);
                              } else {
                                _displayOptions.remove(opt);
                              }
                            }),
                            side: const BorderSide(color: Colors.white54),
                            activeColor: Colors.blue,
                          ),
                          Text(
                            opt.label,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _clearAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Clear all'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop((widget.initialSettings ?? SearchOptions()).copyWith(
                  query: _queryController.text,
                  searchType: _searchType,
                  mediaType: _mediaType,
                  untagged: _untagged,
                  display: _displayOptions,
                  startDate: parseDate(_startDateController.text.replaceAll(' ', '')),
                  endDate: parseDate(_endDateController.text.replaceAll(' ', '')),
                  placeFilter: _placeFilter,
                  cameraFilter: _cameraFilter,
                  sortOrder: _sortOrder,
                  tags: _tags.map((e) => ref.read(tagStoreProvider.notifier).getIdFromPath(e)?.id).whereType<String>().toSet(),
                ));
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Search',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _searchType = SearchType.context;
      _mediaType = MediaType.all;
      _untagged = false;
      _displayOptions.clear();
      _startDateController.clear();
      _endDateController.clear();
    });
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF2C2F33),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdownField(String hint, {List? items, String? intialValue, Function(String? value)? onChange}) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF2C2F33),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      dropdownColor: const Color(0xFF2C2F33),
      style: const TextStyle(color: Colors.white),
      items: items != null ? [
        const DropdownMenuItem(value: null, child: Text('Any')), // optional clear option
        ...items.map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          ),
        ),
        const DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
      ] : [],
      initialValue: intialValue,
      onChanged: (newValue) {
        onChange?.call(newValue);
      },
    );
  }

  Widget _buildDropdown(String hint, {List? items, Function(String? value)? onChange}) {
    return DropdownButton<String>(
      isExpanded: true,
      value: null,
      hint: Text(hint, style: const TextStyle(color: Colors.white38)),
      dropdownColor: const Color(0xFF2C2F33),
      style: const TextStyle(color: Colors.white),
      underline: const SizedBox(),
      items: items != null ? [
        ...items.map((item) => DropdownMenuItem(value: item, child: Text(item))),
      ] : [],
      onChanged: (newValue) => onChange?.call(newValue),
    );
  }

  Widget _buildDateField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: Colors.white70),
      decoration: InputDecoration(
        hintText: 'dd / mm / yyyy',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF2C2F33),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        suffixIcon: const Icon(
          Icons.calendar_today,
          color: Colors.white38,
          size: 18,
        ),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) => Theme(
            data: ThemeData.dark(),
            child: child!,
          ),
        );
        if (picked != null) {
          controller.text =
              '${picked.day.toString().padLeft(2, '0')} / '
              '${picked.month.toString().padLeft(2, '0')} / '
              '${picked.year}';
        }
      },
    );
  }
}

DateTime? parseDate(String input) {
  final parts = input.split('/');
  if (parts.length != 3) return null;
  
  final day = int.tryParse(parts[0].trim());
  final month = int.tryParse(parts[1].trim());
  final year = int.tryParse(parts[2].trim());
  
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

class TagChip extends StatefulWidget {
  final String tag;
  final VoidCallback onDelete;
  const TagChip({required this.tag, required this.onDelete, super.key});

  @override
  State<TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<TagChip> {
  final _hovering = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hovering.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Container(
        height: 25,
        decoration: BoxDecoration(
          borderRadius: BorderRadiusGeometry.only(topRight: Radius.circular(15), bottomRight: Radius.circular(15)),
          color: Colors.blue.shade300,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.only(left: 8),
              child: Text(widget.tag, style: const TextStyle(color: Colors.black)),
            ),
            MouseRegion(
              onEnter: (_) => _hovering.value = true,
              onExit: (_) => _hovering.value = false,
              child: ClipRRect(
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _hovering,
                    builder: (_, hovering, _) => Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: hovering ? Colors.blue.shade400 :Colors.blue.shade300,
                        borderRadius: BorderRadiusGeometry.only(topRight: Radius.circular(15), bottomRight: Radius.circular(15)),
                      ),
                      child: Icon(Icons.close, size: 14, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}