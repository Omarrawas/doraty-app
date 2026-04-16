import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:universal_html/html.dart' as html;
import 'platform_view_registry_stub.dart'
    if (dart.library.js_util) 'dart:ui_web' as ui_web;

/// A widget that handles external video players via IFrames (Web) 
/// or WebView (Windows/Mobile). Supported hosts like avcaption, vimeo, etc.
class ExternalVideoPlayer extends StatefulWidget {
  final String url;
  final double? height;

  const ExternalVideoPlayer({
    super.key,
    required this.url,
    this.height,
  });

  @override
  State<ExternalVideoPlayer> createState() => _ExternalVideoPlayerState();
}

class _ExternalVideoPlayerState extends State<ExternalVideoPlayer> {
  static int _viewCounter = 0;
  late String _viewId;
  
  @override
  void initState() {
    super.initState();
    _viewCounter++;
    _viewId = 'external-video-$_viewCounter';

    if (kIsWeb) {
      // Register the view factory for Web
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = widget.url
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';

          iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen');
          iframe.setAttribute('allowfullscreen', 'true');

          return iframe;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final double playerHeight = widget.height ?? 
        (isLandscape ? size.height : (size.width * 9 / 16).clamp(200, 500));

    if (kIsWeb) {
      return SizedBox(
        height: playerHeight,
        child: HtmlElementView(viewType: _viewId),
      );
    }

    // For Windows and Mobile, use InAppWebView
    return SizedBox(
      height: playerHeight,
      child: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(widget.url),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useWideViewPort: true,
          loadWithOverviewMode: true,
          isElementFullscreenEnabled: true,
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
      ),
    );
  }
}
