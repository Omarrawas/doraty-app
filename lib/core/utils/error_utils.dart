import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorUtils {
  /// Translates technical errors into user-friendly messages
  static String getFriendlyErrorMessage(Object error) {
    // Check for network errors
    final errorString = error.toString().toLowerCase();
    
    // Common network error indicators
    if (errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('stream reached end of content before message was complete')) {
      return 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى';
    }

    // Supabase specific errors
    if (error is AuthException) {
      if (error.message.contains('Invalid login credentials') ||
          error.message.contains('invalid_credentials')) {
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      }
      if (error.message.contains('Email not confirmed')) {
        return 'الرجاء تأكيد البريد الإلكتروني الخاص بك من خلال الرابط المرسل إليك';
      }
      if (error.message.contains('User not found')) {
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      }
      return 'حدث خطأ في المصادقة: ${error.message}';
    }

    if (error is PostgrestException) {
      // Handle Postgres/Postgrest errors which usually have 'PostgrestException' or 'Postgres' in them
      if (error.message.toLowerCase().contains('jwt') || 
          error.code == 'PGRST301') {
        return 'انتهت صلاحية الجلسة، يرجى تسجيل الخروج والخول مرة أخرى';
      }
      
      // If it's a network-like error wrapped in PostgrestException
      if (error.message.toLowerCase().contains('connection') || 
          error.message.toLowerCase().contains('fetch')) {
        return 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى';
      }
      
      return 'حدث خطأ في جلب البيانات. يرجى المحاولة لاحقاً';
    }

    // General fallback
    if (errorString.contains('postgrest') || errorString.contains('postgres')) {
      return 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى';
    }

    return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
  }
}
