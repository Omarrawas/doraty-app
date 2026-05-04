import 'math_normalizer.dart';

class MathParser {
  /// Main entry point to convert linear math to LaTeX
  static String convertToLatex(String input) {
    if (input.isEmpty) return "";
    
    // 1. Normalize Unicode and Greek letters
    String normalized = MathNormalizer.normalize(input);
    
    // 2. Recursively parse structures
    return _parse(normalized);
  }

  static String _parse(String input) {
    String text = input.trim();
    if (text.isEmpty) {
      return "";
    }

    // Process Fractions (/)
    int slashIndex = _findTopLevelOperator(text, '/');
    if (slashIndex != -1) {
      String left = text.substring(0, slashIndex);
      String right = text.substring(slashIndex + 1);

      String numerator = _extractLeftOperand(left);
      String denominator = _extractRightOperand(right);

      String remainingLeft = left.substring(0, left.length - numerator.length);
      String remainingRight = right.substring(denominator.length);

      // Remove surrounding parentheses if they were used for grouping the fraction
      String cleanNum = _stripOuterParentheses(numerator);
      String cleanDen = _stripOuterParentheses(denominator);

      return "${_parse(remainingLeft)}\\frac{${_parse(cleanNum)}}{${_parse(cleanDen)}}${_parse(remainingRight)}";
    }

    // Process Powers (^)
    int caretIndex = _findTopLevelOperator(text, '^');
    if (caretIndex != -1) {
      String left = text.substring(0, caretIndex);
      String right = text.substring(caretIndex + 1);

      String base = _extractLeftOperand(left);
      String exponent = _extractRightOperand(right);

      String remainingLeft = left.substring(0, left.length - base.length);
      String remainingRight = right.substring(exponent.length);

      String cleanExp = _stripOuterParentheses(exponent);

      return "${_parse(remainingLeft)}${_parse(base)}^{${_parse(cleanExp)}}${_parse(remainingRight)}";
    }

    // Process Subscripts (_)
    int subIndex = _findTopLevelOperator(text, '_');
    if (subIndex != -1) {
      String left = text.substring(0, subIndex);
      String right = text.substring(subIndex + 1);

      String base = _extractLeftOperand(left);
      String subscript = _extractRightOperand(right);

      String remainingLeft = left.substring(0, left.length - base.length);
      String remainingRight = right.substring(subscript.length);

      String cleanSub = _stripOuterParentheses(subscript);

      return "${_parse(remainingLeft)}${_parse(base)}_{${_parse(cleanSub)}}${_parse(remainingRight)}";
    }

    // Handle standard parentheses \left( \right)
    if (text.startsWith('(') && text.endsWith(')')) {
      // Check if it's a single balanced group
      if (_isBalanced(text.substring(1, text.length - 1))) {
        return "\\left( ${_parse(text.substring(1, text.length - 1))} \\right)";
      }
    }

    // If no operators, return as is (Greek letters already handled by normalizer)
    return _handleImplicitMultiplication(text);
  }

  static int _findTopLevelOperator(String text, String op) {
    int bracketLevel = 0;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '(') {
        bracketLevel++;
      } else if (text[i] == ')') {
        bracketLevel--;
      } else if (bracketLevel == 0 && text[i] == op) {
        return i;
      }
    }
    return -1;
  }

  static String _extractLeftOperand(String text) {
    if (text.isEmpty) {
      return "";
    }
    text = text.trim();
    if (text.endsWith(')')) {
      int level = 1;
      int i = text.length - 2;
      while (i >= 0 && level > 0) {
        if (text[i] == ')') {
          level++;
        } else if (text[i] == '(') {
          level--;
        }
        i--;
      }
      return text.substring(i + 1);
    } else {
      // Find the last "word" or number
      final regex = RegExp(r'([a-zA-Z\\]+|[0-9.]+)$');
      final match = regex.firstMatch(text);
      return match?.group(0) ?? text.substring(text.length - 1);
    }
  }

  static String _extractRightOperand(String text) {
    if (text.isEmpty) {
      return "";
    }
    text = text.trim();
    if (text.startsWith('(')) {
      int level = 1;
      int i = 1;
      while (i < text.length && level > 0) {
        if (text[i] == '(') {
          level++;
        } else if (text[i] == ')') {
          level--;
        }
        i++;
      }
      return text.substring(0, i);
    } else {
      // Find the first "word" or number
      final regex = RegExp(r'^([a-zA-Z\\]+|[0-9.]+)');
      final match = regex.firstMatch(text);
      return match?.group(0) ?? text.substring(0, 1);
    }
  }

  static String _stripOuterParentheses(String text) {
    text = text.trim();
    if (text.startsWith('(') && text.endsWith(')')) {
      String inner = text.substring(1, text.length - 1);
      if (_isBalanced(inner)) {
        return inner;
      }
    }
    return text;
  }

  static bool _isBalanced(String text) {
    int level = 0;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '(') {
        level++;
      } else if (text[i] == ')') {
        level--;
      }
      if (level < 0) {
        return false;
      }
    }
    return level == 0;
  }

  static String _handleImplicitMultiplication(String text) {
    // Basic logic: put spaces between numbers and LaTeX commands or variables
    // e.g. 2\pi r -> 2 \pi r
    String result = text.replaceAll(RegExp(r'(\d)([\\a-zA-Z])'), r'$1 $2');
    result = result.replaceAll(RegExp(r'([\\a-zA-Z])(\d)'), r'$1 $2');
    return result;
  }
}
