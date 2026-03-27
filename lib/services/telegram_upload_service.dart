import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class TelegramUploadService {
  final String botToken = dotenv.get('TIPS_BOT_TOKEN', fallback: '');
  final String chatId = dotenv.get('TIPS_CHAT_ID', fallback: '');
  final String streamerHost = dotenv.get('STREAMER_HOST', fallback: 'https://omarrawas17-doraty-video-stream.hf.space');

  final Dio _dio = Dio();

  Future<String?> uploadAndGetLink(XFile videoFile) async {
    try {
      if (botToken.isEmpty || chatId.isEmpty) {
        throw Exception("Telegram configuration is missing. Check your .env file.");
      }

      // 1. Prepare Upload to Telegram
      String url = "https://api.telegram.org/bot$botToken/sendVideo";
      
      final bytes = await videoFile.readAsBytes();
      FormData formData = FormData.fromMap({
        'chat_id': chatId,
        'video': MultipartFile.fromBytes(bytes, filename: videoFile.name),
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
      debugPrint("Error Uploading to Telegram: $e");
    }
    return null;
  }
}
