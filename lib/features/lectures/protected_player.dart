import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/security/security_service.dart';
import '../../core/theme/app_theme.dart';
import 'moving_watermark.dart';

class ProtectedPlayer extends StatefulWidget {
  final String url, watermark;
  const ProtectedPlayer({super.key, required this.url, required this.watermark});
  @override State<ProtectedPlayer> createState() => _PP();
}
class _PP extends State<ProtectedPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _v; ChewieController? _c; bool _failed = false; Timer? _t; bool _ext = false;

  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _init();
    _t = Timer.periodic(const Duration(seconds: 3), (_) async {
      final e = await SecurityService.externalDisplay();
      if (!mounted) return; if (e) _v?.pause(); if (e != _ext) setState(() => _ext = e);
    });
  }

  Future<void> _init() async {
    try {
      final v = VideoPlayerController.networkUrl(Uri.parse(widget.url), formatHint: VideoFormat.hls);
      await v.initialize();
      _v = v;
      _c = ChewieController(
        videoPlayerController: v, aspectRatio: v.value.aspectRatio, autoPlay: false, allowedScreenSleep: false,
        allowPlaybackSpeedChanging: true, playbackSpeeds: const [0.75, 1, 1.25, 1.5, 2],
        overlay: MovingWatermark(text: widget.watermark),        // also shown in fullscreen
        deviceOrientationsAfterFullScreen: const [],
        materialProgressColors: ChewieProgressColors(playedColor: AppColors.accent, handleColor: AppColors.cream,
            backgroundColor: Colors.white24, bufferedColor: Colors.white38),
        errorBuilder: (_, m) => const Center(child: Text('تعذر تشغيل الفيديو')));
      if (mounted) setState(() {});
    } catch (_) { if (mounted) setState(() => _failed = true); }
  }

  // leaving the app (recents, screen-recorder overlays, etc.) pauses playback
  @override void didChangeAppLifecycleState(AppLifecycleState s) { if (s != AppLifecycleState.resumed) _v?.pause(); }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel(); _c?.dispose(); _v?.dispose(); super.dispose();
  }

  @override Widget build(BuildContext c) {
    if (_failed) return const AspectRatio(aspectRatio: 16 / 9, child: Center(child: Text('تعذر تحميل الفيديو، تحقق من الاتصال')));
    if (_c == null) return const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()));
    final ratio = _v!.value.aspectRatio;
    return Container(color: Colors.black, child: AspectRatio(aspectRatio: ratio, child: _ext
        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('تم اكتشاف شاشة خارجية / بث. افصلها لمتابعة المشاهدة', textAlign: TextAlign.center)))
        : Chewie(controller: _c!)));
  }
}
