import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'lectures_repository.dart';

class QuizView extends StatefulWidget {
  final Map<String, dynamic> quiz;
  const QuizView({super.key, required this.quiz});
  @override State<QuizView> createState() => _QV();
}
class _QV extends State<QuizView> {
  final _repo = LecturesRepository();
  late Future<List<Map<String, dynamic>>> _f = _repo.questions(widget.quiz['id']);
  final Map<String, int> _ans = {}; Map<String, dynamic>? _result; bool _busy = false; String? _err;

  Future<void> _submit(int total) async {
    setState(() { _busy = true; _err = null; });
    try { _result = await _repo.submitQuiz(widget.quiz['id'], _ans); }
    catch (_) { _err = 'تعذر إرسال الإجابات، حاول مرة أخرى'; }
    if (mounted) setState(() => _busy = false);
  }

  @override Widget build(BuildContext c) => FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, s) {
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    final qs = s.data!;
    if (qs.isEmpty) return const Center(child: Text('لا توجد أسئلة في هذا الاختبار بعد'));
    final review = {for (final r in (_result?['review'] as List? ?? [])) r['id'] as String: r};
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (_result != null) _summary(c),
      for (var i = 0; i < qs.length; i++) _question(c, i, qs[i], review[qs[i]['id']]),
      if (_err != null) Text(_err!, style: const TextStyle(color: AppColors.error)),
      const SizedBox(height: 10),
      if (_result == null) ElevatedButton(onPressed: (_busy || _ans.length < qs.length) ? null : () => _submit(qs.length),
          child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text('تسليم الإجابات (${_ans.length}/${qs.length})'))
      else OutlinedButton.icon(onPressed: () => setState(() { _result = null; _ans.clear(); }), icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
    ]);
  });

  Widget _summary(BuildContext c) {
    final ok = _result!['passed'] == true;
    return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: (ok ? Colors.green : AppColors.error).withOpacity(.14), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ok ? Colors.greenAccent : AppColors.error)),
      child: Column(children: [
        Text('${_result!['score']}%', style: Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
        Text('${_result!['correct']} من ${_result!['total']} إجابة صحيحة'),
        const SizedBox(height: 6), Text(ok ? 'أحسنت! لقد نجحت 🎉' : 'لم تصل إلى درجة النجاح، راجع الإجابات وحاول مرة أخرى'),
      ]));
  }

  Widget _question(BuildContext c, int i, Map<String, dynamic> q, Map<String, dynamic>? rev) {
    final opts = (q['options'] as List).cast<String>(); final id = q['id'] as String;
    return Card(color: AppColors.surface, margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${i + 1}. ${q['body']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.5)),
      const SizedBox(height: 8),
      for (var k = 0; k < opts.length; k++) _option(id, k, opts[k], rev),
    ])));
  }

  Widget _option(String id, int k, String text, Map<String, dynamic>? rev) {
    final picked = _ans[id] == k; Color? border; IconData icon = picked ? Icons.radio_button_checked : Icons.radio_button_off;
    if (rev != null) {
      if (k == rev['correct_index']) { border = Colors.greenAccent; icon = Icons.check_circle; }
      else if (picked) { border = AppColors.error; icon = Icons.cancel; }
    } else if (picked) { border = AppColors.accent; }
    return Padding(padding: const EdgeInsets.only(top: 6), child: InkWell(borderRadius: BorderRadius.circular(12),
      onTap: rev != null ? null : () => setState(() => _ans[id] = k),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border ?? AppColors.cream.withOpacity(.2))),
        child: Row(children: [Icon(icon, size: 20, color: border ?? AppColors.muted), const SizedBox(width: 10), Expanded(child: Text(text))]))));
  }
}
