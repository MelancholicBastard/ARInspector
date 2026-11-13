import 'package:material_ui/material_ui.dart';

import 'settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.store = const SecureSettingsStore()});
  final SettingsStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _position = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _hidden = true;
  String? _loadError;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final settings = await widget.store.load();
      if (!mounted) return;
      _name.text = settings.fullName;
      _position.text = settings.position;
      _login.text = settings.login;
      _password.text = settings.password;
      _server.text = settings.serverUrl;
    } catch (_) {
      if (!mounted) return;
      _loadError = 'Не удалось прочитать настройки из хранилища.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await widget.store.save(
        InspectorSettings(
          fullName: _name.text.trim(),
          position: _position.text.trim(),
          login: _login.text.trim(),
          password: _password.text,
          serverUrl: _server.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _status = 'Настройки сохранены на устройстве');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _status = 'Не удалось сохранить настройки. Повторите попытку.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _position, _login, _password, _server]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _load,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Рабочее пространство',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Профиль автора отчётов и подключение к локальному серверу.',
              ),
              const SizedBox(height: 24),
              _section(context, 'Инженер', Icons.badge_outlined, [
                _field(
                  _name,
                  'ФИО',
                  enabled: !_saving,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: 16),
                _field(_position, 'Должность', enabled: !_saving),
                const SizedBox(height: 16),
                _field(
                  _login,
                  'Логин',
                  enabled: !_saving,
                  autofillHints: const [AutofillHints.username],
                  validator: (value) =>
                      _password.text.isNotEmpty && value!.trim().isEmpty
                      ? 'Укажите логин для этого пароля'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_saving,
                  obscureText: _hidden,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    border: const OutlineInputBorder(),
                    helperText: 'Хранится в защищённом хранилище устройства',
                    helperMaxLines: 3,
                    suffixIcon: IconButton(
                      tooltip: _hidden ? 'Показать пароль' : 'Скрыть пароль',
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      _login.text.trim().isNotEmpty && value!.isEmpty
                      ? 'Укажите пароль для этого логина'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Учётная запись не проверена. Вход и привязка автора отчёта будут доступны после подключения API.',
                ),
              ]),
              const SizedBox(height: 20),
              _section(context, 'Локальный сервер', Icons.dns_outlined, [
                _field(
                  _server,
                  'Адрес сервера',
                  enabled: !_saving,
                  hint: 'http://192.168.1.10:8000',
                  keyboard: TextInputType.url,
                  validator: validateServerUrl,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Укажите адрес HTTP API с БД и моделью распознавания. Телефон и сервер должны находиться в доступной друг другу сети.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'В режиме «Осмотр с моделью» кадры отправляются на этот сервер: POST /detect. На Android HTTP разрешён для localhost и 10.0.2.2, для других хостов используйте HTTPS.',
                ),
              ]),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Сохранение…' : 'Сохранить настройки'),
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(_status!)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    String? hint,
    TextInputType? keyboard,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    enabled: enabled,
    validator: validator,
    keyboardType: keyboard,
    autofillHints: autofillHints,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    ),
  );
}
