// main_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';

enum AppBody { gallery, explore, person, tags}

class AppBodyNotifier extends Notifier<AppBody> {
  AppBody? previousPage;

  @override
  AppBody build() => AppBody.gallery;

  void switchTo(AppBody body) => state = body;
  
  void goToPerson(ImmichPerson person) {
    previousPage = state;
    ref.read(selectedPersonProvider.notifier).select(person);
    state = AppBody.person;
  }

  void goToPrevious() {
    if (previousPage == null) return;

    state = previousPage!;
    previousPage = null;
  }
}

final appBodyProvider = NotifierProvider<AppBodyNotifier, AppBody>(
  AppBodyNotifier.new,
);


class SelectedPersonNotifier extends Notifier<ImmichPerson?> {
  @override
  ImmichPerson? build() => null;

  void select(ImmichPerson person) => state = person;
  void clear() => state = null;
}

final selectedPersonProvider = NotifierProvider<SelectedPersonNotifier, ImmichPerson?>(
  SelectedPersonNotifier.new,
);