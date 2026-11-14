import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/validators.dart';
import 'admin_repository.dart';

const _permLabels = {'content': 'إضافة وتعديل الكورسات والمحتوى', 'codes': 'توليد الأكواد', 'sessions': 'مراقبة الجلسات والطلاب', 'settings': 'إعدادات المنصة'};

/// Super Admin only: manage sub-admins, permissions, device resets, bans.
class StaffScreen extends StatefulWidget { const StaffScreen({super.key}); @override State<StaffScreen> createState() => _SS(); }
class _SS extends State<StaffScreen> {
  final _admin = AdminRepository();
  late Future<List<Map<String, dynamic>>> _f = _admin.staff();
  void _reload() => setState(() => _f = _admin.staff());
  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<Map<String, dynamic>?> _askPhone(String title) async {
    final t = TextEditingController();
    final phone = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(backgroundColor: AppColors.surface, title: Text(title),
      content: TextField(controller: t, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رقم هاتف الطالب')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(ctx, t.text), child: const Text('بحث'))]));
    if (phone == null) return null;
    final p = Validators.normalizeDigits(phone);
    if (Validators.phone(p) != null) { _toast('رقم غير صحيح'); return null; }
    final u = await _admin.findByPhone(p);
    if (u == null) _toast('لا يوجد حساب بهذا الرقم');
    return u;
  }

  Future<void> _editPerms(Map<String, dynamic> u) async {
    final sel = <String>{...((u['permissions'] ?? []) as List).cast<String>()};
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: AppColors.surface, title: Text('صلاحيات ${u['full_name']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [for (final e in _permLabels.entries) CheckboxListTile(
        value: sel.contains(e.key), title: Text(e.value), onChanged: (v) => set(() => v! ? sel.add(e.key) : sel.remove(e.key)))]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))])));
    if (ok != true) return;
    try { await _admin.setRole(u['id'], 'sub_admin', sel.toList()); _reload(); } catch (e) { _toast(errText(e)); }
  }

  Future<void> _addSub() async {
    final u = await _askPhone('إضافة مشرف');
    if (u != null) await _editPerms(u);
  }

  Future<void> _resetPassword(Map<String, dynamic> u) async {
    final t = TextEditingController(); String? err;
    final pw = await showDialog<String>(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: AppColors.surface, title: Text('كلمة مرور جديدة: ${u['full_name']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: t, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: 'كلمة المرور الجديدة (8 أحرف على الأقل، حروف وأرقام)', errorText: err)),
        const SizedBox(height: 8), const Text('سلّمها للطالب، وسيُسجَّل خروجه من أي جهاز.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        TextButton(onPressed: () { final e = Validators.password(t.text); if (e != null) { set(() => err = e); return; } Navigator.pop(ctx, t.text); }, child: const Text('حفظ'))])));
    if (pw == null) return;
    try { await _admin.resetPassword(u['id'], pw); _toast('تم تعيين كلمة المرور الجديدة'); } catch (e) { _toast(errText(e)); }
  }

  Future<void> _studentAction() async {
    final u = await _askPhone('إجراء على طالب');
    if (u == null || !mounted) return;
    final banned = u['is_banned'] == true;
    final a = await showModalBottomSheet<String>(context: context, backgroundColor: AppColors.surface, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: Text(u['full_name']), subtitle: Text(u['phone'], textDirection: TextDirection.ltr)),
      ListTile(leading: const Icon(Icons.phonelink_erase), title: const Text('إعادة ضبط ارتباط الجهاز'), onTap: () => Navigator.pop(ctx, 'reset')),
      ListTile(leading: const Icon(Icons.password), title: const Text('تعيين كلمة مرور جديدة'), onTap: () => Navigator.pop(ctx, 'pw')),
      ListTile(leading: Icon(banned ? Icons.lock_open : Icons.block), title: Text(banned ? 'رفع الحظر' : 'حظر الحساب'), onTap: () => Navigator.pop(ctx, 'ban')),
    ])));
    try {
      if (a == 'pw') { await _resetPassword(u); }
      if (a == 'reset') { await _admin.resetDevice(u['id']); _toast('تمت إعادة الضبط وتسجيل خروج الطالب'); }
      if (a == 'ban') { await _admin.setBan(u['id'], !banned); _toast(banned ? 'تم رفع الحظر' : 'تم حظر الحساب'); }
    } catch (e) { _toast(errText(e)); }
  }

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('المشرفون والطلاب'), actions: [IconButton(tooltip: 'إجراء على طالب', icon: const Icon(Icons.manage_accounts_outlined), onPressed: _studentAction)]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _addSub, icon: const Icon(Icons.person_add_alt), label: const Text('مشرف')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.all(14), children: [for (final u in s.data!) Card(color: AppColors.surface, child: ListTile(
        leading: Icon(u['role'] == 'super_admin' ? Icons.verified_user : Icons.badge_outlined, color: AppColors.accent),
        title: Text(u['full_name']),
        subtitle: Text(u['role'] == 'super_admin' ? 'المالك • كل الصلاحيات' : ((u['permissions'] as List).map((p) => _permLabels[p] ?? p).join('، ').isEmpty ? 'بدون صلاحيات' : (u['permissions'] as List).map((p) => _permLabels[p] ?? p).join('، '))),
        trailing: u['role'] == 'super_admin' ? null : PopupMenuButton<String>(onSelected: (v) async {
          if (v == 'p') { _editPerms(u); }
          else { try { await _admin.setRole(u['id'], 'student', []); _reload(); } catch (e) { _toast(errText(e)); } }
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'p', child: Text('تعديل الصلاحيات')), PopupMenuItem(value: 'r', child: Text('إزالة من الإشراف'))])))]);
    }));
}
