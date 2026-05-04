import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/math_utils.dart';

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

  static final RegExp _latexRegex = MathUtils.latexRegex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = style?.copyWith(
          fontFamily: 'Cairo',
          height: 1.5,
          color: style?.color ?? (isDark ? Colors.white : Colors.black87),
        ) ??
        TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          height: 1.5,
          color: AppColors.getTextColor(context),
        );

    final normalizedContent = MathUtils.normalizeMathContent(content);
    final hasLatex = _latexRegex.hasMatch(normalizedContent);
    final hasHtml =
        normalizedContent.contains('<') && normalizedContent.contains('>');

    if (!hasHtml) {
      if (!hasLatex) {
        return Text(
          normalizedContent,
          style: defaultStyle,
          textAlign: isTitle ? TextAlign.center : TextAlign.start,
          textDirection: TextDirection.rtl,
        );
      }
      return _buildMathText(context, normalizedContent, defaultStyle);
    }

    // ── HTML path ──────────────────────────────────────────────────────────
    // IMPORTANT: Do NOT pass `color` in textStyle to HtmlWidget.
    // When a color is set in textStyle, flutter_widget_from_html uses it as the
    // "resolved" color and ignores inline CSS `color:` / `background-color:` on
    // child elements. Stripping it here lets inline HTML colors take effect.
    // We inject the default color via customStylesBuilder instead, only on
    // elements that have no explicit inline color.
    final htmlBaseStyle = defaultStyle.copyWith(color: null);
    final defaultCssColor = _colorToCss(defaultStyle.color ?? AppColors.getTextColor(context));

    return Directionality(
      // Wrap in RTL so that `text-align:center` on <p> tags renders correctly
      // for Arabic content. Without this wrapper, alignment is resolved against
      // the ambient LTR direction and center/right may appear wrong.
      textDirection: TextDirection.rtl,
      child: HtmlWidget(
        normalizedContent,
        textStyle: htmlBaseStyle,
        renderMode: RenderMode.column,
        customStylesBuilder: (element) {
          final inlineStyle = element.attributes['style'] ?? '';
          // Only inject default text color when the element has no explicit
          // color rule. This preserves inline color / background-color values
          // that were set in the Quill editor.
          if (!inlineStyle.contains('color')) {
            return {'color': defaultCssColor};
          }
          return null;
        },
        customWidgetBuilder: (element) {
          if (element.children.isNotEmpty) {
            return null;
          }

          final text = MathUtils.normalizeMathContent(element.text.trim());
          if (text.isEmpty || !_latexRegex.hasMatch(text)) {
            return null;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildMathText(context, text, defaultStyle),
          );
        },
      ),
    );
  }

  /// Converts a Flutter [Color] to a CSS hex string understood by
  /// flutter_widget_from_html (e.g. `#ffffff`).
  static String _colorToCss(Color color) {
    final rgb = color.value & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  Widget _buildMathText(
    BuildContext context,
    String mathAwareText,
    TextStyle baseStyle,
  ) {
    final textColor = baseStyle.color ?? AppColors.getTextColor(context);
    final matches = _latexRegex.allMatches(mathAwareText).toList();

    if (matches.isEmpty) {
      return Text(
        mathAwareText,
        style: baseStyle,
        textAlign: isTitle ? TextAlign.center : TextAlign.start,
        textDirection: TextDirection.rtl,
      );
    }

    final children = <Widget>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        final textSegment = mathAwareText.substring(cursor, match.start).trim();
        if (textSegment.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                textSegment,
                style: baseStyle,
                textAlign: isTitle ? TextAlign.center : TextAlign.start,
                textDirection: TextDirection.rtl,
              ),
            ),
          );
        }
      }

      final token = match.group(0)!;
      final latex = _stripMathDelimiters(token);
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: isTitle ? Alignment.center : Alignment.centerRight,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Math.tex(
                latex,
                mathStyle:
                    _isDisplayMath(token) ? MathStyle.display : MathStyle.text,
                textStyle: TextStyle(
                  color: textColor,
                  fontSize: (baseStyle.fontSize ?? 16) + 2,
                ),
                onErrorFallback: (error) => Text(
                  token,
                  style: baseStyle.copyWith(
                    color: Colors.redAccent,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ),
      );

      cursor = match.end;
    }

    if (cursor < mathAwareText.length) {
      final trailing = mathAwareText.substring(cursor).trim();
      if (trailing.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              trailing,
              style: baseStyle,
              textAlign: isTitle ? TextAlign.center : TextAlign.start,
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment:
          isTitle ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static bool _isDisplayMath(String token) {
    return token.startsWith(r'\[') ||
        token.startsWith('\$\$') ||
        (token.startsWith(r'\(') == false && token.startsWith('\$') == false);
  }

  static String _stripMathDelimiters(String token) {
    if (token.startsWith(r'\[') && token.endsWith(r'\]')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith(r'\(') && token.endsWith(r'\)')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith('\$\$') && token.endsWith('\$\$')) {
      return token.substring(2, token.length - 2);
    }
    if (token.startsWith('\$') && token.endsWith('\$')) {
      return token.substring(1, token.length - 1);
    }
    return token;
  }
}
