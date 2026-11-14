import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Opening screen:  gradient + twinkling stars  ->  logo (scale + fade, soft glow)  ->  tagline (+0.5 s)  ->  slim loader  ->  app.
/// Timeline (3.0 s):  logo 0.0-1.1 s | tagline 1.6-2.5 s | loader 1.65-2.55 s | fade into the app at ~3.35 s
class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});
  @override State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _main = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  late final Animation<double> _iconFade  = CurvedAnimation(parent: _main, curve: const Interval(0.00, 0.25, curve: Curves.easeOut));
  late final Animation<double> _iconScale = Tween<double>(begin: 0.55, end: 1.0)
      .animate(CurvedAnimation(parent: _main, curve: const Interval(0.00, 0.37, curve: Curves.easeOutBack)));
  late final Animation<double> _textT     = CurvedAnimation(parent: _main, curve: const Interval(0.53, 0.83, curve: Curves.easeOutCubic));
  late final Animation<double> _loaderT   = CurvedAnimation(parent: _main, curve: const Interval(0.55, 0.85, curve: Curves.easeOut));
  late final Animation<double> _progress  = CurvedAnimation(parent: _main, curve: const Interval(0.55, 1.00, curve: Curves.easeInOut));

  @override void initState() {
    super.initState();
    _main.forward().whenComplete(() async {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => widget.next,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)));
    });
  }

  @override void dispose() { _main.dispose(); _loop.dispose(); super.dispose(); }

  @override Widget build(BuildContext c) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF1F3550), Color(0xFF121C24), Color(0xFF0A1118)], stops: [0.0, 0.55, 1.0])),
      child: AnimatedBuilder(animation: Listenable.merge([_main, _loop]), builder: (_, __) => Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _StarsPainter(_loop.value))),
        Positioned.fill(child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Spacer(flex: 5),
          _logo(),
          const SizedBox(height: 30),
          _tagline(),
          const Spacer(flex: 4),
          _loader(),
          const SizedBox(height: 52),
        ]))),
      ]))));

  Widget _logo() {
    final pulse = 0.5 + 0.5 * math.sin(_loop.value * 2 * math.pi * 3);        // soft breathing glow
    return Opacity(opacity: _iconFade.value, child: Transform.scale(scale: _iconScale.value,
      child: SizedBox(width: 230, height: 230, child: Stack(alignment: Alignment.center, children: [
        Container(width: 230, height: 230, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [
          AppColors.accent.withValues(alpha: 0.26 + 0.12 * pulse), AppColors.accent.withValues(alpha: 0)]))),
        Container(width: 136, height: 136, decoration: BoxDecoration(
          shape: BoxShape.circle, color: AppColors.midnight,
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.32 + 0.18 * pulse), blurRadius: 42, spreadRadius: 2)])),
        CustomPaint(size: const Size(100, 100), painter: _AtomPainter(_loop.value)),
      ]))));
  }

  Widget _tagline() => Opacity(opacity: _textT.value.clamp(0.0, 1.0), child: Transform.translate(
    offset: Offset(0, 24 * (1 - _textT.value)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 46, height: 2, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 18),
      Text('الطرق الوعرة تؤدي للنجوم', textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Amiri', fontSize: 27, fontWeight: FontWeight.w700, color: AppColors.cream, height: 1.6,
          shadows: [Shadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 18)])),
    ])));

  Widget _loader() => Opacity(opacity: _loaderT.value.clamp(0.0, 1.0), child: SizedBox(width: 150,
    child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
      value: _progress.value, minHeight: 3,
      backgroundColor: AppColors.cream.withValues(alpha: 0.12),
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent)))));
}

/// The same atom as the launcher icon: 3 orbits, orbiting electrons, glowing nucleus.
class _AtomPainter extends CustomPainter {
  final double t;
  _AtomPainter(this.t);
  @override void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = AppColors.cream;
    final a = s.width * 0.48, b = s.width * 0.19;
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * math.pi / 3 + t * 2 * math.pi);                        // one slow turn per loop (seamless)
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: a * 2, height: b * 2), ring);
      final th = t * 2 * math.pi * 3 + i * 2.1;
      canvas.drawCircle(Offset(a * math.cos(th), b * math.sin(th)), 3.2, Paint()..color = AppColors.accent);
      canvas.restore();
    }
    canvas.drawCircle(c, s.width * 0.09, Paint()..color = AppColors.accent..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawCircle(c, s.width * 0.07, Paint()..color = AppColors.accent);
  }
  @override bool shouldRepaint(_AtomPainter old) => old.t != t;
}

class _StarsPainter extends CustomPainter {
  final double t;
  _StarsPainter(this.t);
  // (x, y, radius, phase, speed)
  static final List<(double, double, double, double, int)> _stars = () {
    final r = math.Random(7);
    return List.generate(46, (_) => (r.nextDouble(), r.nextDouble(), 0.5 + r.nextDouble() * 1.3, r.nextDouble(), 1 + r.nextInt(3)));
  }();
  @override void paint(Canvas canvas, Size s) {
    final p = Paint();
    for (final st in _stars) {
      final tw = 0.5 + 0.5 * math.sin(2 * math.pi * (t * st.$5 * 2 + st.$4));
      p.color = AppColors.cream.withValues(alpha: 0.12 + 0.55 * tw);
      canvas.drawCircle(Offset(st.$1 * s.width, st.$2 * s.height), st.$3, p);
    }
  }
  @override bool shouldRepaint(_StarsPainter old) => old.t != t;
}
