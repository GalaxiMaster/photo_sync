import 'dart:io';
import 'dart:ui';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _getSystemPicturesDirectory() async {
  final Map<String, String> env = Platform.environment;
  
  if (Platform.isWindows) {
    // Standard Windows: C:\Users\<User>\Pictures
    if (env.containsKey('USERPROFILE')) {
      return Directory(p.join(env['USERPROFILE']!, 'Pictures'));
    }
  } else if (Platform.isMacOS) {
    // Standard macOS: /Users/<User>/Pictures
    if (env.containsKey('HOME')) {
      return Directory(p.join(env['HOME']!, 'Pictures'));
    }
  } else if (Platform.isLinux) {
    // Linux standard fallback path
    if (env.containsKey('HOME')) {
      return Directory(p.join(env['HOME']!, 'Pictures'));
    }
  }
  
  return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
}

Future<Directory> getLocalPhotoDirectory() async {
  final baseDir = await _getSystemPicturesDirectory();
  final saveDirPath = p.join(baseDir.path, 'MyGalleryApp');
  final saveDir = Directory(saveDirPath);
  
  if (!await saveDir.exists()) {
    await saveDir.create(recursive: true);
  }
  
  return saveDir;
}

extension EnumeratedIterable<T> on Iterable<T> {
  Iterable<(int, T)> get enumerate sync* {
    var i = 0;
    for (final item in this) {
      yield (i++, item);
    }
  }
}

Color? hexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

extension Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}