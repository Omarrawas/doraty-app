// No imports needed for regex and string utilities

class MathUtils {
  static final RegExp latexRegex = RegExp(
    r'(\$\$.*?\$\$|\$.*?\$|\\\(.*?\\\)|\\\[.*?\\\])',
    dotAll: true,
  );

  static final RegExp wordEquationHintRegex = RegExp(
    r'(〖|〗|【|】|(?<![\w\\])\d+\s*/\s*[^\s<]+)',
    dotAll: true,
  );

  static String normalizeMathContent(String raw) {
    if (raw.trim().isEmpty) return raw;

    // Decode and normalize colors first (8-digit hex to 6-digit)
    var processed = raw;
    processed = processed.replaceAllMapped(
      RegExp(r'#([0-9a-fA-F]{2})([0-9a-fA-F]{6})\b'),
      (match) {
        final alpha = match.group(1)!.toLowerCase();
        final rgb = match.group(2)!;
        // If it's a Flutter-style #AARRGGBB where AA is ff (opaque), convert to #RRGGBB
        if (alpha == 'ff') return '#$rgb';
        return match.group(0)!;
      }
    );

    final decodedRaw = decodeHtmlEntities(processed);
    // Split by HTML tags to avoid normalizing tag names or attributes
    final combinedRegex = RegExp(r'(<[^>]+>|[^<]+)');
    final matches = combinedRegex.allMatches(decodedRaw);

    final buffer = StringBuffer();
    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('<') && part.endsWith('>')) {
        buffer.write(part);
      } else {
        buffer.write(_normalizeTextSegment(part));
      }
    }

    return buffer.toString();
  }

  static String _normalizeTextSegment(String input) {
    var text = decodeHtmlEntities(input);

    // If it already has LaTeX or doesn't look like a Word equation, skip
    if (!wordEquationHintRegex.hasMatch(text) && !latexRegex.hasMatch(text)) {
      // Still apply basic function normalization for simple things like lambda
      return _normalizeFunctions(text);
    }

    // Convert Word-style braces
    text = text
        .replaceAll('〖', '{')
        .replaceAll('〗', '}')
        .replaceAll('【', '{')
        .replaceAll('】', '}');

    // Process line by line
    final lines = text.split('\n');
    final normalizedLines = lines.map((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || latexRegex.hasMatch(trimmed)) {
        return line;
      }

      final converted = _convertWordLinearEquation(trimmed);
      if (converted == trimmed) {
        return line;
      }
      // Wrap in display math for better rendering of converted formulas
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

    // Include trailing scripts if any
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
        .replaceAll('∞', r'\infty')
        .replaceAll('α', r'\alpha')
        .replaceAll('β', r'\beta')
        .replaceAll('γ', r'\gamma')
        .replaceAll('Δ', r'\Delta')
        .replaceAll('Ω', r'\Omega')
        .replaceAll('Σ', r'\Sigma')
        .replaceAll('Φ', r'\Phi');
  }

  static String decodeHtmlEntities(String input) {
    return input
        .replaceAll('&#47;', '/')
        .replaceAll('&#92;', r'\')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}

class _AtomMatch {
  final int start;
  final int end;
  final String value;

  const _AtomMatch(this.start, this.end, this.value);
}
