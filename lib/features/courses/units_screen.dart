import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'courses_repository.dart';
import 'courses_screen.dart' show badge;
import 'models.dart';
import 'redeem_sheet.dart';
import '../lectures/lectures_screen.dart';

class UnitsScreen extends StatefulWidget {
  final Course course;
  const UnitsScreen({super.key, required this.course});
  @override State<UnitsScreen> createState() => _US();
}
class _US extends State<UnitsScreen> {
  final _repo = CoursesRepository();
  late Future<(List<Unit>, Access)> _f = _load();
  Future<(List<Unit>, Access)> _load() async => (await _repo.units(widget.course.id), await _repo.access());
  void _reload() => setState(() => _f = _load());

  Future<void> _redeem(String title, {String? courseId, String? unitId}) async {
    final ok = await showRedeemSheet(context, title: title, courseId: courseId, unitId: unitId);
    if (ok == true) { _reload(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التفعيل بنجاح'))); }
  }

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(widget.course.title)),
    body: FutureBuilder<(List<Unit>, Access)>(future: _f, builder: (_, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return const Center(child: Text('تعذر تحميل الوحدات'));
      final (units, access) = s.data!; final course = widget.course;
      final courseOpen = access.course(course);
      final end = access.endsFor(courseId: course.id);
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (!courseOpen) Padding(padding: const EdgeInsets.only(bottom: 14), child: ElevatedButton.icon(
            icon: const Icon(Icons.vpn_key_outlined), label: const Text('تفعيل الكورس بالكامل بكود'),
            onPressed: () => _redeem(course.title, courseId: course.id))),
        if (courseOpen && !course.free && end != null) Padding(padding: const EdgeInsets.only(bottom: 14),
            child: Text('ينتهي الاشتراك في ${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.muted))),
        if (units.isEmpty) const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: Text('لا توجد وحدات بعد'))),
        for (final u in units) Padding(padding: const EdgeInsets.only(bottom: 10), child: Material(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14),
          child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: Icon(access.unit(u, course) ? Icons.play_circle_outline : Icons.lock_outline,
                color: access.unit(u, course) ? AppColors.accent : AppColors.muted),
            title: Text(u.title), trailing: badge(u.free || course.free ? 'مجاني' : (access.unit(u, course) ? 'مفعّل' : 'مدفوع')),
            onTap: () {
              if (access.unit(u, course)) {
                Navigator.push(c, MaterialPageRoute(builder: (_) => LecturesScreen(unit: u)));
              } else { _redeem(u.title, unitId: u.id); }
            }))),
      ]);
    }));
}
