import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/cities.dart';

/// Поле выбора города: выглядит как обычный TextField из темы приложения,
/// но по тапу открывает шторку с поиском и живыми совпадениями.
class CityField extends StatelessWidget {
  final String value;
  final ValueChanged<RuCity> onSelected;
  final bool enabled;
  final String label;
  final String? errorText;

  const CityField({
    super.key,
    required this.value,
    required this.onSelected,
    this.enabled = true,
    this.label = 'Город',
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    final city = RuCities.byName(value);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: !enabled
          ? null
          : () async {
              final picked = await showCityPicker(context, initialQuery: value);
              if (picked != null) onSelected(picked);
            },
      child: InputDecorator(
        isEmpty: empty,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          enabled: enabled,
          prefixIcon: const Icon(Icons.location_city_outlined),
          suffixIcon: Icon(
            enabled ? Icons.expand_more_rounded : Icons.lock_outline,
            color: Colors.black38,
          ),
        ),
        child: empty
            ? null
            : Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (city != null && city.region != city.name) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        city.region,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.black45),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Открывает шторку выбора города. Возвращает null, если ничего не выбрали.
Future<RuCity?> showCityPicker(BuildContext context,
    {String initialQuery = ''}) {
  return showModalBottomSheet<RuCity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CityPickerSheet(initialQuery: initialQuery),
  );
}

class _CityPickerSheet extends StatefulWidget {
  final String initialQuery;
  const _CityPickerSheet({required this.initialQuery});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  late final TextEditingController _controller;
  late List<RuCity> _results;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    // Показываем сразу крупнейшие города — можно просто пролистать список.
    _results = RuCities.search('', limit: 60);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _results = RuCities.search(v, limit: 60));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Выберите город',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Начните вводить название',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
            ),
            Flexible(
              child: _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
                      child: Text(
                        'Город не найден. Проверьте написание или выберите ближайший крупный город.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(
                          height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                      itemBuilder: (_, i) {
                        final c = _results[i];
                        return ListTile(
                          leading: const Icon(Icons.location_city_outlined,
                              color: AppTheme.primaryColor),
                          title: _HighlightedText(
                            text: c.name,
                            query: _controller.text,
                          ),
                          subtitle: c.region == c.name
                              ? null
                              : Text(c.region,
                                  style: const TextStyle(fontSize: 12.5)),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Подсвечивает совпавшую часть названия, как в поисковых подсказках.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600);
    final q = query.trim().toLowerCase().replaceAll('ё', 'е');
    if (q.isEmpty) return Text(text, style: base);
    final haystack = text.toLowerCase().replaceAll('ё', 'е');
    final start = haystack.indexOf(q);
    if (start < 0) return Text(text, style: base);
    final end = start + q.length;
    return RichText(
      text: TextSpan(
        style: base.copyWith(color: const Color(0xFF0F172A)),
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(
                color: AppTheme.primaryColor, fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
