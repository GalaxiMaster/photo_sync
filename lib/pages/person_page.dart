import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/pages/gallary_screen.dart';
import 'package:photo_sync/provider/body_provider.dart';
import 'package:photo_sync/services/api_service.dart';

class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({super.key});

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);

    if (person == null) return const SizedBox.shrink();
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 50,
                  foregroundImage: CachedNetworkImageProvider(
                    person.thumbnailUrl(ImmichConfig.baseUrl),
                    headers: {'x-api-key': ImmichConfig.apiKey},
                  ),
                  child: Text(person.name.isNotEmpty ? person.name[0] : '?'),
                ),
                const SizedBox(width: 15),
                Text(
                  person.name.isEmpty ? 'Unknown' : person.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 30),
                ),
              ],
            ),
          ),
          GalleryScreen()
        ],
      )
    );
  }
}
