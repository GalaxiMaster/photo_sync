import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/pages/home.dart';
import 'package:photo_sync/provider/ref_providers.dart';
import 'package:photo_sync/models/blob_store.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  final refBlobs = await BlobStore.open();
  runApp(
    ProviderScope(
      overrides: [
        refBlobStoreProvider.overrideWithValue(refBlobs)
      ],
      child: App(),
    ),
  );
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Immich Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(),
      ),
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const MainApp(),
    );
  }
}