import 'package:ar_inspector/settings_page.dart';
import 'package:ar_inspector/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class MemorySettingsStore implements SettingsStore {
  InspectorSettings data = const InspectorSettings(
    fullName: 'Иван Петров',
    position: 'Инженер',
    login: 'petrov',
    password: 'secret',
    serverUrl: 'http://192.168.1.2:8000',
  );
  bool failSave = false;
  @override
  Future<InspectorSettings> load() async => data;
  @override
  Future<void> save(InspectorSettings settings) async {
    if (failSave) throw StateError('storage unavailable');
    data = settings;
  }
}

void main() {
  test('Server URL accepts LAN hosts and rejects malformed input', () {
    for (final url in [
      '',
      'http://192.168.1.10:8000',
      'https://server.local/api',
      'http://[::1]:8080',
    ]) {
      expect(validateServerUrl(url), isNull, reason: url);
    }
    for (final url in [
      '192.168.1.1',
      'postgres://localhost/db',
      'http://user:pass@localhost',
      'http://localhost:99999',
      'http://localhost:bad',
      'http://local host',
      'https://host/?token=abc',
    ]) {
      expect(validateServerUrl(url), isNotNull, reason: url);
    }
  });

  testWidgets('Settings load, mask password, save and restore changes', (
    tester,
  ) async {
    final store = MemorySettingsStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Иван Петров'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText).at(3)).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Показать пароль'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).at(3)).obscureText,
      isFalse,
    );
    await tester.enterText(find.byType(TextFormField).first, 'Анна Смирнова');
    await tester.scrollUntilVisible(
      find.text('Сохранить настройки'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить настройки'));
    await tester.pumpAndSettle();
    expect(store.data.fullName, 'Анна Смирнова');
    expect(store.data.password, 'secret');
    expect(find.text('Настройки сохранены на устройстве'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Анна Смирнова'), findsOneWidget);
  });

  testWidgets('Storage write failure does not report success', (tester) async {
    final store = MemorySettingsStore()..failSave = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Сохранить настройки'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить настройки'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось сохранить настройки. Повторите попытку.'),
      findsOneWidget,
    );
    expect(find.text('Настройки сохранены на устройстве'), findsNothing);
  });
}
