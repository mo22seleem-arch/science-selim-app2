import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import 'courses_repository.dart';

/// Returns true when the code unlocked the target.
Future<bool?> showRedeemSheet(BuildContext c, {required String title, String? courseId, String? unitId}) =>
    showModalBottomSheet<bool>(context: c, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: _Redeem(title: title, courseId: courseId, unitId: unitId)));

class _Redeem extends StatefulWidget {
  final String title; final String? courseId, unitId;
  const _Redeem({required this.title, this.courseId, this.unitId});
  @override State<_Redeem> createState() => _RS();
}
class _RS extends State<_Redeem> {
  final _code = TextEditingController(); bool _busy = false; String? _err;

  Future<void> _go() async {
    final v = _code.text.trim();
    if (v.length < 8) { setState(() => _err = 'أدخل الكود كاملاً'); return; }
    setState(() { _busy = true; _err = null; });
    try {
      await CoursesRepository().redeem(v, courseId: widget.courseId, unitId: widget.unitId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() { _err = errText(e); _busy = false; }); }
  }

  @override Widget build(BuildContext c) => Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text('تفعيل: ${widget.title}', style: Theme.of(c).textTheme.titleLarge, textAlign: TextAlign.center),
    const SizedBox(height: 16),
    TextField(controller: _code, textCapitalization: TextCapitalization.characters, textDirection: TextDirection.ltr,
        textAlign: TextAlign.center, style: const TextStyle(letterSpacing: 3, fontSize: 18),
        decoration: InputDecoration(labelText: 'كود التفعيل', errorText: _err)),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: _busy ? null : _go,
        child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('تفعيل')),
  ]));
}
