// ignore_for_file: avoid_print

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
    '〖': '{', // Changed to { for LaTeX grouping
    '〗': '}',
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
    unicodeMap.forEach((unicode, replacement) {
      result = result.replaceAll(unicode, replacement);
    });
    return result.trim();
  }
}

class MathParser {
  static String convertToLatex(String input) {
    if (input.isEmpty) return "";
    String normalized = MathNormalizer.normalize(input);
    return _parse(normalized);
  }

  static String _parse(String input) {
    String text = input.trim();
    if (text.isEmpty) return "";

    // Find the first operator ANYWHERE, but prioritize top-level
    // Actually, to handle 1/λ = R(1/n^2), we need to be careful.
    
    // Let's try a different approach: find the "outermost" or "first" fraction/power
    // that isn't hidden inside a higher-priority structure.
    
    int slashIndex = _findFirstSlash(text);
    if (slashIndex != -1) {
       // ... fraction logic
    }
    
    return text;
  }
  
  static int _findFirstSlash(String text) {
    // For Word linear math, we can just find the first slash that is not inside {}
    int level = 0;
    for(int i=0; i<text.length; i++) {
      if (text[i] == '{') {
        level++;
      } else if (text[i] == '}') {
        level--;
      } else if (level == 0 && text[i] == '/') {
        return i;
      }
    }
    return -1;
  }
}

void main() {
  String input = "1/λ = R(1/ 〖n_1〗^2 - 1/ 〖n_2〗^2 )";
  print("Input: $input");
  String normalized = MathNormalizer.normalize(input);
  print("Normalized: $normalized");
}
