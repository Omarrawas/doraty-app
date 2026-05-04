import 'package:flutter/material.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../core/theme/app_colors.dart';

class TexViewWidget extends StatelessWidget {
  final String content;
  final TextStyle? style;
  final bool isTitle;

  const TexViewWidget(
    this.content, {
    super.key,
    this.style,
    this.isTitle = false,
  });

  static final RegExp _latexRegex = RegExp(
    r'(\$\$.*?\$\$|\$.*?\$|\\\(.*?\\\)|\\\[.*?\\\])',
    dotAll: true,
  );

  static final RegExp _wordEquationHintRegex = RegExp(
    r'(〖|〗|(?<![\w\\])\d+\s*/\s*[^\s<]+)',
    dotAll: true,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = style?.copyWith(
          fontFamily: 'Cairo',
          height: 1.5,
          color: style?.color ?? (isDark ? Colors.white : Colors.black87),
        ) ??
        TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          height: 1.5,
          color: AppColors.getTextColor(context),
        );

    final normalizedContent = _normalizeMathContent(content);
    final hasLatex = _latexRegex.hasMatch(normalizedContent);
    final hasHtml =
        normalizedContent.contains('<') && normalizedContent.contains('>');

    if (!hasHtml) {
      if (!hasLatex) {
        return Text(
          normalizedContent,
          style: defaultStyle,
          textAlign: isTitle ? TextAlign.center : TextAlign.start,
          textDirection: TextDirection.rtl,
        );
      }
      return _buildMathText(context, normalizedContent, defaultStyle);
    }

