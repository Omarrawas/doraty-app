import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:mime/mime.dart';
import 'encryption_service.dart';

class LocalServerService {
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();

  HttpServer? _server;
  int _port = 0;
  final Map<String, String> _tokenToFile = {};

  // Start the server if not running
  Future<void> start() async {
    if (_server != null) return;

    final router = Router();
    router.get('/stream/<token>', _handleStreamRequest);

    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    // Bind to loopback (localhost) on a random available port (0)
    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    debugPrint('🎥 Local Encryption Server running on port $_port');
  }

  // Get a playable URL for a local encrypted file
  Future<String> getPlayableUrl(String filePath) async {
    await start();

    // Generate a simple token (or use hash of path)
    // Using simple hash for stability across reloads if possible, but map is memory only.
    // Let's use timestamp + random for unique token
    final token = DateTime.now().millisecondsSinceEpoch.toString();
    _tokenToFile[token] = filePath;

    return 'http://127.0.0.1:$_port/stream/$token';
  }

  Future<Response> _handleStreamRequest(Request request, String token) async {
    final filePath = _tokenToFile[token];
    if (filePath == null) {
      return Response.notFound('File not found or expired token');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return Response.notFound('File deleted');
    }

    final totalEncryptedSize = await file.length();
    // Real content size = Encrypted size - 16 bytes IV
    final totalContentSize = totalEncryptedSize - 16;

    final headers = {
      'Content-Type': lookupMimeType(filePath) ?? 'video/mp4',
      'Accept-Ranges': 'bytes',
    };

    final rangeHeader = request.headers['range'];
    if (rangeHeader != null) {
      // Handle Range Request
      try {
        final ranges = rangeHeader.replaceFirst('bytes=', '').split('-');
        int start = int.parse(ranges[0]);
        int end = ranges.length > 1 && ranges[1].isNotEmpty
            ? int.parse(ranges[1])
            : totalContentSize - 1;

        if (start >= totalContentSize) {
          return Response(416, body: 'Requested Range Not Satisfiable');
        }

        // chunk logic
        // Ensure we don't serve more than requested or reasonable size
        if (end >= totalContentSize) end = totalContentSize - 1;

        final contentLength = end - start + 1;

        final bytes = await EncryptionService().decryptRange(file, start, end);

        headers['Content-Range'] = 'bytes $start-$end/$totalContentSize';
        headers['Content-Length'] = contentLength.toString();

        return Response(
          206,
          body: Stream.value(bytes), // Body can be stream or list
          headers: headers,
        );
      } catch (e) {
        debugPrint('Error parsing range: $e');
        return Response.internalServerError(
            body: 'Error processing video range');
      }
    } else {
      // Full content (rarely requested for video streaming, usually starts with 0-)
      headers['Content-Length'] = totalContentSize.toString();
      // Decrypt everything? Too heavy for RAM probably.
      // Better to just support range 0-end if range missing?
      // Or stream it chunks (advanced).
      // Let's return just the first chunk or redirect to Range?
      // Standard video players usually try range.
      // If we must server full:
      // return Response.ok(EncryptionService().decryptStream(file), headers: headers);
      // For now, let's treat "no range" as "start from 0".
      final bytes =
          await EncryptionService().decryptRange(file, 0, totalContentSize - 1);
      return Response.ok(bytes, headers: headers);
    }
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }
}
