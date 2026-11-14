import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/device_service.dart';

/// Watches profiles.active_device_id. If another phone takes over, this device is signed out instantly.
class SessionGuard with WidgetsBindingObserver {
  SessionGuard._();
  static final instance = SessionGuard._();
  /// LoginScreen shows the "logged in from another device" message when true.
  static final kicked = ValueNotifier<bool>(false);

  StreamSubscription? _sub; Timer? _poll;
  final _db = Supabase.instance.client;

  void start() {
    stop();
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    WidgetsBinding.instance.addObserver(this);
    _sub = _db.from('profiles').stream(primaryKey: ['id']).eq('id', uid).listen((rows) {
      if (rows.isNotEmpty) _check(rows.first['active_device_id'] as String?, rows.first['is_banned'] == true);
    });
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => verifyNow());   // safety net if Realtime is unavailable
    verifyNow();
  }

  Future<void> verifyNow() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final r = await _db.from('profiles').select('active_device_id,is_banned').eq('id', uid).single();
      await _check(r['active_device_id'] as String?, r['is_banned'] == true);
    } on AuthException { await _kick(); } catch (_) {}
  }

  Future<void> _check(String? active, bool banned) async {
    final mine = (await DeviceService.info()).id;
    if (banned || (active != null && active != mine)) await _kick();
  }

  Future<void> _kick() async {
    kicked.value = true;
    stop();
    try { await _db.auth.signOut(scope: SignOutScope.local); } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) verifyNow();   // covers offline -> back online
  }

  void stop() { _sub?.cancel(); _sub = null; _poll?.cancel(); _poll = null; WidgetsBinding.instance.removeObserver(this); }
}
