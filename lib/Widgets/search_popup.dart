import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';

enum SearchType {
  context('Context'),
  fileName('File name or extension'),
  description('Description'),
  ocr('OCR');

  const SearchType(this.label);
  final String label;
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

  PlaceFilter({this.country, this.state, this.city});
}

class CameraFilter {
  final String? make;
  final String? model;
  final String? lens;

  CameraFilter({this.make, this.model, this.lens});
}

class SearchOptions {
  final String query;
  final SearchType searchType;
  final MediaType? mediaType;
  final bool? untagged;
  final Set<DisplayOption>? display;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String>? tags;
  final PlaceFilter? placeFilter;
  final CameraFilter? cameraFilter;

  SearchOptions({
    required this.query,
    required this.searchType, 
    this.mediaType, 
    this.untagged, 
    this.display, 
    this.startDate, 
    this.endDate, 
    this.tags, 
    this.placeFilter,
    this.cameraFilter,
  });
}



final searchSuggestionsProvider = FutureProvider<SearchSuggestions>((ref) async {
  final repo = ref.read(immichServiceProvider);
  return repo.getSearchSuggestions();
});



Future<SearchOptions?> showSearchOptionsDialog(BuildContext context) async {
  final SearchOptions? searchOptions = await showDialog(
    context: context,
    builder: (context) => const SearchOptionsDialog(),
  );
  return searchOptions;
}


class SearchOptionsDialog extends ConsumerStatefulWidget {
  const SearchOptionsDialog({super.key});

  @override
  ConsumerState<SearchOptionsDialog> createState() => _SearchOptionsDialogState();
}

class _SearchOptionsDialogState extends ConsumerState<SearchOptionsDialog> {
  SearchType _searchType = SearchType.context;
  MediaType _mediaType = MediaType.all;
  bool _untagged = false;
  final Set<DisplayOption> _displayOptions = {};

  // Date controllers
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _queryController = TextEditingController();

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
                    _buildPeopleSection(),
                    const Divider(color: Colors.white12),
                    _buildSearchTypeSection(),
                    const Divider(color: Colors.white12),
                    _buildTagsSection(),
                    const Divider(color: Colors.white12),
                    _buildPlaceSection(),
                    const Divider(color: Colors.white12),
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
          children: SearchType.values.map((type) {
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
        if (_searchType == SearchType.context) ...[
          const SizedBox(height: 8),
          const Text(
            'Search by context',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildTextField(_queryController, 'Sunrise on the beach'),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Tags',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildDropdown('Search tags...'),
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
            Expanded(child: _buildDropdown('Search country...', items: suggestionsAsync.value?[0])),
            const SizedBox(width: 8),
            Expanded(child: _buildDropdown('Search state...', items: suggestionsAsync.value?[1])),
            const SizedBox(width: 8),
            Expanded(child: _buildDropdown('Search city...', items: suggestionsAsync.value?[2])),
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
            Expanded(child: _buildDropdown('Search camera make...', items: suggestionsAsync.value?[0])),
            const SizedBox(width: 8),
            Expanded(child: _buildDropdown('Search camera model...', items: suggestionsAsync.value?[1])),
            const SizedBox(width: 8),
            Expanded(child: _buildDropdown('Search lens model...', items: suggestionsAsync.value?[2])),
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
              child: Column(
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
                ],
              ),
            ),
            // Display options
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
                Navigator.of(context).pop(SearchOptions(
                query: _queryController.text,
                searchType: _searchType,
                mediaType: _mediaType,
                untagged: _untagged,
                display: _displayOptions,
                startDate: parseDate(_startDateController.text.replaceAll(' ', '')),
                endDate: parseDate(_endDateController.text.replaceAll(' ', '')),
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

  Widget _buildDropdown(String hint, {List? items}) {
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
          (country) => DropdownMenuItem(
            value: country,
            child: Text(country),
          ),
        ),
        const DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
      ] : [],
      onChanged: (_) {},
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