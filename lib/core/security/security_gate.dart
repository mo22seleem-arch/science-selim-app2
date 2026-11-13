import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'security_service.dart';

class SecurityGate extends StatelessWidget {
  final Widget child;
  const SecurityGate({super.key, required this.child});
  @override Widget build(BuildContext c) => FutureBuilder<List<String>>(future: SecurityService.threats(), builder: (_, s) {
    if (s.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return (s.data ?? []).isEmpty ? child : const _Blocked();
  });
}

class _Blocked extends StatelessWidget {
  const _Blocked();
  @override Widget build(BuildContext c) => const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.gpp_bad_outlined, size: 72, color: AppColors.error), SizedBox(height: 16),
    Text('هذا الجهاز غير مدعوم لأسباب أمنية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center), SizedBox(height: 10),
    Text('لا يمكن تشغيل التطبيق على أجهزة معدّلة (روت) أو محاكيات أو مع أدوات تحليل. استخدم هاتفاً عادياً ثم حاول مرة أخرى.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
  ]))));
}
