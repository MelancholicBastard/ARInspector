import 'dart:async';

import 'package:ar_inspector/main.dart';
import 'package:ar_inspector/qr_scanner_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FakeScanner extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  int starts = 0;
  int stops = 0;
  bool denied = false;
  StartOptions? options;

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    options = startOptions;
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(640, 480),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late FakeScanner scanner;
  late MobileScannerPlatform original;

  setUp(() {
    original = MobileScannerPlatform.instance;
    scanner = FakeScanner();
    MobileScannerPlatform.instance = scanner;
  });
  tearDown(() async {
    MobileScannerPlatform.instance = original;
    await scanner.captures.close();
  });

  testWidgets('QR returns once, ignores empty payload, and can scan again', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.scrollUntilVisible(find.text('Сканировать QR-код'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сканировать QR-код'));
    await tester.pumpAndSettle();
    expect(scanner.options?.formats, [BarcodeFormat.qrCode]);
    scanner.captures.add(
      BarcodeCapture(barcodes: [const Barcode(rawValue: '   ')]),
    );
    await tester.pump();
    expect(find.byType(QrScannerPage), findsOneWidget);
    final capture = BarcodeCapture(
      barcodes: [const Barcode(rawValue: 'PUMP-42')],
    );
    scanner.captures.add(capture);
    scanner.captures.add(capture);
    await tester.pumpAndSettle();
    expect(find.text('PUMP-42'), findsOneWidget);
    expect(find.byType(InspectorHome), findsOneWidget);
    await tester.tap(find.text('Объекты'));
    await tester.pumpAndSettle();
    expect(find.text('Код готов к поиску'), findsOneWidget);
    expect(find.text('PUMP-42'), findsOneWidget);
    await tester.tap(find.text('Сканер'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Сканировать ещё'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сканировать ещё'));
    await tester.pumpAndSettle();
    expect(find.byType(QrScannerPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('PUMP-42'), findsOneWidget);
  });

  testWidgets('Camera stops in background and restarts on resume', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: QrScannerPage()));
    await tester.pumpAndSettle();
    expect(scanner.starts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(scanner.stops, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(scanner.starts, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Permission denial explains recovery and allows retry', (
    tester,
  ) async {
    scanner.denied = true;
    await tester.pumpWidget(const MaterialApp(home: QrScannerPage()));
    await tester.pumpAndSettle();
    expect(find.text('Нужен доступ к камере'), findsOneWidget);
    scanner.denied = false;
    await tester.tap(find.text('Повторить попытку'));
    await tester.pumpAndSettle();
    expect(find.text('Нужен доступ к камере'), findsNothing);
    expect(scanner.starts, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
