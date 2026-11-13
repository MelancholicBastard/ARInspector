import 'dart:async';
import 'dart:typed_data';

import 'package:ar_inspector/detection.dart';
import 'package:ar_inspector/detection_api.dart';
import 'package:ar_inspector/detection_overlay.dart';
import 'package:ar_inspector/inspection_frame.dart';
import 'package:ar_inspector/inspection_loop.dart';
import 'package:ar_inspector/objects_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

const responseText =
    'pipe: 43.23% at [526.345345, 126.345453, 571.645751953125, 176.345435]\n'
    'rust: 41.03% at [1.34564536, 109.345534, 378.345435, 254.345534]';

void main() {
  test('Parses fractional XYXY pixels and scales to preview bounds', () {
    final found = parseDetections(responseText, 640, 480);
    expect(found.map((d) => d.label), ['pipe', 'rust']);
    expect(found.first.confidence, closeTo(0.4323, 0.00001));
    final box = detectionRect(found.first.box, const Size(320, 240));
    expect(box.left, closeTo(526.345345 / 2, 0.0001));
    expect(box.bottom, closeTo(176.345435 / 2, 0.0001));
    expect(parseDetections('', 640, 480), isEmpty);
    expect(
      parseDetections('rust: 99% at [-10,-10,900,900]', 640, 480).single.box,
      const Rect.fromLTRB(0, 0, 1, 1),
    );
    for (final invalid in [
      'bad',
      'rust: 200% at [0,0,20,20]',
      'rust: 30% at [20,20,0,0]',
      'rust: 30% at [0,0,NaN,30]',
    ]) {
      expect(() => parseDetections(invalid, 640, 480), throwsFormatException);
    }
  });

  test('Uploads JPEG to configured base path as multipart image', () async {
    final api = DetectionApi(
      'http://10.0.2.2:8000/api/',
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/api/detect');
        expect(request.method, 'POST');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(request.body, contains('name="image"; filename="frame.jpg"'));
        expect(request.body, contains('image/jpeg'));
        return http.Response(responseText, 200);
      }),
    );
    expect(
      await api.detect(Uint8List.fromList([1, 2, 3]), 640, 480),
      hasLength(2),
    );
  });

  test(
    'HTTP failures and malformed responses are not successful detections',
    () async {
      final api = DetectionApi(
        'https://server.local',
        clientFactory: () =>
            MockClient((_) async => http.Response('unavailable', 503)),
      );
      await expectLater(api.detect(Uint8List(0), 640, 480), throwsStateError);
      final malformed = DetectionApi(
        'https://server.local',
        clientFactory: () =>
            MockClient((_) async => http.Response('not a detection', 200)),
      );
      await expectLater(
        malformed.detect(Uint8List(0), 640, 480),
        throwsFormatException,
      );
    },
  );

  test(
    'Still-frame fallback preserves aspect and prepares luminance sample',
    () {
      final image = img.Image(width: 1600, height: 800);
      img.fill(image, color: img.ColorRgb8(100, 100, 100));
      final frame = prepareStillFrame(img.encodeJpg(image));
      expect([frame.width, frame.height], [640, 320]);
      expect(frame.sample, hasLength(576));
      expect(frame.sample.first, closeTo(100, 3));
      expect(img.decodeJpg(frame.jpeg)!.width, 640);
    },
  );

  group('Stability and slow inference', () {
    late Duration now;
    late InspectionLoop loop;
    late List<Completer<List<Detection>>> requests;
    late List<DetectionSnapshot?> published;
    void frame(int ms, [int value = 100]) {
      now = Duration(milliseconds: ms);
      loop.observe(List.filled(16, value));
    }

    void steady(int start, [int value = 100]) {
      for (var ms = start; ms <= start + 1000; ms += 200) {
        frame(ms, value);
      }
    }

    setUp(() {
      now = Duration.zero;
      requests = [];
      published = [];
      loop = InspectionLoop(
        clock: () => now,
        publish: published.add,
        request: () {
          final pending = Completer<List<Detection>>();
          requests.add(pending);
          return pending.future;
        },
      );
    });
    tearDown(() => loop.dispose());

    test(
      'Waits one second then keeps one request during a two-second inference',
      () async {
        steady(0);
        expect(requests, hasLength(1));
        for (var ms = 1200; ms <= 3000; ms += 200) {
          frame(ms);
        }
        expect(requests, hasLength(1));
        requests.first.complete(parseDetections(responseText, 640, 480));
        await Future<void>.delayed(Duration.zero);
        expect(loop.snapshot!.detections, hasLength(2));
        expect(published.last, isNotNull);
        frame(3200);
        expect(requests, hasLength(1));
        frame(3600);
        expect(requests, hasLength(2));
      },
    );

    test(
      'Movement clears boxes and ignores old response even after restabilizing',
      () async {
        steady(0);
        steady(1200, 200);
        expect(loop.stability.stable, isTrue);
        expect(requests, hasLength(1));
        requests.first.complete(parseDetections(responseText, 640, 480));
        await Future<void>.delayed(Duration.zero);
        expect(loop.snapshot, isNull);
        expect(published.whereType<DetectionSnapshot>(), isEmpty);
        frame(2800, 200);
        expect(requests, hasLength(2));
        requests.last.complete(parseDetections(responseText, 640, 480));
        await Future<void>.delayed(Duration.zero);
        expect(loop.snapshot, isNotNull);
        frame(3000, 50);
        expect(loop.snapshot, isNull);
        expect(published.last, isNull);
      },
    );

    test('A stopped frame stream cannot accept a late result', () async {
      steady(0);
      now = const Duration(seconds: 4);
      requests.first.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(loop.snapshot, isNull);
      expect(loop.stability.stable, isFalse);
    });

    test('Lifecycle reset and disposal discard pending inference', () async {
      steady(0);
      loop.invalidate();
      requests.first.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(loop.snapshot, isNull);
      steady(2000);
      final count = published.length;
      loop.dispose();
      requests.last.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(published, hasLength(count));
      // tearDown should not dispose twice.
      loop = InspectionLoop(request: () async => [], publish: (_) {});
    });
  });

  testWidgets(
    'Objects page displays detections and clears them when invalidated',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ObjectsPage(
              inspection: DetectionSnapshot(
                parseDetections(responseText, 640, 480),
                DateTime(2026, 1, 1),
              ),
            ),
          ),
        ),
      );
      expect(find.text('pipe'), findsOneWidget);
      expect(find.text('rust'), findsOneWidget);
      expect(find.text('Уверенность: 43.23%'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ObjectsPage())),
      );
      expect(find.text('pipe'), findsNothing);
    },
  );
}
