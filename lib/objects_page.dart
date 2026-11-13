import 'package:material_ui/material_ui.dart';

class ObjectsPage extends StatelessWidget {
  const ObjectsPage({super.key, this.qrValue});
  final String? qrValue;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.precision_manufacturing_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            qrValue == null ? 'Объекты пока не найдены' : 'Код готов к поиску',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            qrValue == null
                ? 'Считайте QR-код на вкладке «Сканер». Здесь появятся карточки оборудования и его компонентов.'
                : 'QR-код считан. Для поиска оборудования и загрузки характеристик необходимо подключить API сервера.',
          ),
          if (qrValue != null) ...[
            const SizedBox(height: 24),
            Text(
              'Последний QR-код',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(qrValue!),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Цифровая карточка',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Оборудование\nИнвентарный номер, тип, модель, производитель, серийный номер и место установки.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Компоненты и ресурс\nСостав узлов, наработка, срок службы и интервалы обслуживания.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Параметры и диагностика\nИзмерения, пороги, результаты ИИ и история обслуживания.',
                  ),
                  const SizedBox(height: 16),
                  const Text('Данные с сервера ещё не загружены.'),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
