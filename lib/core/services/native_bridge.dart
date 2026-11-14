import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Our own Android bridge (replaces android_id, device_info_plus, file_picker, pdfx).
class NativeBridge {
  static const _ch = MethodChannel('selim/native');

  static Future<({String id, String name})> deviceInfo() async {
    final m = await _ch.invokeMapMethod<String, dynamic>('deviceInfo') ?? {};
    final name = (m['name'] as String?) ?? 'Android';
    var id = (m['id'] as String?) ?? '';
    if (id.isEmpty || id == '9774d56d682e549c') id = 'fallback-${name.hashCode}';   // known-bad ANDROID_ID values
    return (id: id, name: name);
  }

  /// Opens the system document picker (PDF only). null = cancelled.
  static Future<({String name, Uint8List bytes})?> pickPdf() async {
    final r = await _ch.invokeMapMethod<String, dynamic>('pickPdf');
    if (r == null) return null;
    return (name: r['name'] as String, bytes: r['bytes'] as Uint8List);
  }

  static Future<int> pdfOpen(Uint8List bytes) async => (await _ch.invokeMethod<int>('pdfOpen', {'bytes': bytes})) ?? 0;
  static Future<Uint8List> pdfPage(int index, int width) async =>
      (await _ch.invokeMethod<Uint8List>('pdfPage', {'index': index, 'width': width}))!;
  static Future<void> pdfClose() async { try { await _ch.invokeMethod('pdfClose'); } catch (_) {} }
}
