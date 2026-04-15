import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:photo_sync/pages/gallary_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  await dotenv.load(fileName: ".env");

  runApp(
    const ProviderScope(
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
      home: const GalleryScreen(),
    );
  }
}