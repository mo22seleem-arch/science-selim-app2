import 'package:supabase_flutter/supabase_flutter.dart';

String errText(Object e) {
  final m = e is PostgrestException ? e.message : e.toString();
  const map = {
    'code_invalid': 'الكود غير صحيح',
    'code_used': 'هذا الكود مستخدم بالفعل أو تم إلغاؤه',
    'code_wrong_target': 'هذا الكود لا يخص هذا الكورس / الوحدة',
    'code_expired': 'انتهت صلاحية هذا الكود',
    'too_many_attempts': 'محاولات خاطئة كثيرة، انتظر 15 دقيقة ثم حاول مرة أخرى',
    'not_authenticated': 'سجّل الدخول أولاً',
    'no_active_device': 'سجّل الدخول من جديد ثم حاول مرة أخرى',
    'forbidden': 'ليست لديك صلاحية لهذا الإجراء',
    'owner_protected': 'لا يمكن تعديل حساب المالك',
    'cannot_create_super_admin': 'لا يمكن إنشاء مدير عام آخر',
    'bad_count': 'العدد يجب أن يكون بين 1 و 500',
  };
  for (final k in map.keys) { if (m.contains(k)) return map[k]!; }
  return 'حدث خطأ، حاول مرة أخرى';
}
