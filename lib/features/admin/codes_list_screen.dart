import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import 'admin_repository.dart';

class CodesListScreen extends StatefulWidget { const CodesListScreen({super.key}); @override State<CodesListScreen> createState() => _CL(); }
class _CL extends State<CodesListScreen> {
  final _admin = AdminRepository(); String? _status;
  late Future<List<Map<String, dynamic>>> _f = _admin.codes();
  void _reload() => setState(() => _f = _admin.codes(status: _status));
  static const _ar = {'unused': 'غير مستخدم', 'used': 'مستخدم', 'revoked': 'ملغي'};

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('سجل الأكواد')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, children: [
        for (final e in {null: 'الكل', 'unused': 'غير مستخدم', 'used': 'مستخدم', 'revoked': 'ملغي'}.entries)
          ChoiceChip(label: Text(e.value), selected: _status == e.key, onSelected: (_) { _status = e.key; _reload(); })])),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (s.data!.isEmpty) return const Center(child: Text('لا توجد أكواد'));
        return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: s.data!.length, itemBuilder: (_, i) {
          final r = s.data![i];
          final target = r['units']?['title'] ?? r['courses']?['title'] ?? '-';
          final dur = r['duration'] == 'permanent' ? 'دائم' : '${r['duration_days']} يوم';
          return Card(color: AppColors.surface, child: ListTile(
            title: SelectableText(r['code'], textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.5)),
            subtitle: Text('$target • $dur • ${_ar[r['status']]}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.copy, size: 20), onPressed: () => Clipboard.setData(ClipboardData(text: r['code']))),
              if (r['status'] == 'unused') IconButton(icon: const Icon(Icons.block, size: 20, color: AppColors.error), tooltip: 'إلغاء الكود',
                onPressed: () async { try { await _admin.revokeCode(r['id']); _reload(); } catch (e) { if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(errText(e)))); } }),
            ])));
        });
      })),
    ]));
}
