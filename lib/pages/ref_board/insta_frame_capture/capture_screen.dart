import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_sync/pages/ref_board/insta_frame_capture/frame_extractor.dart';
import 'package:photo_sync/pages/ref_board/insta_frame_capture/model.dart';
import 'package:photo_sync/pages/ref_board/insta_frame_capture/settings.dart';

class CapturedFrame {
  CapturedFrame(this.file, this.position);
  final File file;
  final Duration position;
}

typedef SaveFrames = Future<void> Function(
    ResolvedVideo video, String url, List<CapturedFrame> frames);

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, required this.onSave, required this.url});
  final SaveFrames onSave;
  final String url; // later: from the Android share intent

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  ResolvedVideo? _video;
  FrameExtractor? _fx;
  final _frames = <CapturedFrame>[];
  int _frame = 0, _seq = 0;
  File? _exact;
  Timer? _debounce;
  double? _progress;
  bool _loading = false, _busy = false, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _seq++;
    _fx?.dispose().ignore();
    _video?.file.delete().ignore(); // never keep the video
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _progress = null; });
    try {
      final v = await ref.read(serverResolverProvider).resolve(
           widget.url,
            onProgress: (p) { if (mounted) setState(() => _progress = p); },
          );
      final fx = await FrameExtractor.open(v.file);
      _fx?.dispose().ignore();
      _video?.file.delete().ignore();
      setState(() { _video = v; _fx = fx; });
      _seekFrame(0);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _seekFrame(int frame) {
    final fx = _fx!;
    final f = frame.clamp(0, fx.totalFrames - 1).toInt();
    setState(() { _frame = f; _exact = null; }); // show fast preview first
    _debounce?.cancel();
    final seq = ++_seq;
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final file = await fx.frameAt(fx.positionOf(f), maxWidth: 720, ext: 'jpg');
        if (mounted && seq == _seq) setState(() => _exact = file);
      } catch (_) {}
    });
  }

  Future<void> _capture() async {
    final fx = _fx!;
    setState(() => _busy = true);
    try {
     final pos = fx.positionOf(_frame);
      final file = await fx.frameAt(pos); // full-res PNG in the temp dir
      setState(() => _frames.add(CapturedFrame(file, pos)));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_video!, widget.url, _frames);
      if (mounted) Navigator.pop(context, _frames.length);
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = _fx;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture frames'),
        actions: [
          if (_frames.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text('Save ${_frames.length}'),
            ),
        ],
      ),
      body: Column(children: [
        if (_loading) LinearProgressIndicator(value: _progress),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: fx == null
              ? const Center(child: Text('Paste a link to begin'))
              : Image.file(_exact ?? fx.previewFor(_frame),
                  fit: BoxFit.contain, gaplessPlayback: true),
        ),
        if (fx != null) ...[
          Slider(
            value: _frame.toDouble(),
            max: (fx.totalFrames - 1).clamp(1, 1 << 30).toDouble(),
            onChanged: (v) => _seekFrame(v.round()),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: () => _seekFrame(_frame - 1)),
            Text('${(fx.positionOf(_frame).inMilliseconds / 1000).toStringAsFixed(2)} s'
                '  (frame $_frame)'),
            IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: () => _seekFrame(_frame + 1)),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _capture,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Capture'),
            ),
          ]),
        ],
        SizedBox(
          height: _frames.isEmpty ? 8 : 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _frames.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.all(4),
              child: GestureDetector(
                onLongPress: () => setState(() => _frames.removeAt(i)),
                child: Image.file(_frames[i].file, cacheHeight: 180),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}