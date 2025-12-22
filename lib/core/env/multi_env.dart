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
}
