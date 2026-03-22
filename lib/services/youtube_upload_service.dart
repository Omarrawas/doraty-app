import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart' as yt;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class YoutubeUploadService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      yt.YouTubeApi.youtubeUploadScope,
    ],
    clientId: dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: ''),
  );

  Future<String?> uploadUnlistedVideo(File videoFile, String title, String description) async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;

      final authClient = await account.authenticatedClient();
      if (authClient == null) throw Exception("Failed to get auth client");

      final youtube = yt.YouTubeApi(authClient);

      var video = yt.Video();
      video.snippet = yt.VideoSnippet();
      video.snippet?.title = title;
      video.snippet?.description = description;
      
      video.status = yt.VideoStatus();
      video.status?.privacyStatus = "unlisted";

      var media = yt.Media(videoFile.openRead(), videoFile.lengthSync());
      
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
