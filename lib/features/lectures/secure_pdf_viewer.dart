import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import '../../core/theme/app_theme.dart';
import 'lectures_repository.dart';
import 'moving_watermark.dart';

/// In-app only: bytes live in memory (never written to disk), no download/share/print UI exists,
/// and the signed URL expires in 90 s. Watermarked + FLAG_SECURE blocks screenshots.
class SecurePdfViewer extends StatefulWidget {
  final String lectureId, watermark;
  const SecurePdfViewer({super.key, required this.lectureId, required this.watermark});
  @override State<SecurePdfViewer> createState() => _PV();
}
class _PV extends State<SecurePdfViewer> {
  PdfControllerPinch? _ctrl; bool _failed = false;
  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final url = await LecturesRepository().mediaUrl(widget.lectureId, 'pdf');
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('http');
      final Uint8List bytes = res.bodyBytes;
      if (!mounted) return;
      setState(() => _ctrl = PdfControllerPinch(document: PdfDocument.openData(bytes)));
    } catch (_) { if (mounted) setState(() => _failed = true); }
  }
  @override void dispose() { _ctrl?.dispose(); super.dispose(); }

  @override Widget build(BuildContext c) {
    if (_failed) return const Center(child: Text('تعذر تحميل الملف'));
    if (_ctrl == null) return const Center(child: CircularProgressIndicator());
    return Stack(children: [
      PdfViewPinch(controller: _ctrl!, backgroundDecoration: const BoxDecoration(color: AppColors.midnight)),
      Positioned.fill(child: MovingWatermark(text: widget.watermark, opacity: .3)),
      Positioned(bottom: 10, left: 0, right: 0, child: Center(child: PdfPageNumber(controller: _ctrl!, builder: (_, state, page, total) =>
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Text('$page / ${total ?? '-'}', style: const TextStyle(color: Colors.white)))))),
    ]);
  }
}
