/// Exactly three fixed stages. No DB table: the database enforces grade IN (1,2,3).
class Grades {
  static const all = [1, 2, 3];
  static const _names = {1: 'الأول الإعدادي', 2: 'الثاني الإعدادي', 3: 'الثالث الإعدادي'};
  static String label(int g) => _names[g] ?? '';
}

class Course {
  final String id, title; final String? description; final bool free; final int grade;
  Course(this.id, this.title, this.description, this.free, this.grade);
  factory Course.fromMap(Map<String, dynamic> m) =>
      Course(m['id'], m['title'], m['description'], m['access'] == 'free', (m['grade'] as num?)?.toInt() ?? 1);
}

class Unit {
  final String id, courseId, title; final bool free;
  Unit(this.id, this.courseId, this.title, this.free);
  factory Unit.fromMap(Map<String, dynamic> m) =>
      Unit(m['id'], m['course_id'], m['title'], m['access'] == 'free');
}

/// UI-only access check (the server's RLS is the real enforcement).
class Access {
  final List<Map<String, dynamic>> _rows;
  Access(this._rows);
  bool _live(Map<String, dynamic> r) =>
      r['ends_at'] == null || DateTime.parse(r['ends_at']).isAfter(DateTime.now());
  bool course(Course c) => c.free || _rows.any((r) => r['course_id'] == c.id && _live(r));
  bool unit(Unit u, Course c) =>
      course(c) || u.free || _rows.any((r) => r['unit_id'] == u.id && _live(r));
  /// null = permanent; otherwise the expiry of the active enrollment.
  DateTime? endsFor({String? courseId, String? unitId}) {
    for (final r in _rows) {
      if (_live(r) && (r['course_id'] == courseId && courseId != null || r['unit_id'] == unitId && unitId != null)) {
        return r['ends_at'] == null ? null : DateTime.parse(r['ends_at']).toLocal();
      }
    }
    return null;
  }
}
