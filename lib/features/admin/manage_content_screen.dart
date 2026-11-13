import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../courses/courses_repository.dart';
import '../courses/courses_screen.dart' show badge;
import '../courses/models.dart';
import 'admin_repository.dart';
import 'manage_lectures_screen.dart';

Future<bool> confirmDelete(BuildContext c, String what) async => (await showDialog<bool>(context: c, builder: (_) => AlertDialog(
  backgroundColor: AppColors.surface, title: const Text('تأكيد الحذف'),
  content: Text('سيتم حذف "$what" وكل ما بداخله نهائياً.'),
  actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: AppColors.error)))])) ?? false);

/// Shared add/edit dialog. Returns {title, desc, free} or null.
Future<Map<String, dynamic>?> itemDialog(BuildContext c, {required String heading, String? title, String? desc, bool free = false, bool withDesc = false}) {
  final t = TextEditingController(text: title), d = TextEditingController(text: desc); bool f = free;
  return showDialog<Map<String, dynamic>>(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    backgroundColor: AppColors.surface, title: Text(heading),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: t, decoration: const InputDecoration(labelText: 'العنوان')),
      if (withDesc) ...[const SizedBox(height: 10), TextField(controller: d, maxLines: 2, decoration: const InputDecoration(labelText: 'الوصف (اختياري)'))],
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(f ? 'مجاني' : 'مدفوع (يحتاج كود)'), value: f, onChanged: (v) => set(() => f = v)),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () { if (t.text.trim().isEmpty) return; Navigator.pop(ctx, {'title': t.text, 'desc': d.text, 'free': f}); }, child: const Text('حفظ'))])));
}

class ManageContentScreen extends StatefulWidget { const ManageContentScreen({super.key}); @override State<ManageContentScreen> createState() => _MC(); }
class _MC extends State<ManageContentScreen> {
  final _repo = CoursesRepository(), _admin = AdminRepository();
  late Future<List<Course>> _f = _repo.courses();
  void _reload() => setState(() => _f = _repo.courses());
  void _toast(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));

  Future<void> _edit([Course? co]) async {
    final r = await itemDialog(context, heading: co == null ? 'كورس جديد' : 'تعديل الكورس', title: co?.title, desc: co?.description, free: co?.free ?? false, withDesc: true);
    if (r == null) return;
    try { await _admin.saveCourse(id: co?.id, title: r['title'], description: r['desc'], free: r['free']); _reload(); } catch (e) { _toast(e); }
  }

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الكورسات')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add), label: const Text('كورس')),
    body: FutureBuilder<List<Course>>(future: _f, builder: (_, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      if (s.data!.isEmpty) return const Center(child: Text('أضف أول كورس'));
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [for (final co in s.data!) Card(
        color: AppColors.surface, child: ListTile(title: Text(co.title), subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerRight, child: badge(co.free ? 'مجاني' : 'مدفوع'))),
          onTap: () async { await Navigator.push(c, MaterialPageRoute(builder: (_) => ManageUnitsScreen(course: co))); },
          trailing: PopupMenuButton<String>(onSelected: (v) async {
            if (v == 'e') { _edit(co); }
            else if (await confirmDelete(c, co.title)) { try { await _admin.deleteCourse(co.id); _reload(); } catch (e) { _toast(e); } }
          }, itemBuilder: (_) => const [PopupMenuItem(value: 'e', child: Text('تعديل')), PopupMenuItem(value: 'd', child: Text('حذف'))])))]);
    }));
}

class ManageUnitsScreen extends StatefulWidget { final Course course; const ManageUnitsScreen({super.key, required this.course}); @override State<ManageUnitsScreen> createState() => _MU(); }
class _MU extends State<ManageUnitsScreen> {
  final _repo = CoursesRepository(), _admin = AdminRepository();
  late Future<List<Unit>> _f = _repo.units(widget.course.id);
  void _reload() => setState(() => _f = _repo.units(widget.course.id));
  void _toast(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));

  Future<void> _edit([Unit? u]) async {
    final r = await itemDialog(context, heading: u == null ? 'وحدة جديدة' : 'تعديل الوحدة', title: u?.title, free: u?.free ?? false);
    if (r == null) return;
    try { await _admin.saveUnit(id: u?.id, courseId: widget.course.id, title: r['title'], free: r['free']); _reload(); } catch (e) { _toast(e); }
  }

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('وحدات: ${widget.course.title}')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add), label: const Text('وحدة')),
    body: FutureBuilder<List<Unit>>(future: _f, builder: (_, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      if (s.data!.isEmpty) return const Center(child: Text('لا توجد وحدات'));
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [for (final u in s.data!) Card(color: AppColors.surface,
        child: ListTile(title: Text(u.title), subtitle: const Text('اضغط لإدارة المحاضرات'), leading: badge(u.free ? 'مجاني' : 'مدفوع'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ManageLecturesScreen(unit: u))),
          trailing: PopupMenuButton<String>(onSelected: (v) async {
            if (v == 'e') { _edit(u); }
            else if (await confirmDelete(c, u.title)) { try { await _admin.deleteUnit(u.id); _reload(); } catch (e) { _toast(e); } }
          }, itemBuilder: (_) => const [PopupMenuItem(value: 'e', child: Text('تعديل')), PopupMenuItem(value: 'd', child: Text('حذف'))])))]);
    }));
}
