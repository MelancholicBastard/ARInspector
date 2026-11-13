import 'package:ar_inspector/app_theme.dart';
import 'package:ar_inspector/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Home offers QR identification without opening the camera', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('AR Инспектор'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Сканировать QR-код'), 200);
    expect(find.text('Сканировать QR-код'), findsOneWidget);
    expect(find.text('QR-код считан'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Result preserves payload and copies it to clipboard', (
    tester,
  ) async {
    const payload = 'оборудование:НАСОС-42\nhttps://example.com/equipment/42';
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: QrResultCard(value: payload)),
      ),
    );
    expect(find.text(payload), findsOneWidget);
    await tester.tap(find.text('Копировать'));
    await tester.pump();
    expect(copied, payload);
    expect(find.text('Содержимое QR-кода скопировано'), findsOneWidget);
  });

  testWidgets('Home fits a narrow screen with large text in dark theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const InspectorHome(),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Сканировать QR-код'), 200);
    expect(tester.takeException(), isNull);
  });
}
