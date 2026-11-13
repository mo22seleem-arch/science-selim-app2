class Validators {
  static const superAdminPhone = '01091277447';

  /// Converts Arabic-Indic digits (٠-٩) to ASCII so "٠١٠..." is accepted.
  static String normalizeDigits(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final r in s.trim().runes) {
      final ch = String.fromCharCode(r);
      final i = ar.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString();
  }

  /// 010 / 011 / 012 / 015 + 8 digits = exactly 11 digits.
  static final _egPhone = RegExp(r'^01[0125][0-9]{8}$');
  static String? phone(String? v) {
    final p = normalizeDigits(v ?? '');
    if (p.isEmpty) return 'أدخل رقم الهاتف';
    if (!_egPhone.hasMatch(p)) return 'رقم غير صحيح: يجب أن يبدأ بـ 010 أو 011 أو 012 أو 015 ويتكون من 11 رقم';
    if (RegExp(r'^(\d)\1+$').hasMatch(p.substring(3))) return 'رقم غير صحيح'; // e.g. 01000000000
    return null;
  }

  static final _nameChars = RegExp(r'^[\u0621-\u064A\u0671a-zA-Z ]+$');
  static String? tripleName(String? v) {
    final n = cleanName(v ?? '');
    if (n.isEmpty) return 'أدخل الاسم الثلاثي';
    if (!_nameChars.hasMatch(n)) return 'الاسم يجب أن يحتوي على حروف فقط';
    final parts = n.split(' ');
    if (parts.length < 3 || parts.any((p) => p.length < 2)) return 'أدخل الاسم الثلاثي كاملاً (ثلاث كلمات على الأقل)';
    return null;
  }

  static String? password(String? v) {
    if ((v ?? '').length < 8) return 'كلمة المرور 8 أحرف على الأقل';
    if (!RegExp(r'[A-Za-z]').hasMatch(v!) || !RegExp(r'\d').hasMatch(v)) return 'يجب أن تحتوي على حروف وأرقام';
    return null;
  }

  static String cleanName(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');
}
