import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'detection.dart';
import 'detection_api.dart';
import 'detection_overlay.dart';
import 'inspection_frame.dart';
import 'inspection_loop.dart';

class InspectionPage extends StatefulWidget {
  const InspectionPage({
    super.key,
    required this.serverUrl,
    required this.onChanged,
  });
  final String serverUrl;
  final ValueChanged<DetectionSnapshot?> onChanged;

  @override
  State<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends State<InspectionPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  late final DetectionApi _api;
  late final InspectionLoop _loop;
  CameraImage? _latestRaw;
  EncodedFrame? _latestEncoded;
  final _clock = Stopwatch()..start();
  Duration? _lastFrameAt;
  Duration _sampledAt = const Duration(seconds: -1);
  int _rotation = 0;
  DeviceOrientation? _previewOrientation;
  int _cameraRevision = 0;
  bool _active = true;
  bool _polling = false;
  String? _cameraError;
  Future<void> _cameraWork = Future.value();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _api = DetectionApi(widget.serverUrl);
    _loop = InspectionLoop(request: _request, publish: widget.onChanged)
      ..addListener(_redraw);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loop.invalidate();
      _scheduleCamera();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted || !_active) return;
      if (_lastFrameAt != null &&
          _clock.elapsed - _lastFrameAt! > const Duration(milliseconds: 700)) {
        _lastFrameAt = null;
        _loop.invalidate();
      }
      final camera = _camera;
      if (camera != null &&
          camera.value.isInitialized &&
          !camera.supportsImageStreaming()) {
        unawaited(_pollStill(camera));
      }
    });
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _loop.invalidate();
      _api.close();
      _latestRaw = null;
      _latestEncoded = null;
    }
    _scheduleCamera();
  }

  void _scheduleCamera() {
    final revision = ++_cameraRevision;
    _cameraWork = _cameraWork.then((_) => _configureCamera(revision));
  }

  Future<void> _configureCamera(int revision) async {
    if (!mounted || revision != _cameraRevision) return;
    final old = _camera;
    old?.removeListener(_cameraStateChanged);
    _camera = null;
    _latestRaw = null;
    _latestEncoded = null;
    _lastFrameAt = null;
    _loop.invalidate();
    setState(() => _cameraError = null);
    try {
      await old?.dispose();
    } catch (_) {
      /* Already closed by platform. */
    }
    if (!mounted || !_active || revision != _cameraRevision) return;
    CameraController? camera;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'Камера не найдена');
      }
      final back = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      camera = CameraController(
        back.isEmpty
            ? throw CameraException('NoBackCamera', 'Нужна задняя камера')
            : back.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await camera.initialize();
      if (!mounted || !_active || revision != _cameraRevision) {
        await camera.dispose();
        return;
      }
      _camera = camera;
      _previewOrientation = camera.value.deviceOrientation;
      camera.addListener(_cameraStateChanged);
      if (camera.supportsImageStreaming()) {
        await camera.startImageStream(_onFrame);
      }
      if (mounted) setState(() {});
    } catch (_) {
      try {
        await camera?.dispose();
      } catch (_) {
        /* Release partial startup. */
      }
      if (identical(_camera, camera)) _camera = null;
      if (mounted && revision == _cameraRevision) {
        setState(
          () => _cameraError = 'Камера недоступна. Разрешите доступ в настройках и повторите попытку.',
        );
      }
    }
  }

  void _cameraStateChanged() {
    if (!mounted || !_active) return;
    final orientation = _camera?.value.deviceOrientation;
    if (orientation != _previewOrientation) {
      _previewOrientation = orientation;
      _loop.invalidate();
    }
  }

  int _frameRotation(CameraController camera) {
    final device = switch (camera.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return (camera.description.sensorOrientation - device + 360) % 360;
  }

  void _onFrame(CameraImage image) {
    if (!mounted || !_active || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final now = _clock.elapsed;
    if (now - _sampledAt < const Duration(milliseconds: 180)) return;
    _sampledAt = now;
    try {
      final rotation = _frameRotation(_camera!);
      if (_rotation != rotation ||
          (_latestRaw != null &&
              (_latestRaw!.width != image.width ||
                  _latestRaw!.height != image.height))) {
        _loop.invalidate();
      }
      _rotation = rotation;
      _latestRaw = image;
      _lastFrameAt = now;
      _loop.observe(sampleLuminance(image));
    } catch (_) {
      _loop.invalidate();
      setState(
        () =>
            _cameraError = 'Формат кадров этой камеры пока не поддерживается.',
      );
    }
  }

  Future<void> _pollStill(CameraController camera) async {
    if (_polling || !_active || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _polling = true;
    try {
      final shot = await camera.takePicture();
      final frame = await compute(prepareStillFrame, await shot.readAsBytes());
      if (!mounted || !_active || !identical(camera, _camera)) return;
      if (_latestEncoded != null &&
          (_latestEncoded!.width != frame.width ||
              _latestEncoded!.height != frame.height)) {
        _loop.invalidate();
      }
      _latestEncoded = frame;
      _lastFrameAt = _clock.elapsed;
      _loop.observe(frame.sample);
    } catch (_) {
      if (mounted && _active && identical(camera, _camera)) {
        _loop.invalidate();
        setState(
          () => _cameraError =
              'Не удалось получить кадр камеры. Повторите попытку.',
        );
      }
    } finally {
      _polling = false;
    }
  }

  Future<List<Detection>> _request() async {
    final generation = _loop.generation;
    final EncodedFrame frame;
    if (_latestRaw != null) {
      final copy = InspectionFrame(_latestRaw!, _rotation);
      frame = await compute(encodeInspectionFrame, copy);
    } else if (_latestEncoded != null) {
      frame = _latestEncoded!;
    } else {
      throw StateError('Нет кадра');
    }
    // Movement during JPEG conversion invalidates the entire request.
    if (!mounted ||
        !_active ||
        !_loop.stability.stable ||
        generation != _loop.generation) {
      throw StateError('Кадр устарел');
    }
    return _api.detect(frame.jpeg, frame.width, frame.height);
  }

  @override
  void dispose() {
    _active = false;
    _cameraRevision++;
    _timer?.cancel();
    _camera?.removeListener(_cameraStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _loop.removeListener(_redraw);
    _loop.dispose();
    _api.close();
    unawaited(
      _cameraWork.then((_) async {
        try {
          await _camera?.dispose();
        } catch (_) {
          /* Best-effort release. */
        }
      }),
    );
    super.dispose();
  }

  Widget _preview(CameraController camera) {
    final overlay = IgnorePointer(
      child: CustomPaint(
        painter: DetectionOverlay(
          _loop.snapshot?.detections ?? const [],
          Directionality.of(context),
        ),
      ),
    );
    if (kIsWeb) {
      final frame = _latestEncoded;
      return AspectRatio(
        aspectRatio: frame == null
            ? camera.value.aspectRatio
            : frame.width / frame.height,
        child: Stack(
          fit: StackFit.expand,
          children: [camera.buildPreview(), overlay],
        ),
      );
    }
    return CameraPreview(camera, child: overlay);
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final ready = camera != null && camera.value.isInitialized;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Осмотр с моделью'),
        actions: [
          IconButton(
            tooltip: 'Показать результаты',
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.list_alt_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: ColoredBox(
                    color: Colors.black,
                    child: _cameraError != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _cameraError!,
                                    style: const TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.tonal(
                                    onPressed: _scheduleCamera,
                                    child: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : !ready
                        ? const Center(child: CircularProgressIndicator())
                        : Center(child: _preview(camera)),
                  ),
                ),
              ),
            ),
            Flexible(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pan_tool_outlined, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text('Не шевелите камерой во время осмотра'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loop.status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (_loop.busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
