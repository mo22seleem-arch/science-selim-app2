import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../courses/models.dart';
import '../lectures/lectures_repository.dart';
import 'manage_content_screen.dart' show confirmDelete;
import 'quiz_builder_screen.dart';

class ManageLecturesScreen extends StatefulWidget { final Unit unit; const ManageLecturesScreen({super.key, required this.unit}); @override State<ManageLecturesScreen> createState() => _ML(); }
class _ML extends State<ManageLecturesScreen> {
  final _repo = LecturesRepository();
  late Future<List<Lecture>> _f = _repo.lectures(widget.unit.id);
  void _reload() => setState(() => _f = _repo.lectures(widget.unit.id));
  void _toast(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));

  Future<void> _edit([Lecture? l, int count = 0]) async {
    final title = TextEditingController(text: l?.title), ref = TextEditingController(text: l?.videoRef);
    String provider = l?.provider ?? 'bunny'; PlatformFile? pdf; bool removePdf = false;
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: AppColors.surface, title: Text(l == null ? 'محاضرة جديدة' : 'تعديل المحاضرة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان المحاضرة')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: provider, decoration: const InputDecoration(labelText: 'مصدر الفيديو'),
          items: const [DropdownMenuItem(value: 'bunny', child: Text('Bunny.net (Video ID — موقّع)')), DropdownMenuItem(value: 'hls', child: Text('رابط HLS مباشر (غير موقّع)'))],
          onChanged: (v) => set(() => provider = v!)),
        const SizedBox(height: 12),
        TextField(controller: ref, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: provider == 'bunny' ? 'Video ID (GUID)' : 'رابط .m3u8')),
        const SizedBox(height: 12),
        OutlinedButton.icon(icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(pdf != null ? pdf!.name : (l?.hasPdf == true && !removePdf ? 'استبدال الملزمة PDF' : 'رفع ملزمة PDF')),
          onPressed: () async { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true); if (r != null) set(() { pdf = r.files.single; removePdf = false; }); }),
        if (l?.hasPdf == true && pdf == null) CheckboxListTile(contentPadding: EdgeInsets.zero, value: removePdf, title: const Text('حذف الملزمة الحالية'), onChanged: (v) => set(() => removePdf = v!)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))])));
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      final id = await _repo.saveLecture(id: l?.id, unitId: widget.unit.id, title: title.text, provider: provider, videoRef: ref.text, order: l == null ? count : 0);
      if (pdf?.bytes != null) { await _repo.uploadPdf(id, pdf!.bytes!); }
      else if (removePdf && l != null) { await _repo.removePdf(l); }
      _reload();
    } catch (e) { _toast(e); }
  }

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('محاضرات: ${widget.unit.title}')),
    body: FutureBuilder<List<Lecture>>(future: _f, builder: (_, s) {
      final list = s.data ?? [];
      return Scaffold(backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(null, list.length), icon: const Icon(Icons.add), label: const Text('محاضرة')),
        body: !s.hasData ? const Center(child: CircularProgressIndicator()) : list.isEmpty ? const Center(child: Text('لا توجد محاضرات')) :
        ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [for (final l in list) Card(color: AppColors.surface, child: ListTile(
          title: Text(l.title), subtitle: Text('${l.hasVideo ? 'فيديو' : 'بدون فيديو'} • ${l.hasPdf ? 'PDF' : 'بدون PDF'}'),
          onTap: () => _edit(l),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'الاختبار', icon: const Icon(Icons.quiz_outlined), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => QuizBuilderScreen(lecture: l)))),
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: () async {
              if (await confirmDelete(c, l.title)) { try { await _repo.deleteLecture(l); _reload(); } catch (e) { _toast(e); } } }),
          ])))]));
    }));
}
