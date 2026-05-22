import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/models/immich_models.dart';
import 'package:photo_sync/provider/gallary_provider.dart';
import 'package:photo_sync/provider/people_provider.dart';
import 'package:photo_sync/services/api_service.dart';

const _kHandleHit  = 24.0;  // hit test radius around each corner handle
const _kHandleDraw =  6.0;  // visual radius of corner dots

enum _DragMode { none, drawing, moving, resizeTL, resizeTR, resizeBL, resizeBR }

class FaceTagOverlay extends StatefulWidget {
  final GlobalKey imageKey;
  final String assetId;
  final VoidCallback onClose;
  final (int, int) imageSize;

  const FaceTagOverlay({
    super.key,
    required this.imageKey,
    required this.assetId,
    required this.onClose,
    required this.imageSize,
  });

  @override
  State<FaceTagOverlay> createState() => _FaceTagOverlayState();
}

class _FaceTagOverlayState extends State<FaceTagOverlay>
    with SingleTickerProviderStateMixin {
  Rect? _box;
  _DragMode _mode = _DragMode.none;
  Offset _drawStart   = Offset.zero;
  Offset _moveAnchor  = Offset.zero;
  Offset _fixedCorner = Offset.zero;

  Rect? _imageRect;

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  bool get _hasBox => _box != null && _box!.shortestSide >= 20;

  Rect? _resolveImageRect() {
    final overlayRB = context.findRenderObject() as RenderBox?;
    final imageRB   = widget.imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayRB == null || imageRB == null) return null;
    final origin = overlayRB.globalToLocal(imageRB.localToGlobal(Offset.zero));
    return origin & imageRB.size;
  }

  Offset _clamp(Offset p) {
    final r = _imageRect;
    if (r == null) return p;
    return Offset(p.dx.clamp(r.left, r.right), p.dy.clamp(r.top, r.bottom));
  }

  Rect _clampRect(Rect r) {
    final img = _imageRect;
    if (img == null) return r;
    final norm = Rect.fromLTRB(
      r.left.clamp(img.left, img.right),
      r.top.clamp(img.top, img.bottom),
      r.right.clamp(img.left, img.right),
      r.bottom.clamp(img.top, img.bottom),
    );
    return norm;
  }

  _DragMode _detectMode(Offset p) {
    if (!_hasBox || _box == null) return _DragMode.drawing;
    if ((p - _box!.topLeft).distance     < _kHandleHit) return _DragMode.resizeTL;
    if ((p - _box!.topRight).distance    < _kHandleHit) return _DragMode.resizeTR;
    if ((p - _box!.bottomLeft).distance  < _kHandleHit) return _DragMode.resizeBL;
    if ((p - _box!.bottomRight).distance < _kHandleHit) return _DragMode.resizeBR;
    if (_box!.contains(p))                               return _DragMode.moving;
    return _DragMode.drawing;
  }

  void _onPanStart(DragStartDetails d) {
    _imageRect = _resolveImageRect();
    final p = _clamp(d.localPosition);
    _mode = _detectMode(p);

    switch (_mode) {
      case _DragMode.drawing:
        _drawStart = p;
        setState(() => _box = Rect.fromLTWH(p.dx, p.dy, 0, 0));
      case _DragMode.moving:
        _moveAnchor = p - _box!.topLeft;
      case _DragMode.resizeTL:
        _fixedCorner = _box!.bottomRight;
      case _DragMode.resizeTR:
        _fixedCorner = _box!.bottomLeft;
      case _DragMode.resizeBL:
        _fixedCorner = _box!.topRight;
      case _DragMode.resizeBR:
        _fixedCorner = _box!.topLeft;
      case _DragMode.none:
        break;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final p = _clamp(d.localPosition);
    setState(() {
      switch (_mode) {
        case _DragMode.drawing:
          _box = _clampRect(Rect.fromPoints(_drawStart, p));

        case _DragMode.moving:
          final img = _imageRect;
          if (img == null || _box == null) break;
          final bw = _box!.width;
          final bh = _box!.height;
          final tl = Offset(
            (p.dx - _moveAnchor.dx).clamp(img.left, img.right  - bw),
            (p.dy - _moveAnchor.dy).clamp(img.top,  img.bottom - bh),
          );
          _box = tl & _box!.size;

        case _DragMode.resizeTL:
        case _DragMode.resizeTR:
        case _DragMode.resizeBL:
        case _DragMode.resizeBR:
          _box = _clampRect(Rect.fromPoints(_fixedCorner, p));

        case _DragMode.none:
          break;
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_mode == _DragMode.drawing && !_hasBox) {
      setState(() => _box = null); // too small -> discard
    }
    _mode = _DragMode.none;
  }

  Rect? _normalisedBox() {
    if (_box == null) return null;
    final img = _resolveImageRect();
    if (img == null || img.isEmpty) return null;
    final c = _box!.intersect(img);
    if (c.isEmpty) return null;
    return Rect.fromLTRB(
      ((c.left - img.left) / img.width ).clamp(0.0, 1.0),
      ((c.top - img.top ) / img.height).clamp(0.0, 1.0),
      ((c.right - img.left) / img.width ).clamp(0.0, 1.0),
      ((c.bottom - img.top ) / img.height).clamp(0.0, 1.0),
    );
  }

  void _openPicker() {
    final norm = _normalisedBox();
    if (norm == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF252525),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _PersonPickerSheet(
        assetId: widget.assetId,
        boundingBox: norm,
        onDone: _dismiss,
        imageSize: widget.imageSize,
      ),
    );
  }

  Future<void> _dismiss() async {
    await _fadeCtrl.reverse();
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Stack(
        children: [
          // Dim layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart:  _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd:    _onPanEnd,
              child: CustomPaint(
                painter: _OverlayPainter(box: _box, committed: _hasBox),
              ),
            ),
          ),

          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopBar(
              hasBox: _hasBox,
              onClose: _dismiss,
            ),
          ),

          if (_hasBox)
            Positioned(
              bottom: 36, left: 40, right: 40,
              child: _ConfirmButton(onTap: _openPicker),
            ),

          if (!_hasBox && _box == null)
            Positioned(
              bottom: 52, left: 0, right: 0,
              child: Center(
                child: _Pill(
                  child: const Text(
                    'Drag to draw a box around a face',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect? box;
  final bool committed;
  const _OverlayPainter({required this.box, required this.committed});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.50),
    );
    if (box != null) {
      canvas.drawRect(box!, Paint()..blendMode = BlendMode.clear);
    }
    canvas.restore();

    if (box != null) {
      canvas.drawRect(
        box!,
        Paint()
          ..color = Colors.blueAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = committed ? 2.5 : 1.5,
      );

      if (committed) {
        final fill = Paint()..color = Colors.white;
        final stroke = Paint()
          ..color = Colors.blueAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        for (final c in [box!.topLeft, box!.topRight, box!.bottomLeft, box!.bottomRight]) {
          canvas.drawCircle(c, _kHandleDraw, fill);
          canvas.drawCircle(c, _kHandleDraw, stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.box != box || old.committed != committed;
}

class _TopBar extends StatelessWidget {
  final bool hasBox;
  final VoidCallback onClose;
  const _TopBar({required this.hasBox, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withValues(alpha: 0.55),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 4,
      left: 8, right: 8, bottom: 8,
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Draw a box around the face',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500
            ),
          ),
        ),
      ],
    ),
  );
}

class _ConfirmButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ConfirmButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'Assign person',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15
            )
          ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _PersonPickerSheet extends ConsumerStatefulWidget {
  final String assetId;
  final Rect boundingBox; // normalised 0.0–1.0
  final VoidCallback onDone;
  final (int, int) imageSize;

  const _PersonPickerSheet({
    required this.assetId,
    required this.boundingBox,
    required this.onDone,
    required this.imageSize,
  });

  @override
  ConsumerState<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<_PersonPickerSheet> {
  List<ImmichPerson> _people = [];
  List<ImmichPerson> _filtered = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final people = await ref.read(peopleStoreProvider.future);
      if (mounted) setState(() { _people = people; _filtered = people; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
        ? _people
        : _people.where((p) => (p.name).toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _select(ImmichPerson person) async {
    setState(() => _submitting = true);
    try {
      await ref.read(galleryBucketProvider.notifier).addFace(
        assetId: widget.assetId,
        personId: person.id,
        boundingBox: {
          'x1': widget.boundingBox.left,
          'y1': widget.boundingBox.top,
          'x2': widget.boundingBox.right,
          'y2': widget.boundingBox.bottom,
        },
        imageSize: widget.imageSize,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Assigned to ${person.name}'),
          backgroundColor: Colors.green.shade700,
        ));
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          const Text('Select a person', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search people',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF363636),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _submitting || _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white54))
              : _error != null
                ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                : _filtered.isEmpty
                    ? const Center(
                      child: Text(
                        'No people found',
                        style: TextStyle(color: Colors.white38)
                      )
                    )
                    : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey.shade700,
                            foregroundImage: CachedNetworkImageProvider(p.thumbnailUrl(ImmichConfig.baseUrl)),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 14
                            )
                          ),
                          onTap: () => _select(p),
                        );
                      },
                    ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3A3A),
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}