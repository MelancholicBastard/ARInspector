import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'detection.dart';
import 'settings_store.dart';

class DetectionApi {
  DetectionApi(String baseUrl, {http.Client Function()? clientFactory})
    : endpoint = endpointFor(baseUrl),
      _clientFactory = clientFactory ?? http.Client.new;
  final Uri endpoint;
  final http.Client Function() _clientFactory;
  http.Client? _active;

  static Uri endpointFor(String baseUrl) {
    if (baseUrl.trim().isEmpty || validateServerUrl(baseUrl) != null) {
      throw const FormatException('Укажите адрес сервера в настройках');
    }
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/detect');
  }

  Future<List<Detection>> detect(Uint8List jpeg, int width, int height) async {
    final client = _clientFactory();
    _active = client;
    try {
      return await (() async {
        final request = http.MultipartRequest('POST', endpoint)
          ..headers['Accept'] = 'text/plain'
          ..fields['width'] = '$width'
          ..fields['height'] = '$height'
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              jpeg,
              filename: 'frame.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        final response = await client.send(request);
        if (response.statusCode != 200) {
          throw StateError('Сервер вернул HTTP ${response.statusCode}');
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          if (bytes.length > 1024 * 1024) {
            throw const FormatException('Слишком большой ответ');
          }
        }
        return parseDetections(utf8.decode(bytes), width, height);
      })().timeout(const Duration(seconds: 10));
    } finally {
      client.close(); // Also terminates the transport after a timeout.
      if (identical(_active, client)) _active = null;
    }
  }

  void close() => _active?.close();
}
