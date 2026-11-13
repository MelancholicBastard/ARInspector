import 'dart:async';

import 'package:flutter/foundation.dart';

import 'detection.dart';

/// Cheap scene-stability heuristic. The anchor also catches accumulated slow drift.
class FrameStability {
  List<int>? _previous;
  List<int>? _anchor;
  Duration? _since;
  Duration? _last;
  bool stable = false;

  double _difference(List<int> a, List<int> b) {
    if (a.length != b.length || a.isEmpty) return 1;
    var sum = 0;
    for (var i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]).abs();
    }
    return sum / a.length / 255;
  }

  bool observe(List<int> sample, Duration now) {
    final moved =
        _previous == null ||
        _last == null ||
        now - _last! > const Duration(milliseconds: 700) ||
        _difference(sample, _previous!) > 0.025 ||
        (_anchor != null && _difference(sample, _anchor!) > 0.045);
    if (moved) {
      _since = now;
      _anchor = List.of(sample);
    }
    _previous = List.of(sample);
    _last = now;
    stable = !moved && now - _since! >= const Duration(milliseconds: 1000);
    return stable;
  }

  void reset() {
    _previous = _anchor = null;
    _since = _last = null;
    stable = false;
  }
}

class InspectionLoop extends ChangeNotifier {
  InspectionLoop({required this.request, required this.publish, this.clock});
  final Duration Function()? clock;
  Duration? _lastObservation;
  Duration get _time => clock?.call() ?? _clock.elapsed;
  int get generation => _generation;
  final Future<List<Detection>> Function() request;
  final ValueChanged<DetectionSnapshot?> publish;
  final stability = FrameStability();
  bool busy = false;
  bool _disposed = false;
  int _generation = 0;
  Duration _nextRequest = Duration.zero;
  DetectionSnapshot? snapshot;
  String? error;
  final _clock = Stopwatch()..start();

  String get status =>
      error ??
      (!stability.stable
          ? 'Зафиксируйте камеру'
          : busy
          ? 'Модель анализирует кадр…'
          : snapshot == null
          ? 'Кадр стабилен'
          : 'Результат получен');

  void observe(List<int> sample) {
    if (_disposed) return;
    final now = _time;
    _lastObservation = now;
    final wasStable = stability.stable;
    final stable = stability.observe(sample, now);
    if (!stable && (wasStable || snapshot != null)) {
      invalidate(resetStability: false);
    }
    if (wasStable != stable) notifyListeners();
    if (stable && !busy && now >= _nextRequest) {
      unawaited(_run(now));
    }
  }

  Future<void> _run(Duration now) async {
    final generation = _generation;
    busy = true;
    error = null;
    final capturedAt = DateTime.now();
    notifyListeners();
    try {
      final result = await request();
      if (_disposed || generation != _generation || !stability.stable) return;
      if (_lastObservation == null ||
          _time - _lastObservation! > const Duration(milliseconds: 700)) {
        invalidate();
        return;
      }
      snapshot = DetectionSnapshot(result, capturedAt);
      publish(snapshot);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = 'Модель недоступна или ответ некорректен. Повтор через 3 с.';
      snapshot = null;
      publish(null);
    } finally {
      busy = false;
      _nextRequest = _time + Duration(milliseconds: error == null ? 500 : 3000);
      if (!_disposed) notifyListeners();
    }
  }

  void invalidate({bool resetStability = true}) {
    if (_disposed) return;
    _generation++;
    snapshot = null;
    error = null;
    if (resetStability) stability.reset();
    publish(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _disposed = true;
    _clock.stop();
    super.dispose();
  }
}
