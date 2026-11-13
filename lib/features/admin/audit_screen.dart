import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

/// Super Admin only (enforced by RLS on audit_log).
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});
  static const _ar = {
    'codes.generate': 'توليد أكواد', 'codes.revoke': 'إلغاء كود', 'student.device_reset': 'إعادة ضبط جهاز طالب',
    'student.ban': 'حظر طالب', 'student.unban': 'رفع حظر', 'staff.set_role': 'تعديل مشرف',
    'device.switch': 'تغيير جهاز (إشارة مشاركة حساب)',
  };
  String _label(String a) {
    if (_ar.containsKey(a)) return _ar[a]!;
    final p = a.split('.'); final t = {'courses': 'كورس', 'units': 'وحدة', 'lectures': 'محاضرة'}[p.first] ?? p.first;
    return '${{'insert': 'إضافة', 'update': 'تعديل', 'delete': 'حذف'}[p.last] ?? p.last} $t';
  }

  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('سجل العمليات')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client.from('audit_log').select().order('created_at', ascending: false).limit(200), builder: (_, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      if (s.data!.isEmpty) return const Center(child: Text('لا توجد عمليات'));
      return ListView.builder(padding: const EdgeInsets.all(12), itemCount: s.data!.length, itemBuilder: (_, i) {
        final r = s.data![i]; final t = DateTime.parse(r['created_at']).toLocal();
        final title = (r['meta'] as Map?)?['title'];
        final sharing = r['action'] == 'device.switch';
        return Card(color: AppColors.surface, child: ListTile(
          leading: Icon(sharing ? Icons.warning_amber_rounded : Icons.history, color: sharing ? Colors.amber : AppColors.accent),
          title: Text('${_label(r['action'])}${title != null ? ': $title' : ''}'),
          subtitle: Text('${r['actor_name'] ?? '-'} • ${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')));
      });
    }));
}
