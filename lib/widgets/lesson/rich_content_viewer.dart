import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class RichContentViewer extends StatelessWidget {
  final String? htmlContent;
  final String? markdownContent;

  RichContentViewer({
    super.key,
    this.htmlContent,
    this.markdownContent,
  });

  @override
  Widget build(BuildContext context) {
    // إذا لم يكن هناك محتوى، لا نعرض شيء
    if (htmlContent == null && markdownContent == null) {
      return SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: AppColors.getTextColor(context),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'شرح الدرس',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (htmlContent != null)
                HtmlWidget(
                  htmlContent!,
                  textStyle: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 16,
                    height: 1.6,
                    fontFamily: 'Cairo',
                  ),
                  onTapUrl: (url) async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                      return true;
                    }
                    return false;
                  },
                  customStylesBuilder: (element) {
                    if (element.localName == 'h1') {
                      return {
                        'font-size': '24px',
                        'font-weight': 'bold',
                        'margin-top': '16px',
                        'margin-bottom': '12px'
                      };
                    }
                    if (element.localName == 'h2') {
                      return {
                        'font-size': '20px',
                        'font-weight': 'bold',
                        'margin-top': '14px',
                        'margin-bottom': '10px'
                      };
                    }
                    if (element.localName == 'h3') {
                      return {
                        'font-size': '18px',
                        'font-weight': 'bold',
                        'margin-top': '12px',
                        'margin-bottom': '8px'
                      };
                    }
                    if (element.localName == 'a') {
                      return {
                        'color': '#9C27B0',
                        'text-decoration': 'underline'
                      }; // Primary Purple
                    }
                    if (element.localName == 'code') {
                      return {
                        'font-family': 'monospace',
                        'background-color': 'rgba(0, 0, 0, 0.26)',
                        'color': '#69F0AE',
                        'padding': '2px 6px'
                      };
                    }
                    if (element.localName == 'pre') {
                      return {
                        'background-color': 'rgba(0, 0, 0, 0.26)',
                        'padding': '12px',
                        'border-radius': '8px'
                      };
                    }
                    return null;
                  },
                )
              else if (markdownContent != null)
                MarkdownBody(
                  data: markdownContent!,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontSize: 16,
                      height: 1.6,
                    ),
                    h1: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    h2: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    h3: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    listBullet: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontSize: 16,
                    ),
                    code: TextStyle(
                      backgroundColor: Colors.black26,
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    a: TextStyle(
                      color: AppColors.primaryPurple,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
