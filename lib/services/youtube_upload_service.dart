import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart' as yt;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:image_picker/image_picker.dart';

class YoutubeUploadService {
  GoogleSignIn get _googleSignIn => GoogleSignIn(
    scopes: [
      yt.YouTubeApi.youtubeUploadScope,
    ],
    clientId: dotenv.isInitialized ? dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '') : '',
  );

  Future<String?> uploadUnlistedVideo(XFile videoFile, String title, String description) async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;

      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) throw Exception("Failed to get auth client");

      final youtube = yt.YouTubeApi(authClient);

      var video = yt.Video();
      video.snippet = yt.VideoSnippet();
      video.snippet?.title = title;
      video.snippet?.description = description;
      
      video.status = yt.VideoStatus();
      video.status?.privacyStatus = "unlisted";

      final length = await videoFile.length();
      final stream = videoFile.openRead();
      var media = yt.Media(stream, length);
      
      var uploadedVideo = await youtube.videos.insert(
        video, 
        ["snippet", "status"], 
        uploadMedia: media
      );

      if (uploadedVideo.id != null) {
        return "https://www.youtube.com/watch?v=${uploadedVideo.id}";
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error Uploading to YouTube: $e");
    }
    return null;
  }
}
