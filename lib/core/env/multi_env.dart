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
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNzdGxxeWpvZmxoeHRvY3J0eXBnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5MTg4ODQsImV4cCI6MjA3OTQ5NDg4NH0.qF7RU9yndmuoDHXhhnitURuTM8cSr4UMuoxHh8b1_vM')
  static const String supabaseAnonKey = _Env.supabaseAnonKey;

  @EnviedField(
      varName: 'ENCRYPTION_KEY',
      defaultValue: 'default_encryption_key_32_chars_long!')
  static const String encryptionKey = _Env.encryptionKey;
  
  @EnviedField(
      varName: 'GOOGLE_WEB_CLIENT_ID',
      defaultValue:
          '535436798827-0rogt5b5beuq7lgsrl5ommvpa49q62bh.apps.googleusercontent.com')
  static const String googleWebClientId = _Env.googleWebClientId;

  @EnviedField(
      varName: 'GOOGLE_IOS_CLIENT_ID',
      defaultValue: 'YOUR_GOOGLE_IOS_CLIENT_ID')
  static const String googleIosClientId = _Env.googleIosClientId;

  @EnviedField(
      varName: 'GOOGLE_ANDROID_CLIENT_ID',
      defaultValue:
          '535436798827-23an8ocpmvq3aj0ad8v426nqqid0vf14.apps.googleusercontent.com')
  static const String googleAndroidClientId = _Env.googleAndroidClientId;

  @EnviedField(varName: 'GITHUB_TOKEN', defaultValue: '')
  static const String githubToken = _Env.githubToken;
}
