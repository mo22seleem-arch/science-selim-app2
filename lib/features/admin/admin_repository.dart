import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  final _db = Supabase.instance.client;

  // ---- content ----
  Future<void> saveCourse({String? id, required int grade, required String title, String? description, required bool free}) async {
    final row = {'grade': grade, 'title': title.trim(), 'description': description?.trim(), 'access': free ? 'free' : 'paid'};
    if (id == null) {
      await _db.from('courses').insert(row);
    } else {
      await _db.from('courses').update(row).eq('id', id);
    }
  }
  Future<void> deleteCourse(String id) => _db.from('courses').delete().eq('id', id);

  Future<void> saveUnit({String? id, required String courseId, required String title, required bool free}) async {
    final row = {'course_id': courseId, 'title': title.trim(), 'access': free ? 'free' : 'paid'};
    if (id == null) {
      await _db.from('units').insert(row);
    } else {
      await _db.from('units').update(row).eq('id', id);
    }
  }
  Future<void> deleteUnit(String id) => _db.from('units').delete().eq('id', id);

  // ---- codes ----
  Future<List<String>> generateCodes({required int count, String? courseId, String? unitId,
      required bool permanent, int? days, DateTime? redeemBefore}) async {
    final r = await _db.rpc('admin_generate_codes', params: {
      'p_count': count, 'p_course': courseId, 'p_unit': unitId,
      'p_duration': permanent ? 'permanent' : 'timed', 'p_days': permanent ? null : days,
      'p_redeem_before': redeemBefore?.toUtc().toIso8601String(),
    });
    return (r as List).map((e) => e.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> codes({String? status}) {
    var q = _db.from('activation_codes').select('*, courses(title), units(title)');
    if (status != null) q = q.eq('status', status);
    return q.order('created_at', ascending: false).limit(300);
  }
  Future<void> revokeCode(String id) => _db.rpc('admin_revoke_code', params: {'p_id': id});

  // ---- staff / students (super admin) ----
  Future<List<Map<String, dynamic>>> staff() =>
      _db.from('profiles').select().neq('role', 'student').order('created_at');

  Future<Map<String, dynamic>?> findByPhone(String phone) =>
      _db.from('profiles').select().eq('phone', phone).maybeSingle();

  Future<void> setRole(String userId, String role, List<String> perms) =>
      _db.rpc('admin_set_role', params: {'p_user': userId, 'p_role': role, 'p_perms': perms});
  Future<void> resetDevice(String userId) => _db.rpc('admin_reset_device', params: {'p_user': userId});
  Future<void> setBan(String userId, bool ban) => _db.rpc('admin_set_ban', params: {'p_user': userId, 'p_ban': ban});
}
