import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'qr_scanner_page.dart';
import 'settings_page.dart';
import 'objects_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AR Инспектор',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: const InspectorShell(),
  );
}

class InspectorShell extends StatefulWidget {
  const InspectorShell({super.key});

  @override
  State<InspectorShell> createState() => _InspectorShellState();
}

class _InspectorShellState extends State<InspectorShell> {
  int _tab = 0;
  bool _settingsVisited = false;
  String? _qrValue;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _tab == 0
        ? null
        : AppBar(title: Text(_tab == 1 ? 'Объекты' : 'Настройки')),
    body: SafeArea(
      top: _tab != 0,
      bottom: false,
      child: IndexedStack(
        index: _tab,
        children: [
          InspectorHome(
            onDetected: (value) => setState(() => _qrValue = value),
          ),
          ObjectsPage(qrValue: _qrValue),
          if (_settingsVisited)
            const SettingsPage()
          else
            const SizedBox.shrink(),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() {
        _tab = index;
        if (index == 2) _settingsVisited = true;
      }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Сканер',
        ),
        NavigationDestination(
          icon: Icon(Icons.precision_manufacturing_outlined),
          label: 'Объекты',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Настройки',
        ),
      ],
    ),
  );
}

class InspectorHome extends StatefulWidget {
  const InspectorHome({super.key, this.onDetected});
  final ValueChanged<String>? onDetected;

  @override
  State<InspectorHome> createState() => _InspectorHomeState();
}

class _InspectorHomeState extends State<InspectorHome> {
  String? _result;
  bool _openingScanner = false;

  bool get _supported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _scan() async {
    if (_openingScanner) return;
    setState(() => _openingScanner = true);
    final value = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (!mounted) return;
    setState(() {
      _openingScanner = false;
      if (value != null) _result = value;
    });
    if (value != null) widget.onDetected?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.view_in_ar_rounded),
            SizedBox(width: 10),
            Expanded(
              child: Text('AR Инспектор', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                Text(
                  'ОСМОТР ОБОРУДОВАНИЯ',
                  style: text.labelMedium?.copyWith(
                    color: colors.primary,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Каждый осмотр\nначинается с QR',
                  style: text.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Считайте код на оборудовании, чтобы получить его идентификатор.',
                  style: text.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          size: 96,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Наведите. Считайте. Готово.',
                        textAlign: TextAlign.center,
                        style: text.titleLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Разместите QR-код перед камерой.\nРаспознавание произойдёт автоматически.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _supported && !_openingScanner ? _scan : null,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(
                    _result == null ? 'Сканировать QR-код' : 'Сканировать ещё',
                  ),
                ),
                if (!_supported) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Сканирование доступно на Android, iOS, macOS и в веб-браузере.',
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  QrResultCard(value: _result!),
                ],
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Первый этап — идентификация. Цифровые карточки оборудования и AR-анализ появятся на следующих этапах.',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QrResultCard extends StatelessWidget {
  const QrResultCard({super.key, required this.value});
  final String value;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Содержимое QR-кода скопировано')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'QR-код считан',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Содержимое кода',
            style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: SelectableText(value, style: text.bodyLarge),
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Копировать'),
          ),
        ],
      ),
    );
  }
}