    return HtmlWidget(
      normalizedContent,
      textStyle: defaultStyle,
      renderMode: RenderMode.column,
      customWidgetBuilder: (element) {
        if (element.children.isNotEmpty) {
          return null;
        }

        final text = _normalizeMathContent(element.text.trim());
        if (text.isEmpty || !_latexRegex.hasMatch(text)) {
          return null;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildMathText(context, text, defaultStyle),
        );
      },
    );
  }

  Widget _buildMathText(
    BuildContext context,
    String mathAwareText,
    TextStyle baseStyle,
  ) {
    final fontSize = baseStyle.fontSize ?? 16;
    final textColor = baseStyle.color ?? AppColors.getTextColor(context);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: TeXWidget(
        key: ValueKey('tex_${mathAwareText.hashCode}'),
        content: mathAwareText,
        textWidgetBuilder: (context, text) => TextSpan(
          text: text,
          style: baseStyle,
        ),
        inlineFormulaWidgetBuilder: (context, inlineFormula) => Math2SVG(
          key: ValueKey('inline_${inlineFormula.hashCode}'),
          math: inlineFormula,
          formulaWidgetBuilder: (context, svg) => SvgPicture.string(
            svg,
            height: fontSize * 1.2,
            fit: BoxFit.contain,
          ),
        ),
        displayFormulaWidgetBuilder: (context, displayFormula) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: isTitle ? Alignment.center : Alignment.centerRight,
            child: Math2SVG(
              key: ValueKey('display_${displayFormula.hashCode}'),
              math: displayFormula,
              formulaWidgetBuilder: (context, svg) => SvgPicture.string(
                svg,
                width: MediaQuery.of(context).size.width * 0.9,
                colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _normalizeMathContent(String raw) {
    if (raw.trim().isEmpty) return raw;

    final parts = raw.split(RegExp(r'(<[^>]+>)'));
    final buffer = StringBuffer();

    for (final part in parts) {
      if (part.isEmpty) continue;
      if (part.startsWith('<') && part.endsWith('>')) {
        buffer.write(part);
      } else {
        buffer.write(_normalizeTextSegment(part));
      }
    }

    return buffer.toString();
  }

  static String _normalizeTextSegment(String input) {
    var text = input;

    if (!_wordEquationHintRegex.hasMatch(text) && !_latexRegex.hasMatch(text)) {
      return text;
    }

    text = text.replaceAll('〖', '{').replaceAll('〗', '}');

    final lines = text.split('\n');
    final normalizedLines = lines.map((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || _latexRegex.hasMatch(trimmed)) {
        return line;
      }

      final converted = _convertWordLinearEquation(trimmed);
      if (converted == trimmed) {
        return line;
      }
      return line.replaceFirst(trimmed, '\\[$converted\\]');
    }).toList();

    return normalizedLines.join('\n');
  }

  static String _convertWordLinearEquation(String input) {
    var text = input;
    text = _normalizeScripts(text);
    text = _convertFractions(text);
    text = _normalizeFunctions(text);
    return text;
  }

  static String _normalizeScripts(String input) {
    final tokenRegex = RegExp(
      r'([A-Za-z\u0370-\u03FF]+|\{[^{}]+\})([_^])([A-Za-z0-9\u0370-\u03FF]+)',
    );

    var current = input;
    while (true) {
      final updated = current.replaceAllMapped(tokenRegex, (match) {
        final base = match.group(1)!;
        final operator = match.group(2)!;
        final value = match.group(3)!;
        return '$base$operator{$value}';
      });
      if (updated == current) break;
      current = updated;
    }
    return current;
  }

  static String _convertFractions(String input) {
    var text = input;
    int index = 0;

    while (index < text.length) {
      if (text[index] != '/') {
        index++;
        continue;
      }

      final left = _readLeftAtom(text, index - 1);
      final right = _readRightAtom(text, index + 1);

      if (left == null || right == null) {
        index++;
        continue;
      }

      final replacement = r'\frac{' '${left.value}' '}{' '${right.value}' '}';
      text = text.replaceRange(left.start, right.end, replacement);
      index = left.start + replacement.length;
    }

    return text;
  }

  static _AtomMatch? _readLeftAtom(String text, int index) {
    while (index >= 0 && text[index].trim().isEmpty) {
      index--;
    }
    if (index < 0) return null;

    final end = index + 1;
    final start = _scanAtomStart(text, index);
    if (start == null) return null;
    return _AtomMatch(start, end, text.substring(start, end));
  }

  static _AtomMatch? _readRightAtom(String text, int index) {
    while (index < text.length && text[index].trim().isEmpty) {
      index++;
    }
    if (index >= text.length) return null;

    final end = _scanAtomEnd(text, index);
    if (end == null || end <= index) return null;
    return _AtomMatch(index, end, text.substring(index, end));
  }

  static int? _scanAtomStart(String text, int index) {
    if (index < 0) return null;

    if (text[index] == '}') {
      final braceStart = _findMatchingOpen(text, index, '{', '}');
      if (braceStart == null) return null;
      return _includeBaseBeforeGroup(text, braceStart);
    }

    if (text[index] == ')') {
      return _findMatchingOpen(text, index, '(', ')');
    }

    var start = index;
    while (start >= 0 && _isMathTokenChar(text[start])) {
      start--;
    }
    return start + 1;
  }

  static int _includeBaseBeforeGroup(String text, int braceStart) {
    var start = braceStart;
    var cursor = braceStart - 1;
    while (cursor >= 0 && _isMathTokenChar(text[cursor])) {
      start = cursor;
      cursor--;
    }
    return start;
  }

  static int? _scanAtomEnd(String text, int index) {
    if (index >= text.length) return null;

    int cursor;
    if (text[index] == '{') {
      final close = _findMatchingClose(text, index, '{', '}');
      if (close == null) return null;
      cursor = close + 1;
    } else if (text[index] == '(') {
      final close = _findMatchingClose(text, index, '(', ')');
      if (close == null) return null;
      cursor = close + 1;
    } else {
      cursor = index;
      while (cursor < text.length && _isMathTokenChar(text[cursor])) {
        cursor++;
      }
    }

    while (cursor < text.length) {
      final marker = text[cursor];
      if (marker != '^' && marker != '_') break;

      if (cursor + 1 >= text.length) break;
      final next = text[cursor + 1];
      if (next == '{') {
        final close = _findMatchingClose(text, cursor + 1, '{', '}');
        if (close == null) break;
        cursor = close + 1;
      } else {
        cursor += 2;
        while (cursor < text.length && _isMathTokenChar(text[cursor])) {
          cursor++;
        }
      }
    }

    return cursor;
  }

  static int? _findMatchingOpen(
    String text,
    int closeIndex,
    String openChar,
    String closeChar,
  ) {
    var depth = 0;
    for (var i = closeIndex; i >= 0; i--) {
      if (text[i] == closeChar) depth++;
      if (text[i] == openChar) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  static int? _findMatchingClose(
    String text,
    int openIndex,
    String openChar,
    String closeChar,
  ) {
    var depth = 0;
    for (var i = openIndex; i < text.length; i++) {
      if (text[i] == openChar) depth++;
      if (text[i] == closeChar) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  static bool _isMathTokenChar(String char) {
    return RegExp(r'[A-Za-z0-9\u0370-\u03FF\\.]').hasMatch(char);
  }

  static String _normalizeFunctions(String input) {
    return input
        .replaceAll('λ', r'\lambda')
        .replaceAll('Λ', r'\Lambda')
        .replaceAll('∞', r'\infty');
  }
}

class _AtomMatch {
  final int start;
  final int end;
  final String value;

  const _AtomMatch(this.start, this.end, this.value);
}
