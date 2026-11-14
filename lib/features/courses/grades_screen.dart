import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../admin/admin_dashboard.dart';
import '../auth/auth_repository.dart';
import '../auth/change_password.dart';
import 'courses_repository.dart';
import 'courses_screen.dart';
import 'models.dart';

/// Home: the three fixed stages.
class GradesScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const GradesScreen({super.key, required this.profile});
  @override State<GradesScreen> createState() => _GS();
}
class _GS extends State<GradesScreen> {
  final _repo = CoursesRepository();
  late Future<Map<int, int>> _f = _repo.countByGrade();
  bool get _staff => widget.profile['role'] != 'student';
  void _reload() => setState(() => _f = _repo.countByGrade());

  @override Widget build(BuildContext c) {
    final first = '${widget.profile['full_name']}'.trim().split(' ').first;
    return Scaffold(
      appBar: AppBar(title: const Text('العلوم مع محمد سليم'), actions: [
        if (_staff) IconButton(tooltip: 'لوحة التحكم', icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AdminDashboard(profile: widget.profile)))),
        IconButton(tooltip: 'تغيير كلمة المرور', icon: const Icon(Icons.lock_reset), onPressed: () => showChangePasswordDialog(c)),
        IconButton(tooltip: 'خروج', icon: const Icon(Icons.logout), onPressed: () => AuthRepository().signOut()),
      ]),
      body: RefreshIndicator(onRefresh: () async { _reload(); await _f; }, child: FutureBuilder<Map<int, int>>(future: _f, builder: (_, s) {
        final counts = s.data ?? {};
        return ListView(padding: const EdgeInsets.all(18), children: [
          Text('أهلاً $first 👋', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('اختر مرحلتك الدراسية', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          for (final g in Grades.all) Padding(padding: const EdgeInsets.only(bottom: 14), child: Material(
            color: AppColors.surface, borderRadius: BorderRadius.circular(20),
            child: InkWell(borderRadius: BorderRadius.circular(20),
              onTap: () async { await Navigator.push(c, MaterialPageRoute(builder: (_) => CoursesScreen(grade: g))); _reload(); },
              child: Container(padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cream.withValues(alpha: .2))),
                child: Row(children: [
                  Container(width: 56, height: 56, alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.midnight, borderRadius: BorderRadius.circular(16)),
                      child: Text('$g', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.accent))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Grades.label(g), style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(s.connectionState != ConnectionState.done ? '...' : ((counts[g] ?? 0) == 0 ? 'لا توجد كورسات بعد' : '${counts[g]} كورس'),
                        style: const TextStyle(color: AppColors.muted)),
                  ])),
                  const Icon(Icons.chevron_left, color: AppColors.muted),
                ]))))),
        ]);
      })));
  }
}
