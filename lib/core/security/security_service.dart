import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ch = MethodChannel('selim/security');
const _allowEmulator = bool.fromEnvironment('ALLOW_EMULATOR');   // flutter run --dart-define=ALLOW_EMULATOR=true

class SecurityService {
  /// Release builds only. Returns e.g. ['root','hooks']. Fails open on channel errors (server-side checks still apply).
  static Future<List<String>> threats() async {
    if (kDebugMode) return [];
    try {
      final r = await _ch.invokeListMethod<String>('threats') ?? [];
      return r.where((t) => !(t == 'emulator' && _allowEmulator)).toList();
    } catch (_) { return []; }
  }

  static Future<bool> externalDisplay() async {
    try { return await _ch.invokeMethod<bool>('externalDisplay') ?? false; } catch (_) { return false; }
  }
}

/// Play Integrity: nonce from OUR server -> token from Google -> verified server-side (Edge Function verify-integrity).
class IntegrityService {
  static const _project = String.fromEnvironment('GCP_PROJECT_NUMBER');
  static Future<bool> attest() async {
    if (_project.isEmpty) return false;
    try {
      final db = Supabase.instance.client;
      final n = await db.functions.invoke('verify-integrity', body: {'action': 'nonce'});
      final token = await _ch.invokeMethod<String>('integrityToken', {'nonce': n.data['nonce'], 'project': _project});
      final v = await db.functions.invoke('verify-integrity', body: {'action': 'verify', 'token': token});
      return v.data['ok'] == true;
    } catch (_) { return false; }
  }
}
