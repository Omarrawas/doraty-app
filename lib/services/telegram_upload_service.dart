import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TelegramUploadService {
  final String botToken = dotenv.get('TIPS_BOT_TOKEN', fallback: '');
  final String chatId = dotenv.get('TIPS_CHAT_ID', fallback: '');
  final String streamerHost = dotenv.get('STREAMER_HOST', fallback: 'https://omarrawas17-doraty-video-stream.hf.space');

  final Dio _dio = Dio();

  Future<String?> uploadAndGetLink(File videoFile) async {
    try {
      if (botToken.isEmpty || chatId.isEmpty) {
        throw Exception("Telegram configuration is missing. Check your .env file.");
      }

      // 1. Prepare Upload to Telegram
      String url = "https://api.telegram.org/bot$botToken/sendVideo";
      
      FormData formData = FormData.fromMap({
        'chat_id': chatId,
        'video': await MultipartFile.fromFile(videoFile.path),
      });

      // 2. Perform Request
      var response = await _dio.post(url, data: formData);

      if (response.statusCode == 200) {
        // 3. Extract file_id
        String fileId = response.data['result']['video']['file_id'];
        
        // 4. Build Link
        // We assume HASH_LENGTH = 0 as recommended
        return "$streamerHost/stream/$fileId";
      }
    } catch (e) {
      print("Error Uploading to Telegram: $e");
    }
    return null;
  }
}
