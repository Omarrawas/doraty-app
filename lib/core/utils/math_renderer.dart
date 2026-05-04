import 'math_parser.dart';

class MathRenderer {
  /// Transforms raw linear input into a LaTeX string suitable for Math.tex()
  static String renderToLatex(String input) {
    try {
      return MathParser.convertToLatex(input);
    } catch (e) {
      // If parsing fails, return the original input or a safe fallback
      return input;
    }
  }
}
