import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'code_generator_screen.dart';
import 'codes_list_screen.dart';
import 'manage_content_screen.dart';
import 'staff_screen.dart';
import 'audit_screen.dart';

bool hasPerm(Map<String, dynamic> p, String perm) =>
    p['role'] == 'super_admin' || (p['role'] == 'sub_admin' && ((p['permissions'] ?? []) as List).contains(perm));

class AdminDashboard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const AdminDashboard({super.key, required this.profile});

  @override Widget build(BuildContext c) {
    final tiles = <_T>[
      if (hasPerm(profile, 'content')) _T('إدارة الكورسات والوحدات', Icons.menu_book_outlined, const ManageContentScreen()),
      if (hasPerm(profile, 'codes')) _T('توليد أكواد التفعيل', Icons.vpn_key_outlined, const CodeGeneratorScreen()),
      if (hasPerm(profile, 'codes')) _T('سجل الأكواد', Icons.receipt_long_outlined, const CodesListScreen()),
      if (profile['role'] == 'super_admin') _T('المشرفون والطلاب', Icons.groups_2_outlined, const StaffScreen()),
      if (profile['role'] == 'super_admin') _T('سجل العمليات', Icons.history, const AuditScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم')),
      body: tiles.isEmpty
        ? const Center(child: Text('لم تُمنح أي صلاحيات بعد'))
        : GridView.count(crossAxisCount: 2, padding: const EdgeInsets.all(16), mainAxisSpacing: 14, crossAxisSpacing: 14,
            children: [for (final t in tiles) Material(color: AppColors.surface, borderRadius: BorderRadius.circular(18),
              child: InkWell(borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => t.page)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(t.icon, size: 40, color: AppColors.accent), const SizedBox(height: 10),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(t.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                ])))]));
  }
}
class _T { final String title; final IconData icon; final Widget page; _T(this.title, this.icon, this.page); }
