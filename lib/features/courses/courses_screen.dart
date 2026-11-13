import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'courses_repository.dart';
import 'models.dart';
import 'units_screen.dart';

Widget badge(String t, {bool filled = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  decoration: BoxDecoration(color: filled ? AppColors.cream : Colors.transparent,
      border: Border.all(color: AppColors.cream.withValues(alpha: .6)), borderRadius: BorderRadius.circular(20)),
  child: Text(t, style: TextStyle(fontSize: 12, color: filled ? AppColors.midnight : AppColors.cream)));

/// Courses of ONE stage.
class CoursesScreen extends StatefulWidget {
  final int grade;
  const CoursesScreen({super.key, required this.grade});
  @override State<CoursesScreen> createState() => _CS();
}
class _CS extends State<CoursesScreen> {
  final _repo = CoursesRepository();
  late Future<(List<Course>, Access)> _f = _load();
  Future<(List<Course>, Access)> _load() async => (await _repo.courses(grade: widget.grade), await _repo.access());

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(Grades.label(widget.grade))),
    body: RefreshIndicator(onRefresh: () async { setState(() => _f = _load()); await _f; },
      child: FutureBuilder<(List<Course>, Access)>(future: _f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return ListView(children: const [SizedBox(height: 120), Center(child: Text('تعذر تحميل الكورسات'))]);
        final (courses, access) = s.data!;
        if (courses.isEmpty) return ListView(children: const [SizedBox(height: 120), Center(child: Text('لا توجد كورسات في هذه المرحلة بعد'))]);
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: courses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final co = courses[i]; final open = access.course(co);
            return Material(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
              child: InkWell(borderRadius: BorderRadius.circular(16),
                onTap: () async { await Navigator.push(c, MaterialPageRoute(builder: (_) => UnitsScreen(course: co))); setState(() => _f = _load()); },
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  Icon(open ? Icons.science : Icons.lock_outline, size: 34, color: open ? AppColors.accent : AppColors.muted),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(co.title, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if ((co.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4),
                        child: Text(co.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted))),
                  ])),
                  badge(co.free ? 'مجاني' : (open ? 'مفعّل' : 'مدفوع'), filled: !co.free && open),
                ]))));
          });
      })));
}
