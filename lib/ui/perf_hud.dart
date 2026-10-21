import 'dart:async';
import 'dart:ui' show FrameTiming, FramePhase;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// With `?perf=1` in the address: a small corner readout of how long frames take (build and drawing) and the frame rate.
/// It takes no mouse clicks and is never shown otherwise (no debug-build notice either).
class PerfHud extends StatefulWidget {
  final Widget child;
  const PerfHud({super.key, required this.child});
  @override
  State<PerfHud> createState() => _PerfHudState();
}

class _PerfHudState extends State<PerfHud> {
  static final bool _perf = kIsWeb && Uri.base.queryParameters['perf'] == '1';
  final List<FrameTiming> _recent = [];
  final ValueNotifier<String> _text = ValueNotifier('measuring…');
  Timer? _timer;

  void _onTimings(List<FrameTiming> t) {
    _recent.addAll(t);
    if (_recent.length > 120) _recent.removeRange(0, _recent.length - 120);
  }

  @override
  void initState() {
    super.initState();
    if (!_perf) return;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now().microsecondsSinceEpoch;
      // frames that finished in the last second
      final last = _recent.where((f) => now - f.timestampInMicroseconds(FramePhase.rasterFinish) < 1000000).toList();
      if (last.isEmpty) {
        _text.value = 'idle (no frames drawn)';
        return;
      }
      double avg(Duration Function(FrameTiming) pick) => last.map(pick).fold<int>(0, (a, d) => a + d.inMicroseconds) / last.length / 1000;
      final build = avg((f) => f.buildDuration), raster = avg((f) => f.rasterDuration), total = avg((f) => f.totalSpan);
      _text.value = '${last.length} frames/s · build ${build.toStringAsFixed(1)} ms · draw ${raster.toStringAsFixed(1)} ms · total ${total.toStringAsFixed(1)} ms';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_perf) SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _text.dispose();
    super.dispose();
  }

  Widget _pill(String text, Color bg) => IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_perf) return widget.child;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        Positioned.fill(child: widget.child),
        Positioned(
            right: 8,
            bottom: 8,
            child: ValueListenableBuilder<String>(valueListenable: _text, builder: (_, t, __) => _pill(t, const Color(0xCC0F172A))),
          ),
      ]),
    );
  }
}
