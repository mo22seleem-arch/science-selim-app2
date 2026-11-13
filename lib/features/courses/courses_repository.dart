import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class CoursesRepository {
  final _db = Supabase.instance.client;

  Future<List<Course>> courses() async {
    final r = await _db.from('courses').select().order('sort_order').order('created_at');
    return r.map(Course.fromMap).toList();
  }

  Future<List<Unit>> units(String courseId) async {
    final r = await _db.from('units').select().eq('course_id', courseId).order('sort_order').order('title');
    return r.map(Unit.fromMap).toList();
  }

  Future<Access> access() async {
    final r = await _db.from('enrollments').select('course_id,unit_id,ends_at').eq('user_id', _db.auth.currentUser!.id);
    return Access(r);
  }

  /// Server validates: exists / unused / matches target / not expired.
  Future<void> redeem(String code, {String? courseId, String? unitId}) async {
    final r = await _db.rpc('redeem_code', params: {'p_code': code, 'p_course': courseId, 'p_unit': unitId});
    if (r != 'ok') throw Exception(r);
  }
}
