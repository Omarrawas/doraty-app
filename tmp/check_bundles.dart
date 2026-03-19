import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

void main() async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase.from('bundles').select('*');
    debugPrint('Bundles table exists! Count: ${response.length}');
  } catch (e) {
    debugPrint('Bundles table does not exist or error: $e');
  }
}
