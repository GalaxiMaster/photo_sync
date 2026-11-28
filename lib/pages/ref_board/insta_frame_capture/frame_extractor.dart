import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

class FrameExtractor {
  FrameExtractor._(this.video, this.duration, this.fps, this._dir,
      this._previewFps, this._previewCount);

  final File video;
  final Duration duration;
  final double fps;
  final Directory _dir;
  final double _previewFps;
  final int _previewCount;

  int get totalFrames => (duration.inMilliseconds / 1000 * fps).floor();
  Duration positionOf(int frame) =>
      Duration(milliseconds: (frame * 1000 / fps).round());

  static Future<FrameExtractor> open(File video) async {
    final probe = await FFprobeKit.getMediaInformation(video.path);
    final info = probe.getMediaInformation();
    if (info == null) throw Exception('Could not read video info');

    final seconds = double.tryParse(info.getDuration() ?? '') ?? 0;
    var fps = 30.0;
    for (final s in info.getStreams()) {
      if (s.getType() == 'video') {
        final parts = (s.getAverageFrameRate() ?? '').split('/');
        final n = double.tryParse(parts.first) ?? 0;
        final d = parts.length > 1 ? double.tryParse(parts[1]) ?? 1 : 1;
        if (n > 0 && d > 0) fps = n / d;
        break;
      }
    }

    final dir = await Directory.systemTemp.createTemp('frames_');
    final previewFps =
        (300 / (seconds > 0 ? seconds : 1)).clamp(0.5, 5.0).toDouble();

    // executeWithArguments avoids shell-quoting problems with Windows paths
    final run = await FFmpegKit.executeWithArguments([
      '-y', '-i', video.path,
      '-vf', 'fps=${previewFps.toStringAsFixed(3)},scale=360:-2',
      '-q:v', '5',
      p.join(dir.path, 'p_%04d.jpg'),
    ]);
    if (!ReturnCode.isSuccess(await run.getReturnCode())) {
      throw Exception('Preview generation failed');
    }
    final count = dir
        .listSync()
        .where((f) => p.basename(f.path).startsWith('p_'))
        .length;

    return FrameExtractor._(video,
        Duration(milliseconds: (seconds * 1000).round()), fps, dir,
        previewFps, count);
  }

  File previewFor(int frame) {
    final k = ((frame / fps) * _previewFps)
            .round()
            .clamp(0, _previewCount - 1)
            .toInt() +
        1;
    return File(p.join(_dir.path, 'p_${k.toString().padLeft(4, '0')}.jpg'));
  }

  /// Exact frame at [pos]. Full resolution PNG unless [maxWidth] is given.
  Future<File> frameAt(Duration pos, {int? maxWidth, String ext = 'png'}) async {
    final out = p.join(_dir.path, 'f_${pos.inMilliseconds}_${maxWidth ?? 0}.$ext');
    if (await File(out).exists()) return File(out);

    return _enqueue(() async {
      if (await File(out).exists()) return File(out); // made while we waited
      final ss = (pos.inMilliseconds - 1).clamp(0, 1 << 31).toInt() / 1000;
      final run = await FFmpegKit.executeWithArguments([
        '-y', '-ss', ss.toStringAsFixed(3), '-i', video.path,
        '-frames:v', '1', '-an',
        if (maxWidth != null) ...['-vf', 'scale=$maxWidth:-2'],
        if (ext == 'jpg') ...['-q:v', '2'],
        '-update', '1',
        out,
      ]);
      if (!ReturnCode.isSuccess(await run.getReturnCode())) {
        throw Exception('Frame extraction failed');
      }
      return File(out);
    });
  }

  Future<void> dispose() async {
    try {
      await _dir.delete(recursive: true);
    } catch (_) {}
  }
}
Future<void> _ffmpegTail = Future.value();

Future<T> _enqueue<T>(Future<T> Function() job) {
  final c = Completer<T>();
  _ffmpegTail = _ffmpegTail.then((_) async {
    try {
      c.complete(await job());
    } catch (e, st) {
      c.completeError(e, st);
    }
  });
  return c.future;
}