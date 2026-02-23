import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:ui_web' as ui_web;

class YoutubePlayerWebWindows extends StatefulWidget {
  final String videoId;
  final double? height;

  const YoutubePlayerWebWindows({
    super.key,
    required this.videoId,
    this.height,
  });

  @override
  State<YoutubePlayerWebWindows> createState() => _YoutubePlayerWebWindowsState();
}

class _YoutubePlayerWebWindowsState extends State<YoutubePlayerWebWindows> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'youtube-${widget.videoId}';
    
    if (kIsWeb) {
      // Register the view factory for Web
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = 'https://www.youtube-nocookie.com/embed/${widget.videoId}?autoplay=0&rel=0&modestbranding=1&fs=1'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true;
            
          // Set allow attribute for fullscreen and other permissions
          iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen');
          iframe.setAttribute('webkitallowfullscreen', 'true');
          iframe.setAttribute('mozallowfullscreen', 'true');
          
          return iframe;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double playerHeight = widget.height ?? 
        (MediaQuery.of(context).size.width * 9 / 16).clamp(200, 500);

    if (kIsWeb) {
      return SizedBox(
        height: playerHeight,
        child: HtmlElementView(viewType: _viewId),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return SizedBox(
        height: playerHeight,
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri('https://www.youtube-nocookie.com/embed/${widget.videoId}?autoplay=0&rel=0&modestbranding=1&fs=1'),
          ),
          initialSettings: InAppWebViewSettings(
            useWideViewPort: true,
            loadWithOverviewMode: true,
            javaScriptEnabled: true,
            transparentBackground: true,
            allowsFullscreenVideo: true,
          ),
        ),
      );
    }

    return Container(
      height: playerHeight,
      color: Colors.black,
      child: const Center(
        child: Text('Platform not supported for this player'),
      ),
    );
  }
}
