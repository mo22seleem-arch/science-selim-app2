import 'package:flutter/material.dart';
import '../auth/auth_repository.dart';
import 'lectures_repository.dart';
import 'protected_player.dart';
import 'quiz_view.dart';
import 'secure_pdf_viewer.dart';

class _Data { final Map<String, dynamic> profile; final String? videoUrl; final Map<String, dynamic>? quiz; final bool videoFailed;
  _Data(this.profile, this.videoUrl, this.quiz, this.videoFailed); }

class LectureScreen extends StatefulWidget {
  final Lecture lecture;
  const LectureScreen({super.key, required this.lecture});
  @override State<LectureScreen> createState() => _LS();
}
class _LS extends State<LectureScreen> {
  final _repo = LecturesRepository();
  late Future<_Data> _f = _load();

  Future<_Data> _load() async {
    final profile = await AuthRepository().myProfile();
    String? url; bool failed = false;
    if (widget.lecture.hasVideo) { try { url = await _repo.mediaUrl(widget.lecture.id, 'video'); } catch (_) { failed = true; } }
    return _Data(profile, url, await _repo.quizFor(widget.lecture.id), failed);
  }

  @override Widget build(BuildContext c) => FutureBuilder<_Data>(future: _f, builder: (_, s) {
    if (s.connectionState != ConnectionState.done) return Scaffold(appBar: AppBar(title: Text(widget.lecture.title)), body: const Center(child: CircularProgressIndicator()));
    if (s.hasError) return Scaffold(appBar: AppBar(title: Text(widget.lecture.title)), body: const Center(child: Text('تعذر تحميل المحاضرة')));
    final d = s.data!; final l = widget.lecture;
    final mark = '${d.profile['full_name']} • ${d.profile['phone']}';
    final tabs = <(String, IconData, Widget)>[
      if (l.hasVideo) ('الفيديو', Icons.play_circle_outline, d.videoFailed || d.videoUrl == null
          ? const Center(child: Text('لا تملك صلاحية تشغيل الفيديو أو حدث خطأ'))
          : SingleChildScrollView(child: ProtectedPlayer(url: d.videoUrl!, watermark: mark))),
      if (l.hasPdf) ('الملزمة', Icons.picture_as_pdf_outlined, SecurePdfViewer(lectureId: l.id, watermark: mark)),
      if (d.quiz != null) ('الاختبار', Icons.quiz_outlined, QuizView(quiz: d.quiz!)),
    ];
    if (tabs.isEmpty) return Scaffold(appBar: AppBar(title: Text(l.title)), body: const Center(child: Text('لم يُضف محتوى لهذه المحاضرة بعد')));
    return DefaultTabController(length: tabs.length, child: Scaffold(
      appBar: AppBar(title: Text(l.title), bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t.$1, icon: Icon(t.$2))])),
      body: TabBarView(physics: const NeverScrollableScrollPhysics(), children: [for (final t in tabs) t.$3])));
  });
}
