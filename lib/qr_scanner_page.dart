import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _handled = false;
  Future<void> _lifecycleTask = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs can change lifecycle while startup is still pending.
    if (!_controller.value.hasCameraPermission || _handled) return;
    _lifecycleTask = _lifecycleTask.then((_) async {
      if (!mounted || _handled) return;
      try {
        if (state == AppLifecycleState.resumed) {
          await _controller.start();
        } else {
          await _controller.stop();
        }
      } on MobileScannerException {
        // Camera errors are displayed by MobileScanner.
      }
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || !mounted) return;
    String? value;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        value = raw;
        break;
      }
    }
    if (value == null) return;
    _handled = true;
    // Lock detection before awaiting: a frame may contain repeated QR codes.
    try {
      await _controller.stop();
    } on MobileScannerException {
      // A lifecycle transition may already have stopped the camera.
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pop(value);
  }

  Future<void> _retry() async {
    try {
      await _controller.start();
    } on MobileScannerException {
      // MobileScanner renders the controller's error state below.
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on MobileScannerException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось включить фонарик')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Сканирование QR')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  useAppLifecycleState: false,
                  tapToFocus: true,
                  errorBuilder: (context, error) => _CameraError(
                    permissionDenied:
                        error.errorCode ==
                        MobileScannerErrorCode.permissionDenied,
                    onRetry: _retry,
                  ),
                  overlayBuilder: (context, constraints) => IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD9F4A7),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Наведите камеру на QR-код',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Держите код в кадре и убедитесь, что он хорошо освещён.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (context, state, _) {
                    final available =
                        state.isRunning &&
                        state.torchState != TorchState.unavailable;
                    final isOn = state.torchState == TorchState.on;
                    return FilledButton.tonalIcon(
                      onPressed: available ? _toggleTorch : null,
                      icon: Icon(
                        isOn
                            ? Icons.flashlight_off_rounded
                            : Icons.flashlight_on_rounded,
                      ),
                      label: Text(
                        isOn ? 'Выключить фонарик' : 'Включить фонарик',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.permissionDenied, required this.onRetry});
  final bool permissionDenied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              permissionDenied
                  ? Icons.no_photography_rounded
                  : Icons.videocam_off_rounded,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              permissionDenied ? 'Нужен доступ к камере' : 'Камера недоступна',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              permissionDenied
                  ? 'Разрешите доступ к камере в настройках приложения или браузера, затем повторите попытку.'
                  : 'Проверьте подключение камеры и закройте другие приложения, которые могут её использовать.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Повторить попытку'),
            ),
          ],
        ),
      ),
    ),
  );
}
