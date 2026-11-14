import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';

/// Self-service password change (student/admin, while signed in).
Future<void> showChangePasswordDialog(BuildContext c) async {
  final p1 = TextEditingController(), p2 = TextEditingController(); String? err; bool busy = false;
  final ok = await showDialog<bool>(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    backgroundColor: AppColors.surface, title: const Text('تغيير كلمة المرور'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: p1, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
      const SizedBox(height: 10),
      TextField(controller: p2, obscureText: true, decoration: InputDecoration(labelText: 'تأكيد كلمة المرور', errorText: err)),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
      TextButton(onPressed: busy ? null : () async {
        final e = Validators.password(p1.text);
        if (e != null) { set(() => err = e); return; }
        if (p1.text != p2.text) { set(() => err = 'كلمتا المرور غير متطابقتين'); return; }
        set(() { busy = true; err = null; });
        try { await Supabase.instance.client.auth.updateUser(UserAttributes(password: p1.text)); if (ctx.mounted) Navigator.pop(ctx, true); }
        catch (_) { set(() { busy = false; err = 'تعذر تغيير كلمة المرور، حاول مرة أخرى'; }); }
      }, child: const Text('حفظ'))])));
  if (ok == true && c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور')));
}
