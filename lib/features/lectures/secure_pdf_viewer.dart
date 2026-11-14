import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/native_bridge.dart';
import '../../core/theme/app_theme.dart';
import 'lectures_repository.dart';
import 'moving_watermark.dart';

/// In-app only. Rendering is done by Android's own PdfRenderer: the file is never stored with a path on disk,
/// there is no download/share/print UI, the signed URL lives 90 s, pages are watermarked and FLAG_SECURE blocks screenshots.
class SecurePdfViewer extends StatefulWidget {
  final String lectureId, watermark;
  const SecurePdfViewer({super.key, required this.lectureId, required this.watermark});
  @override State<SecurePdfViewer> createState() => _PV();
}
class _PV extends State<SecurePdfViewer> {
  int _pages = 0; bool _failed = false;
  final Map<int, Future<Uint8List>> _cache = {};

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final url = await LecturesRepository().mediaUrl(widget.lectureId, 'pdf');
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('http');
      final n = await NativeBridge.pdfOpen(res.bodyBytes);
      if (!mounted) return;
      setState(() { _pages = n; _failed = n == 0; });
    } catch (_) { if (mounted) setState(() => _failed = true); }
  }

  @override void dispose() { NativeBridge.pdfClose(); super.dispose(); }

  int _width(BuildContext c) { final m = MediaQuery.of(c); return (m.size.width * m.devicePixelRatio).clamp(600.0, 1600.0).round(); }
  Future<Uint8List> _page(int i, int w) => _cache.putIfAbsent(i, () => NativeBridge.pdfPage(i, w));

  void _zoom(BuildContext c, Uint8List bytes) => showDialog(context: c, builder: (ctx) => Dialog.fullscreen(backgroundColor: Colors.black,
    child: Stack(children: [
      InteractiveViewer(minScale: 1, maxScale: 5, child: Center(child: Image.memory(bytes))),
      Positioned.fill(child: MovingWatermark(text: widget.watermark)),
      Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx))),
    ])));

  @override Widget build(BuildContext c) {
    if (_failed) return const Center(child: Text('تعذر تحميل الملف'));
    if (_pages == 0) return const Center(child: CircularProgressIndicator());
    final w = _width(c);
    return Stack(children: [
      ListView.builder(padding: const EdgeInsets.all(10), itemCount: _pages, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10),
        child: FutureBuilder<Uint8List>(future: _page(i, w), builder: (_, s) => s.hasData
          ? GestureDetector(onTap: () => _zoom(c, s.data!), child: Image.memory(s.data!, fit: BoxFit.fitWidth, gaplessPlayback: true))
          : AspectRatio(aspectRatio: 0.707, child: Container(color: AppColors.surface, child: Center(child: s.hasError ? const Text('تعذر عرض الصفحة') : const CircularProgressIndicator())))))),
      Positioned.fill(child: MovingWatermark(text: widget.watermark, opacity: .3)),
    ]);
  }
}
