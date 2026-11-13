import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InspectorSettings {
  const InspectorSettings({
    this.fullName = '',
    this.position = '',
    this.login = '',
    this.password = '',
    this.serverUrl = '',
  });
  final String fullName;
  final String position;
  final String login;
  final String password;
  final String serverUrl;

  Map<String, String> toJson() => {
    'fullName': fullName,
    'position': position,
    'login': login,
    'password': password,
    'serverUrl': serverUrl,
  };

  factory InspectorSettings.fromJson(Map<String, dynamic> json) =>
      InspectorSettings(
        fullName: json['fullName'] as String? ?? '',
        position: json['position'] as String? ?? '',
        login: json['login'] as String? ?? '',
        password: json['password'] as String? ?? '',
        serverUrl: json['serverUrl'] as String? ?? '',
      );
}

abstract interface class SettingsStore {
  Future<InspectorSettings> load();
  Future<void> save(InspectorSettings settings);
}

class SecureSettingsStore implements SettingsStore {
  const SecureSettingsStore();
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _key = 'inspector.settings.v1';

  @override
  Future<InspectorSettings> load() async {
    final value = await _storage.read(key: _key);
    return value == null
        ? const InspectorSettings()
        : InspectorSettings.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> save(InspectorSettings settings) =>
      _storage.write(key: _key, value: jsonEncode(settings.toJson()));
}

/// The address is a base HTTP API URL, never a database connection string.
String? validateServerUrl(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      RegExp(r'\s').hasMatch(text)) {
    return 'Укажите http:// или https://, адрес и при необходимости порт';
  }
  try {
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return 'Порт должен быть от 1 до 65535';
    }
  } on FormatException {
    return 'Некорректный порт сервера';
  }
  return null;
}
