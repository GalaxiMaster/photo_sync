import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ResolvedVideo {
  ResolvedVideo(this.file, this.serverJobId, {this.caption, this.uploader, this.duration});
  final File file;
  final String serverJobId;
  final String? caption, uploader;
  final double? duration;
}

class ServerResolver {
  ServerResolver(String baseUrl, String token)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(minutes: 2),
        ));
  final Dio _dio;

  Future<ResolvedVideo> resolve(String url, {void Function(double)? onProgress}) async {
    final res = await _dio.post('/resolve', data: {'url': url});
    final d = res.data as Map<String, dynamic>;

    final tmp = await getTemporaryDirectory();
    final path = p.join(tmp.path, 'reel_${d['id']}.mp4');
    await _dio.download(d['videoPath'], path, onReceiveProgress: (got, total) {
      if (total > 0) onProgress?.call(got / total);
    });
    // free the server's copy
    unawaited(_dio.delete(d['videoPath']).catchError((_) {}));

    return ResolvedVideo(File(path), d['id'],
        caption: d['caption'], uploader: d['uploader'],
        duration: (d['duration'] as num?)?.toDouble());
  }
}