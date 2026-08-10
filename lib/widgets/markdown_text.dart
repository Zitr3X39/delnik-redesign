import 'package:flutter/material.dart';

/// Лёгкий рендер Markdown без внешних пакетов.
///
/// Нужен для юридических документов: раньше они показывались сырым
/// текстом с решётками и звёздочками.
///
/// Поддерживается: заголовки #..######, списки, цитаты, разделители,
/// блоки кода и инлайн-разметка: **жирный**, *курсив*, _курсив_,
/// ~~зачёркнутый~~, `код` и ссылки [текст](url).
class MarkdownText extends StatelessWidget {
  final String data;
  final TextStyle baseStyle;
  final Color accentColor;
  final Color dividerColor;
  final bool selectable;

  const MarkdownText({
    super.key,
    required this.data,
    required this.baseStyle,
    required this.accentColor,
    required this.dividerColor,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    final lines = data.replaceAll('\r\n', '\n').split('\n');

    var inCode = false;
    final codeBuffer = <String>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final text = paragraph.join(' ').trim();
      paragraph.clear();
      if (text.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _richText(text, baseStyle),
      ));
    }

    void flushCode() {
      if (codeBuffer.isEmpty) return;
      final text = codeBuffer.join('\n');
      codeBuffer.clear();
      blocks.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: dividerColor),
        ),
        child: Text(
          text,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: (baseStyle.fontSize ?? 15) - 1,
          ),
        ),
      ));
    }

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();

      if (trimmed.startsWith('```')) {
        if (inCode) {
          flushCode();
          inCode = false;
        } else {
          flushParagraph();
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        codeBuffer.add(rawLine);
        continue;
      }

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        flushParagraph();
        blocks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: dividerColor, height: 1),
        ));
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        final level = heading.group(1)!.length;
        final text = heading.group(2)!.trim();
        final base = baseStyle.fontSize ?? 15;
        final sizes = <double>[
          base + 8,
          base + 5,
          base + 3,
          base + 1.5,
          base + 0.5,
          base,
        ];
        blocks.add(Padding(
          padding: EdgeInsets.only(top: level <= 2 ? 18 : 12, bottom: 8),
          child: _richText(
            text,
            baseStyle.copyWith(
              fontSize: sizes[level - 1],
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: level <= 2 ? accentColor : baseStyle.color,
            ),
          ),
        ));
        continue;
      }

      if (trimmed.startsWith('> ')) {
        flushParagraph();
        blocks.add(Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 3)),
          ),
          child: _richText(
            trimmed.substring(2).trim(),
            baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        ));
        continue;
      }

      final bullet = RegExp(r'^[-*\u2022]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        blocks.add(_listItem('\u2022', bullet.group(1)!.trim()));
        continue;
      }

      final numbered = RegExp(r'^(\d+[.)])\s+(.*)$').firstMatch(trimmed);
      if (numbered != null) {
        flushParagraph();
        blocks.add(_listItem(numbered.group(1)!, numbered.group(2)!.trim()));
        continue;
      }

      paragraph.add(trimmed);
    }

    flushCode();
    flushParagraph();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  Widget _listItem(String marker, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: marker == '\u2022' ? 18 : 26,
            child: Text(
              marker,
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          Expanded(child: _richText(text, baseStyle)),
        ],
      ),
    );
  }

  Widget _richText(String source, TextStyle style) {
    final span = TextSpan(style: style, children: _inlineSpans(source, style));
    if (selectable) return SelectableText.rich(span);
    return RichText(text: span);
  }

  List<TextSpan> _inlineSpans(String source, TextStyle style) {
    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: style));
      buffer.clear();
    }

    var i = 0;
    while (i < source.length) {
      final rest = source.substring(i);

      final link = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)').firstMatch(rest);
      if (link != null) {
        flush();
        spans.add(TextSpan(
          text: link.group(1),
          style: style.copyWith(
            color: accentColor,
            decoration: TextDecoration.underline,
            decorationColor: accentColor,
          ),
        ));
        i += link.group(0)!.length;
        continue;
      }

      final marker = _matchMarker(rest);
      if (marker != null) {
        flush();
        final innerStyle = marker.apply(style, accentColor);
        spans.addAll(_inlineSpans(marker.content, innerStyle));
        i += marker.length;
        continue;
      }

      buffer.write(source[i]);
      i++;
    }

    flush();
    return spans;
  }

  /// Ищет парный маркер в начале строки.
  _InlineMarker? _matchMarker(String rest) {
    const markers = <String, _MarkerKind>{
      '**': _MarkerKind.bold,
      '__': _MarkerKind.bold,
      '~~': _MarkerKind.strike,
      '*': _MarkerKind.italic,
      '_': _MarkerKind.italic,
      '`': _MarkerKind.code,
    };

    for (final entry in markers.entries) {
      final token = entry.key;
      if (!rest.startsWith(token)) continue;
      final closeAt = rest.indexOf(token, token.length);
      if (closeAt <= token.length) continue;
      return _InlineMarker(
        kind: entry.value,
        content: rest.substring(token.length, closeAt),
        length: closeAt + token.length,
      );
    }
    return null;
  }
}

enum _MarkerKind { bold, italic, strike, code }

class _InlineMarker {
  final _MarkerKind kind;
  final String content;
  final int length;

  const _InlineMarker({
    required this.kind,
    required this.content,
    required this.length,
  });

  TextStyle apply(TextStyle style, Color accent) {
    switch (kind) {
      case _MarkerKind.bold:
        return style.copyWith(fontWeight: FontWeight.w800);
      case _MarkerKind.italic:
        return style.copyWith(fontStyle: FontStyle.italic);
      case _MarkerKind.strike:
        return style.copyWith(decoration: TextDecoration.lineThrough);
      case _MarkerKind.code:
        return style.copyWith(fontFamily: 'monospace', color: accent);
    }
  }
}
