import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class TexViewWidget extends StatelessWidget {
  final String content;
  final TextStyle? style;
  final bool isTitle;

  TexViewWidget(
    this.content, {
    super.key,
    this.style,
    this.isTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. اكتشاف نوع المحتوى بشكل أكثر دقة
    final String trimmedContent = content.trim();
    
    // LaTeX markers check - be stricter
    bool hasLatex = trimmedContent.contains(r'$$') || 
                   trimmedContent.contains(r'$') || 
                   trimmedContent.contains(r'\( ') || 
                   trimmedContent.contains(r'\[ ') ||
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
        textDirection: TextDirection.rtl, // دعم العربية الافتراضي
      );
    }

    // الحالة الثانية: يحتوي على HTML (مثل النصوص القادمة من Word) ولا يحتاج معادلات معقدة
    if (hasHtml && !hasLatex) {
      return HtmlWidget(
        content,
        textStyle: style?.copyWith(
          fontFamily: 'Cairo',
          height: 1.5,
          color: style?.color ?? Colors.white,
        ) ?? TextStyle(color: AppColors.getTextColor(context), fontSize: 16),
        renderMode: RenderMode.column,
      );
    }

    // الحالة الثالثة: معادلات رياضية (استخدام TeXView)
    String processedContent = content;
    
    // تأمين المحتوى ليتناسب مع TeXViewDocument
    // إذا لم يكن محاطاً بمحددات، نحيطه بـ $$ فقط إذا كان نصاً رياضياً صرفاً
    bool alreadyDelimited = trimmedContent.startsWith(r'$') || 
                          trimmedContent.startsWith(r'\( ') || 
                          trimmedContent.startsWith(r'\[ ');
                          
    if (!alreadyDelimited && hasLatex) {
        // إذا كان هناك علامات لاتيكس متفرقة، نتركها لـ TeXView ليتعامل معها
        // أو إذا كان المحتوى كله معادلة، نحيطه
        if (!trimmedContent.contains(' ')) { 
          processedContent = r'$$' + trimmedContent + r'$$';
        }
    }

    return TeXView(
      child: TeXViewDocument(
        processedContent,
        style: TeXViewStyle(
          contentColor: style?.color ?? Colors.white,
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
        backgroundColor: Colors.transparent,
      ),
      loadingWidgetBuilder: (context) => Padding(
        padding: EdgeInsets.all(10),
        child: Text(content, style: style),
      ),
    );
  }
}
