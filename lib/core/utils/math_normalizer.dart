class MathNormalizer {
  static const Map<String, String> unicodeMap = {
    '⁄': '/',
    '×': r'\times',
    '−': '-',
    'π': r'\pi',
    'λ': r'\lambda',
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'θ': r'\theta',
    'δ': r'\delta',
    'σ': r'\sigma',
    'ω': r'\omega',
    'Δ': r'\Delta',
    'Ω': r'\Omega',
    'Φ': r'\Phi',
    '〖': '(',
    '〗': ')',
    '±': r'\pm',
    '÷': r'\div',
    '≤': r'\le',
    '≥': r'\ge',
    '≠': r'\ne',
    '≈': r'\approx',
    '∞': r'\infty',
  };

  static String normalize(String input) {
    if (input.isEmpty) return input;

    String result = input;

    // 1. Replace Unicode characters from map
    unicodeMap.forEach((unicode, replacement) {
      result = result.replaceAll(unicode, replacement);
    });

    // 2. Remove Word specific artifacts
    result = result.replaceAll('〖', '(').replaceAll('〗', ')');

    // 3. Normalize spaces but keep necessary ones
    result = result.trim();
    
    // 4. Handle scientific notation variants (e.g., 10^-3)
    // We'll let the parser handle the caret, but normalize the symbol if needed
    
    return result;
  }
}
