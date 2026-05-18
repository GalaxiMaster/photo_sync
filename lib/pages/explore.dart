import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/body_provider.dart';
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
    _peopleFuture = ref.read(galleryBucketProvider.notifier).getPeople();
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
          return LayoutBuilder(
            builder: (context, constraints) {
              final itemCount = 12;
              const padding = 24.0;
              final separators = (itemCount - 1) * 12.0;
              final itemWidth = (constraints.maxWidth - padding - separators) / itemCount;

              return PersonBox(people: people, itemWidth: itemWidth);
            },
          );
        },
      ),
    );
  }
}

class PersonBox extends ConsumerWidget {
  const PersonBox({
    super.key,
    required this.people,
    required this.itemWidth,
  });

  final List<ImmichPerson> people;
  final double itemWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      child: SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: people.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final person = people[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: (){
                  ref.read(galleryBucketProvider.notifier).loadCloud(personId: person.id);
                  ref.read(appBodyProvider.notifier).goToPerson(person);
                },
                child: SizedBox(
                  width: itemWidth,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: itemWidth / 2 - 4,
                            foregroundImage: CachedNetworkImageProvider(
                              person.thumbnailUrl(ImmichConfig.baseUrl),
                              headers: {'x-api-key': ImmichConfig.apiKey},
                            ),
                            child: Text(person.name.isNotEmpty ? person.name[0] : '?'),
                          ),
                          if (person.isFavorite)
                          Positioned(
                            bottom: 5,
                            right: 10,
                            child: Icon(Icons.favorite, color: Color(0xffe4443e),),
                          )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        person.name.isEmpty ? 'Unknown' : person.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}