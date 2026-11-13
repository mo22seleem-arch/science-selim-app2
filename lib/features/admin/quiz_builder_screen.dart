import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../lectures/lectures_repository.dart';

class QuizBuilderScreen extends StatefulWidget { final Lecture lecture; const QuizBuilderScreen({super.key, required this.lecture}); @override State<QuizBuilderScreen> createState() => _QB(); }
class _QB extends State<QuizBuilderScreen> {
  final _repo = LecturesRepository();
  Map<String, dynamic>? _quiz; List<Map<String, dynamic>> _qs = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final q = await _repo.quizFor(widget.lecture.id);
    final qs = q == null ? <Map<String, dynamic>>[] : await _repo.questionsWithKeys(q['id']);
    if (mounted) setState(() { _quiz = q; _qs = qs; _loading = false; });
  }
  void _toast(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
  int _key(Map<String, dynamic> q) { final k = q['question_keys']; return (k is List ? (k.isEmpty ? null : k.first['correct_index']) : k?['correct_index']) ?? -1; }

  Future<void> _addQuestion() async {
    final body = TextEditingController(); final opts = List.generate(4, (_) => TextEditingController()); int correct = 0; String? err;
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: AppColors.surface, title: const Text('سؤال جديد'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: body, maxLines: 2, decoration: const InputDecoration(labelText: 'نص السؤال')),
        for (var i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: opts[i], decoration: InputDecoration(labelText: 'الاختيار ${i + 1}${i > 1 ? ' (اختياري)' : ''}'))),
        const SizedBox(height: 12), const Align(alignment: Alignment.centerRight, child: Text('الإجابة الصحيحة:')),
        SegmentedButton<int>(segments: [for (var i = 0; i < 4; i++) ButtonSegment(value: i, label: Text('${i + 1}'))], selected: {correct}, onSelectionChanged: (s) => set(() => correct = s.first)),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: AppColors.error))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () {
          final filled = [for (final o in opts) o.text.trim()];
          if (body.text.trim().isEmpty || filled[0].isEmpty || filled[1].isEmpty) { set(() => err = 'اكتب السؤال واختيارين على الأقل'); return; }
          if (filled[correct].isEmpty) { set(() => err = 'الإجابة الصحيحة لا يمكن أن تكون فارغة'); return; }
          Navigator.pop(ctx, true);
        }, child: const Text('حفظ'))])));
    if (ok != true) return;
    // keep positions stable: drop empty options but remap the correct index
    final all = [for (final o in opts) o.text.trim()]; final kept = <String>[]; int newCorrect = 0;
    for (var i = 0; i < all.length; i++) { if (all[i].isEmpty) continue; if (i == correct) newCorrect = kept.length; kept.add(all[i]); }
    try { await _repo.addQuestion(_quiz!['id'], body.text, kept, newCorrect, _qs.length); await _load(); } catch (e) { _toast(e); }
  }

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('اختبار: ${widget.lecture.title}'), actions: [
      if (_quiz != null) IconButton(tooltip: 'حذف الاختبار', icon: const Icon(Icons.delete_outline), onPressed: () async { try { await _repo.deleteQuiz(_quiz!['id']); await _load(); } catch (e) { _toast(e); } })]),
    floatingActionButton: _quiz == null ? null : FloatingActionButton.extended(onPressed: _addQuestion, icon: const Icon(Icons.add), label: const Text('سؤال')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _quiz == null
      ? Center(child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(220, 54)), onPressed: () async { try { await _repo.createQuiz(widget.lecture.id, 50); await _load(); } catch (e) { _toast(e); } }, child: const Text('إنشاء اختبار')))
      : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
          Row(children: [const Text('درجة النجاح: '), DropdownButton<int>(value: _quiz!['pass_percent'], items: [for (final p in [40, 50, 60, 70, 80, 90]) DropdownMenuItem(value: p, child: Text('$p%'))],
            onChanged: (v) async { await _repo.setPass(_quiz!['id'], v!); await _load(); })]),
          if (_qs.isEmpty) const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('أضف أول سؤال'))),
          for (var i = 0; i < _qs.length; i++) Card(color: AppColors.surface, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${i + 1}. ${_qs[i]['body']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () async { try { await _repo.deleteQuestion(_qs[i]['id']); await _load(); } catch (e) { _toast(e); } })]),
            for (var k = 0; k < (_qs[i]['options'] as List).length; k++) Padding(padding: const EdgeInsets.only(top: 3), child: Row(children: [
              Icon(k == _key(_qs[i]) ? Icons.check_circle : Icons.circle_outlined, size: 18, color: k == _key(_qs[i]) ? Colors.greenAccent : AppColors.muted), const SizedBox(width: 8), Expanded(child: Text('${(_qs[i]['options'] as List)[k]}'))])),
          ]))),
        ]));
}
