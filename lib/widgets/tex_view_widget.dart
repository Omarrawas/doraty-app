import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
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
    // 1. اكتشاف نوع المحتوى بشكل أكثر دقة
    final String trimmedContent = content.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // LaTeX markers check - include the tags used by our editor
    bool hasLatex = trimmedContent.contains(r'$$') || 
                   trimmedContent.contains(r'$') || 
                   trimmedContent.contains(r'\(') || 
                   trimmedContent.contains(r'\[') ||
                   (trimmedContent.contains(r'\\') && (
                     trimmedContent.contains(r'frac') || 
                     trimmedContent.contains(r'sqrt') || 
                     trimmedContent.contains(r'alpha') || 
                     trimmedContent.contains(r'begin') ||
                     trimmedContent.contains(r'matrix') ||
                     trimmedContent.contains(r'vector') ||
                     trimmedContent.contains(r'sum') ||
                     trimmedContent.contains(r'int')
                   ));
    
    bool hasHtml = trimmedContent.contains('<') && trimmedContent.contains('>');

    // 2. اختيار الويدجت الأنسب
    
    // الحالة الأولى: نص عادي بدون أي أكواد
    if (!hasLatex && !hasHtml) {
      return Text(
        content,
        style: style,
        textAlign: isTitle ? TextAlign.center : TextAlign.start,
        textDirection: TextDirection.rtl,
      );
    }

    // الحالة الثانية: يحتوي على HTML ولا يحتاج معادلات معقدة
    if (hasHtml && !hasLatex) {
      return HtmlWidget(
        content,
        textStyle: style?.copyWith(
          fontFamily: 'Cairo',
          height: 1.5,
          color: style?.color ?? (isDark ? Colors.white : Colors.black87),
        ) ?? TextStyle(color: AppColors.getTextColor(context), fontSize: 16),
        renderMode: RenderMode.column,
      );
    }

    // الحالة الثالثة: معادلات رياضية (LaTeX) باستخدام TeXView
    return TeXView(
      key: ValueKey('display_${content.hashCode}'),
      child: TeXViewDocument(
        content,
        style: TeXViewStyle(
          contentColor: style?.color ?? (isDark ? Colors.white : Colors.black87),
          backgroundColor: Colors.transparent,
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
      style: TeXViewStyle(
        // Use a slight background in dark mode to prevent black-box glitches on some platforms
        backgroundColor: isDark ? Colors.black.withValues(alpha: 0.01) : Colors.transparent,
      ),
      loadingWidgetBuilder: (context) => Padding(
        padding: const EdgeInsets.all(10),
        child: Text(content, style: style),
      ),
    );
  }
}
