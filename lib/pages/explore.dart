import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/services/api_service.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {

  late final Future<List<ImmichPerson>> _peopleFuture;

  @override
  void initState() {
    super.initState();
    _peopleFuture = ref.read(galleryProvider.notifier).getPeople();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder<List<ImmichPerson>>(
        future: _peopleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading people: ${snapshot.error}'));
          }
          final people = snapshot.data ?? [];
          return ListView(
            children: people.map((person) => ListTile(
              leading: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(
                  person.thumbnailUrl(ImmichConfig.baseUrl),
                  headers: {'x-api-key': ImmichConfig.apiKey},
                ),
              ),
              title: Text(person.name),
              subtitle: Text('Birthdate: ${person.birthDate ?? "Unknown"}'),
            )).toList(),
          );
        },
      ),
    );
  }
}