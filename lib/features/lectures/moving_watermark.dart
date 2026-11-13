import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Anti-piracy overlay: student's name + phone, jumping to a random spot every few seconds.
/// Two independent marks (different rhythms) make cropping/blurring one of them pointless.
class MovingWatermark extends StatelessWidget {
  final String text; final double opacity;
  const MovingWatermark({super.key, required this.text, this.opacity = .38});
  @override Widget build(BuildContext c) => IgnorePointer(child: Stack(fit: StackFit.expand, children: [
    _Mark(text: text, every: const Duration(seconds: 4), opacity: opacity),
    _Mark(text: text, every: const Duration(seconds: 7), opacity: opacity * .75, size: 11),
  ]));
}

class _Mark extends StatefulWidget {
  final String text; final Duration every; final double opacity, size;
  const _Mark({required this.text, required this.every, required this.opacity, this.size = 13});
  @override State<_Mark> createState() => _MS();
}
class _MS extends State<_Mark> {
  final _r = Random.secure(); Timer? _t; Alignment _a = Alignment.center;
  @override void initState() { super.initState(); _jump(); _t = Timer.periodic(widget.every, (_) => _jump()); }
  void _jump() { if (mounted) setState(() => _a = Alignment(_r.nextDouble() * 1.8 - .9, _r.nextDouble() * 1.8 - .9)); }
  @override void dispose() { _t?.cancel(); super.dispose(); }
  @override Widget build(BuildContext c) => AnimatedAlign(alignment: _a, duration: const Duration(milliseconds: 900), curve: Curves.easeInOut,
    child: Directionality(textDirection: TextDirection.ltr, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(6)),
      child: Text(widget.text, style: TextStyle(color: Colors.white.withValues(alpha: widget.opacity + .12), fontSize: widget.size, fontWeight: FontWeight.w600,
          shadows: const [Shadow(blurRadius: 3, color: Colors.black87)])))));
}
