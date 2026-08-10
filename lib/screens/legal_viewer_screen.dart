import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../legal_docs.dart';
import '../widgets/markdown_text.dart';

/// Просмотрщик юридических документов. Markdown рендерится по-настоящему:
/// заголовки, жирный шрифт, курсив и списки, а не сырые звёздочки и решётки.
/// Ссылки на него открываются с экрана входа.
class LegalViewerScreen extends StatelessWidget {
  final String title;
  final String assetPath;
  const LegalViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  // Тёмный фон и светлый текст — читаемо, как в большинстве приложений
  // с тёмной темой (документ на тёмной «бумаге»).
  static const Color _bg = Color(0xFF0F172A); // тёмно-синий фон
  static const Color _fg = Color(0xFFE5E7EB); // мягкий светло-серый текст
  // Акцент заголовков — фирменный голубой из градиента приложения.
  static const Color _accent = Color(0xFF38BDF8);

  // Сначала берём вшитый в код текст (работает везде), иначе — из ассетов.
  Future<String> _loadDoc() async {
    final embedded = kLegalDocs[assetPath];
    if (embedded != null) return embedded;
    return rootBundle.loadString(assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _bg,
        foregroundColor: _fg,
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: _loadDoc(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить документ.',
                  style: TextStyle(color: _fg),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: MarkdownText(
              data: snapshot.data ?? '',
              baseStyle: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: _fg,
              ),
              accentColor: _accent,
              dividerColor: const Color(0x33FFFFFF),
            ),
          );
        },
      ),
    );
  }
}
