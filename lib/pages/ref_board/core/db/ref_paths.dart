import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where app data lives:
///   Windows:       %LOCALAPPDATA%\PhotoSync\
///                    app.db                (settings + Photo Ref tables)
///                    Reference\originals, Reference\thumbs
///   macOS / Linux: <application support dir>/PhotoSync/...
class RefPaths {
  RefPaths._(this.appRoot, this.root);

  /// …\PhotoSync
  final Directory appRoot;

  /// …\PhotoSync\Reference (image files)
  final Directory root;

  File get databaseFile => File(p.join(appRoot.path, 'app.db'));

  static const _appFolder = 'PhotoSync';
  static const _moduleFolder = 'Reference';

  static final Future<RefPaths> _instance = _resolve();
  static Future<RefPaths> get() => _instance;

  static Future<RefPaths> _resolve() async {
    final localAppData =
        Platform.isWindows ? Platform.environment['LOCALAPPDATA'] : null;
    final base = (localAppData != null && localAppData.isNotEmpty)
        ? Directory(localAppData)
        : await getApplicationSupportDirectory();
    final appRoot = Directory(p.join(base.path, _appFolder));
    final root = Directory(p.join(appRoot.path, _moduleFolder));
    await root.create(recursive: true); // also creates appRoot
    return RefPaths._(appRoot, root);
  }
}
