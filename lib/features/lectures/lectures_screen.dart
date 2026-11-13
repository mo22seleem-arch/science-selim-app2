import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../courses/models.dart';
import 'lecture_screen.dart';
import 'lectures_repository.dart';

class LecturesScreen extends StatelessWidget {
  final Unit unit;
  const LecturesScreen({super.key, required this.unit});
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: Text(unit.title)),
    body: FutureBuilder<List<Lecture>>(future: LecturesRepository().lectures(unit.id), builder: (_, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return const Center(child: Text('تعذر تحميل المحاضرات'));
      if (s.data!.isEmpty) return const Center(child: Text('لا توجد محاضرات بعد'));
      return ListView.separated(padding: const EdgeInsets.all(16), itemCount: s.data!.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) { final l = s.data![i];
          return Material(color: AppColors.surface, borderRadius: BorderRadius.circular(14), child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: CircleAvatar(backgroundColor: AppColors.midnight, child: Text('${i + 1}')), title: Text(l.title),
            subtitle: Row(children: [if (l.hasVideo) const Icon(Icons.play_circle_outline, size: 16), if (l.hasPdf) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.picture_as_pdf_outlined, size: 16))]),
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => LectureScreen(lecture: l)))));
        });
    }));
}
