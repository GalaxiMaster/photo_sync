import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> getSystemPicturesDirectory() async {
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

extension EnumeratedIterable<T> on Iterable<T> {
  Iterable<(int, T)> get enumerate sync* {
    var i = 0;
    for (final item in this) {
      yield (i++, item);
    }
  }
}