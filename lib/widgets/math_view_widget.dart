import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../core/utils/math_renderer.dart';

class MathView extends StatelessWidget {
  final String input;
  final TextStyle? textStyle;
  final MathStyle mathStyle;
  final TextAlign textAlign;

  const MathView(
    this.input, {
    super.key,
    this.textStyle,
    this.mathStyle = MathStyle.text,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    if (input.isEmpty) return const SizedBox.shrink();

    final latex = MathRenderer.renderToLatex(input);

    return SelectionArea(
      child: Math.tex(
        latex,
        mathStyle: mathStyle,
        textStyle: textStyle ?? TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
        onErrorFallback: (error) {
          // If rendering fails, show the original input as plain text
          return Text(
            input,
            style: textStyle,
            textAlign: textAlign,
          );
        },
      ),
    );
  }
}
