import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  SupabaseService._();

  bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }
  
  /// Get the Supabase client safely. 
  /// Note: Only call this when you are sure Supabase is initialized.
  SupabaseClient get client {
    if (!isInitialized) {
      // Return the underlying client if possible, it might throw its own error
      // which is often more descriptive in the debugger, but we prefer ours.
      try {
        return Supabase.instance.client;
      } catch (_) {
        throw Exception(
          'Supabase has not been initialized. Please call SupabaseService.initialize() first.');
      }
    }
    return Supabase.instance.client;
  }

  /// Check if user is authenticated safely
  bool get isAuthenticated => isInitialized ? Supabase.instance.client.auth.currentUser != null : false;

  /// Get current user safely
  User? get currentUser => isInitialized ? Supabase.instance.client.auth.currentUser : null;

  /// Get current user ID safely
  String? get currentUserId => isInitialized ? Supabase.instance.client.auth.currentUser?.id : null;

  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        debug: kDebugMode,
      );
    } catch (e) {
      debugPrint('🚨 Supabase initialization error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (isInitialized) {
      await client.auth.signOut();
    }
  }
}
