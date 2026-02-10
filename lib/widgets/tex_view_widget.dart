
import 'package:flutter/material.dart';
import 'package:flutter_tex/flutter_tex.dart';

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

  @override
  Widget build(BuildContext context) {
    // Check if content likely contains LaTeX or similar equation markers
    // Also check for HTML tags to ensure they are rendered correctly
    bool hasLatex = content.contains(r'$') ||
        content.contains(r'\(') ||
        content.contains(r'\[') ||
        content.contains(r'\') ||
        content.contains(r'^') ||
        content.contains(r'_') ||
        (content.contains(r'{') && content.contains(r'}'));
    
    bool hasHtml = content.contains('<') && content.contains('>');

    // If no latex markers and no HTML, just render text for performance
    if (!hasLatex && !hasHtml) {
      return Text(
        content,
        style: style,
        textAlign: isTitle ? TextAlign.center : TextAlign.start,
      );
    }

    // Force TeX mode for commands by wrapping in $$ if not already wrapped
    // This is a heuristic: if we have math markers but no obvious delimiters, wrap it.
    String processedContent = content;
    bool alreadyDelimited = content.contains(r'$') || content.contains(r'\(') || content.contains(r'\[');
    if (!alreadyDelimited && (content.contains(r'\') || content.contains(r'^') || content.contains(r'_'))) {
       processedContent = r'$$' + content + r'$$';
    }

    return TeXView(
      child: TeXViewDocument(
        processedContent,
        style: TeXViewStyle(
          contentColor: style?.color ?? Colors.black,
          fontStyle: TeXViewFontStyle(
            fontSize: style?.fontSize?.toInt() ?? 16,
            fontWeight: style?.fontWeight == FontWeight.bold
                ? TeXViewFontWeight.bold
                : TeXViewFontWeight.normal,
          ),
          textAlign: isTitle ? TeXViewTextAlign.center : TeXViewTextAlign.right,
          padding: const TeXViewPadding.all(10),
        ),
      ),
      style: const TeXViewStyle(
        backgroundColor: Colors.transparent,
      ),
      renderingEngine: const TeXViewRenderingEngine.katex(),
      loadingWidgetBuilder: (context) => Text(content, style: style),
    );
  }
}
