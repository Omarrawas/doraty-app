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
    
    // 1. استخدام RegExp دقيق لاكتشاف المعادلات الرياضية (نصيحة ذهبية)
    final latexRegex = RegExp(
      r'(\$\$.*?\$\$|\$.*?\$|\\\(.*?\\\)|\\\[.*?\\\])',
      dotAll: true,
    );
    bool hasLatex = latexRegex.hasMatch(trimmedContent);
    bool hasHtml = trimmedContent.contains('<') && trimmedContent.contains('>');

    // 2. اختيار الويدجت الأنسب - التحول إلى المعمارية الهجينة (Hybrid Architecture)
    
    // الحالة الأولى: نص عادي تماماً
    if (!hasLatex && !hasHtml) {
      return Text(
        content,
        style: style,
        textAlign: isTitle ? TextAlign.center : TextAlign.start,
        textDirection: TextDirection.rtl,
      );
    }

    // الحالة الثانية: خليط من HTML و LaTeX (المعمارية الاحترافية)
    // نستخدم HtmlWidget كمحرك أساسي وندمج TeXView بداخله فقط عند الحاجة
    return HtmlWidget(
      content,
      textStyle: style?.copyWith(
        fontFamily: 'Cairo',
        height: 1.5,
        color: style?.color ?? (isDark ? Colors.white : Colors.black87),
      ) ?? TextStyle(color: AppColors.getTextColor(context), fontSize: 16),
      renderMode: RenderMode.column,
      
      // هنا السحر: نقوم بتحويل أي جزء يحتوي على معادلة إلى TeXView بشكل مستقل
      customWidgetBuilder: (element) {
        // إذا وجدنا معادلة داخل النص، نستخدم TeXView لهذا العنصر فقط
        if (latexRegex.hasMatch(element.innerHtml)) {
          return TeXView(
            key: ValueKey('math_${element.innerHtml.hashCode}'),
            child: TeXViewDocument(
              element.outerHtml, // نمرر الـ HTML الخاص بهذا العنصر فقط لضمان التنسيق
              style: TeXViewStyle(
                contentColor: style?.color ?? (isDark ? Colors.white : Colors.black87),
                backgroundColor: Colors.transparent,
                fontStyle: TeXViewFontStyle(
                  fontSize: (style?.fontSize ?? 16).toInt(),
                ),
                textAlign: isTitle ? TeXViewTextAlign.center : TeXViewTextAlign.right,
              ),
            ),
            style: TeXViewStyle(
              backgroundColor: isDark ? Colors.black.withValues(alpha: 0.01) : Colors.transparent,
            ),
          );
        }
        return null; // نترك الباقي لـ HtmlWidget ليعرضه بشكل Native
      },
    );
  }
}
