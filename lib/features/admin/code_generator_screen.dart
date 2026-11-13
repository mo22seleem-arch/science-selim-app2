import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../courses/courses_repository.dart';
import '../courses/models.dart';
import 'admin_repository.dart';

class CodeGeneratorScreen extends StatefulWidget { const CodeGeneratorScreen({super.key}); @override State<CodeGeneratorScreen> createState() => _CG(); }
class _CG extends State<CodeGeneratorScreen> {
  final _repo = CoursesRepository(), _admin = AdminRepository();
  final _count = TextEditingController(text: '10'), _days = TextEditingController(text: '30');
  List<Course> _courses = []; List<Unit> _units = [];
  Course? _course; Unit? _unit;
  bool _forUnit = false, _permanent = true, _busy = false; DateTime? _redeemBefore; List<String> _out = []; String? _err;

  @override void initState() { super.initState(); _repo.courses().then((v) { if (mounted) setState(() => _courses = v.where((c) => !c.free).toList()); }); }

  Future<void> _pickCourse(Course? co) async {
    setState(() { _course = co; _unit = null; _units = []; });
    if (co != null) { final u = await _repo.units(co.id); if (mounted) setState(() => _units = u.where((x) => !x.free).toList()); }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 1095)));
    if (d != null) setState(() => _redeemBefore = DateTime(d.year, d.month, d.day, 23, 59));
  }

  Future<void> _generate() async {
    final n = int.tryParse(_count.text), days = int.tryParse(_days.text);
    if (_course == null || (_forUnit && _unit == null)) { setState(() => _err = 'اختر الكورس${_forUnit ? ' والوحدة' : ''}'); return; }
    if (n == null || n < 1 || n > 500) { setState(() => _err = 'العدد من 1 إلى 500'); return; }
    if (!_permanent && (days == null || days < 1)) { setState(() => _err = 'أدخل عدد أيام صحيح'); return; }
    setState(() { _busy = true; _err = null; _out = []; });
    try {
      final r = await _admin.generateCodes(count: n, courseId: _forUnit ? null : _course!.id, unitId: _forUnit ? _unit!.id : null,
          permanent: _permanent, days: days, redeemBefore: _redeemBefore);
      setState(() => _out = r);
    } catch (e) { setState(() => _err = errText(e)); }
    if (mounted) setState(() => _busy = false);
  }

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('توليد أكواد التفعيل')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('كورس كامل')), ButtonSegment(value: true, label: Text('وحدة محددة'))],
          selected: {_forUnit}, onSelectionChanged: (s) => setState(() { _forUnit = s.first; _unit = null; })),
      const SizedBox(height: 14),
      DropdownButtonFormField<Course>(value: _course, decoration: const InputDecoration(labelText: 'الكورس (المدفوع فقط)'),
          items: [for (final co in _courses) DropdownMenuItem(value: co, child: Text(co.title))], onChanged: _pickCourse),
      if (_forUnit) ...[const SizedBox(height: 12), DropdownButtonFormField<Unit>(value: _unit, decoration: const InputDecoration(labelText: 'الوحدة'),
          items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(u.title))], onChanged: (u) => setState(() => _unit = u))],
      const SizedBox(height: 12),
      TextField(controller: _count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الأكواد')),
      const SizedBox(height: 12),
      SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('دائم')), ButtonSegment(value: false, label: Text('مؤقت'))],
          selected: {_permanent}, onSelectionChanged: (s) => setState(() => _permanent = s.first)),
      if (!_permanent) ...[const SizedBox(height: 12), TextField(controller: _days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدة الاشتراك بالأيام (تبدأ من لحظة التفعيل)'))],
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.event_outlined),
          label: Text(_redeemBefore == null ? 'آخر موعد لاستخدام الكود (اختياري)' : 'يُستخدم قبل ${_redeemBefore!.toLocal().toString().substring(0, 10)}')),
      if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: const TextStyle(color: AppColors.error))),
      const SizedBox(height: 18),
      ElevatedButton(onPressed: _busy ? null : _generate, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('توليد الأكواد')),
      if (_out.isNotEmpty) ...[
        const SizedBox(height: 22),
        Row(children: [Expanded(child: Text('تم توليد ${_out.length} كود', style: Theme.of(c).textTheme.titleMedium)),
          TextButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: _out.join('\n'))); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تم نسخ كل الأكواد'))); },
              icon: const Icon(Icons.copy_all), label: const Text('نسخ الكل'))]),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(_out.join('\n'), textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.5, height: 1.7))),
      ],
    ]));
}
