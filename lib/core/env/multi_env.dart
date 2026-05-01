import 'package:envied/envied.dart';

part 'multi_env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(
      varName: 'SUPABASE_URL',
      defaultValue: 'https://cstlqyjoflhxtocrtypg.supabase.co')
  static const String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(
      varName: 'SUPABASE_ANON_KEY',
      defaultValue: '')
  static const String supabaseAnonKey = _Env.supabaseAnonKey;

  @EnviedField(
      varName: 'ENCRYPTION_KEY',
      defaultValue: '')
  static const String encryptionKey = _Env.encryptionKey;
  
  @EnviedField(
      varName: 'GOOGLE_WEB_CLIENT_ID',
      defaultValue: '')
  static const String googleWebClientId = _Env.googleWebClientId;

  @EnviedField(
      varName: 'GOOGLE_IOS_CLIENT_ID',
      defaultValue: 'YOUR_GOOGLE_IOS_CLIENT_ID')
  static const String googleIosClientId = _Env.googleIosClientId;

  @EnviedField(
      varName: 'GOOGLE_ANDROID_CLIENT_ID',
      defaultValue: '')
  static const String googleAndroidClientId = _Env.googleAndroidClientId;

  @EnviedField(
      varName: 'DORATY_GITHUB_TOKEN',
      defaultValue: '')
  static const String githubToken = _Env.githubToken;

  @EnviedField(
      varName: 'YouTube_Data_API_v3',
      defaultValue: '')
  static const String youtubeDataApiKey = _Env.youtubeDataApiKey;
}
