import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart' as yt;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../core/env/multi_env.dart';

class YoutubeUploadService {
  // Use envied (always available at compile time) instead of dotenv
  GoogleSignIn get _googleSignIn => GoogleSignIn(
        scopes: [
          yt.YouTubeApi.youtubeUploadScope,
          yt.YouTubeApi.youtubeReadonlyScope,
        ],
        clientId: kIsWeb ? (Env.googleWebClientId.isNotEmpty ? Env.googleWebClientId : null) : null,
      );

  Future<bool> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('⚠️ [YouTube] User cancelled sign-in.');
        return false;
      }
      debugPrint('✅ [YouTube] Signed in as: ${account.email}');
      return true;
    } catch (e) {
      debugPrint('❌ [YouTube] Sign-in error: $e');
      rethrow;
    }
  }

  Future<String?> uploadUnlistedVideo(
    XFile videoFile,
    String title,
    String description,
  ) async {
    try {
      debugPrint('🎬 [YouTube] Starting upload: $title');

      // Ensure we are signed in, but prefer the explicit signIn() call first
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      if (account == null) {
        account = await _googleSignIn.signIn();
        if (account == null) {
          debugPrint('⚠️ [YouTube] User cancelled sign-in.');
          return null;
        }
      }

      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) {
        throw Exception('Failed to get authenticated HTTP client');
      }

      final youtube = yt.YouTubeApi(authClient);

      // Build video metadata
      final video = yt.Video()
        ..snippet = (yt.VideoSnippet()
          ..title = title
          ..description = description)
        ..status = (yt.VideoStatus()..privacyStatus = 'unlisted');

      // Read file bytes — works on Web AND native
      final Uint8List bytes = await videoFile.readAsBytes();
      final int length = bytes.length;
      debugPrint('📦 [YouTube] Video size: ${(length / 1024 / 1024).toStringAsFixed(1)} MB');

      // Build a stream from bytes (compatible with Web)
      final stream = Stream<List<int>>.fromIterable([bytes]);
      final media = yt.Media(stream, length);

      debugPrint('⬆️ [YouTube] Uploading...');
      final uploadedVideo = await youtube.videos.insert(
        video,
        ['snippet', 'status'],
        uploadMedia: media,
      );

      authClient.close();

      if (uploadedVideo.id != null) {
        final url = 'https://www.youtube.com/watch?v=${uploadedVideo.id}';
        debugPrint('✅ [YouTube] Upload successful: $url');
        return url;
      } else {
        debugPrint('❌ [YouTube] Upload returned no video ID.');
        return null;
      }
    } on yt.DetailedApiRequestError catch (e) {
      debugPrint('❌ [YouTube API Error] ${e.status}: ${e.message}');
      debugPrint('   Errors: ${e.errors}');
      rethrow;
    } catch (e, stack) {
      debugPrint('❌ [YouTube Upload Error] $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }
}
