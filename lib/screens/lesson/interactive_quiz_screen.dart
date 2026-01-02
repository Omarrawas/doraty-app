import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
// import 'dart:io'; (Removed to avoid web error)
import 'package:flutter/foundation.dart';

class InteractiveQuizScreen extends StatefulWidget {
  final String? content;
  final String? url;
  final String title;
  final bool isHtml;

  const InteractiveQuizScreen({
    super.key,
    this.content,
    this.url,
    this.title = 'عرض المحتوى',
    this.isHtml = true,
  }) : assert(content != null || url != null, 'Either content or url must be provided');

  @override
  State<InteractiveQuizScreen> createState() => _InteractiveQuizScreenState();
}

class _InteractiveQuizScreenState extends State<InteractiveQuizScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final bool isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    if (!kIsWeb && isMobile) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
          ),
        );
      
      if (widget.url != null) {
        _controller.loadRequest(Uri.parse(widget.url!));
      } else if (widget.content != null) {
        _controller.loadHtmlString(_wrapHtmlContent(widget.content!));
      }
    }
  }

  String _wrapHtmlContent(String content) {
    if (!widget.isHtml) {
      // Basic markdown to html wrapping if needed, but for now assuming html or pre-wrapped
      return content;
    }
    return '''
      <!DOCTYPE html>
      <html dir="rtl">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            body { 
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              padding: 16px;
              line-height: 1.6;
              color: #333;
              background-color: #fff;
            }
            img { max-width: 100%; height: auto; border-radius: 8px; }
            .quiz-container { max-width: 600px; margin: 0 auto; }
          </style>
        </head>
        <body>
          <div class="quiz-container">
            $content
          </div>
        </body>
      </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primaryPurple,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          if (isMobile)
            WebViewWidget(controller: _controller)
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 64, color: Colors.amber),
                    SizedBox(height: 16),
                    Text(
                      'عذراً، المحتوى التفاعلي متاح فقط على تطبيقات الجوال (Android/iOS).',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading && isMobile)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
        ],
      ),
    );
  }
}
