import 'package:flutter/material.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

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
    // 1. اكتشاف نوع المحتوى
    // LaTeX markers check
    bool hasLatex = content.contains(r'$$') || 
                   content.contains(r'\\(') || 
                   content.contains(r'\\[') ||
                   (content.contains(r'\\') && (content.contains(r'frac') || content.contains(r'sqrt') || content.contains(r'alpha')));
    
    bool hasHtml = content.contains('<') && content.contains('>');

    // 2. اختيار الويدجت الأنسب
    
    // الحالة الأولى: نص عادي بدون أي أكواد
    if (!hasLatex && !hasHtml) {
      return Text(
        content,
        style: style,
        textAlign: isTitle ? TextAlign.center : TextAlign.start,
      );
    }

    // الحالة الثانية: يحتوي على HTML (مثل النصوص القادمة من Word) ولا يحتاج معادلات معقدة
    if (hasHtml && !hasLatex) {
      return HtmlWidget(
        content,
        textStyle: style?.copyWith(
          fontFamily: 'Cairo', // دعم العربية
          height: 1.5,
        ) ?? const TextStyle(color: Colors.white, fontSize: 16),
        renderMode: RenderMode.column,
      );
    }

    // الحالة الثالثة: معادلات رياضية (استخدام TeXView)
    String processedContent = content;
    bool alreadyDelimited = content.contains(r'$') || content.contains(r'\\(') || content.contains(r'\\[');
    if (!alreadyDelimited && (content.contains(r'\\') || content.contains(r'^') || content.contains(r'_'))) {
       processedContent = r'$$' + content + r'$$';
    }

    return TeXView(
      child: TeXViewDocument(
        processedContent,
        style: TeXViewStyle(
          contentColor: style?.color ?? Colors.white,
          fontStyle: TeXViewFontStyle(
            fontSize: (style?.fontSize ?? 16).toInt(),
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
      loadingWidgetBuilder: (context) => Text(content, style: style),
    );
  }
}
