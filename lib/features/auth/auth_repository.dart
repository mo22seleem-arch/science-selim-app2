import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/device_service.dart';
import '../../core/utils/validators.dart';

class AuthRepository {
  final SupabaseClient _db = Supabase.instance.client;
  /// Supabase phone auth needs an SMS provider; until OTP is added we map phone -> synthetic email.
  static String _email(String phone) => '${Validators.normalizeDigits(phone)}@selim-science.app';

  Future<void> signUp({required String name, required String phone, required String password}) async {
    final p = Validators.normalizeDigits(phone);
    try {
      await _db.auth.signUp(email: _email(p), password: password,
          data: {'full_name': Validators.cleanName(name), 'phone': p});
    } on AuthException catch (e) { throw _map(e); }
  }

  Future<void> signIn({required String phone, required String password}) async {
    try {
      await _db.auth.signInWithPassword(email: _email(phone), password: password);
    } on AuthException catch (e) { throw _map(e); }
  }

  /// Claims this device as THE active one; the server kills every other session and notifies the old phone.
  Future<void> bindDevice() async {
    final d = await DeviceService.info();
    await _db.rpc('register_device', params: {'p_device_id': d.id, 'p_device_name': d.name});
  }

  Future<Map<String, dynamic>> myProfile() async =>
      await _db.from('profiles').select().eq('id', _db.auth.currentUser!.id).single();

  Future<void> signOut() => _db.auth.signOut();

  String _map(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) return 'هذا الرقم مسجل بالفعل';
    if (m.contains('invalid login')) return 'رقم الهاتف أو كلمة المرور غير صحيحة';
    if (m.contains('banned')) return 'هذا الحساب موقوف';
    return 'حدث خطأ، حاول مرة أخرى';
  }
}
