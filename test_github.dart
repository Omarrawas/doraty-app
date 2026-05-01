import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final token = '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';
  final url = Uri.parse('https://api.github.com/user');
  
  print('Testing GitHub token...');
  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github.v3+json',
    },
  );
  
  print('Status code: ${response.statusCode}');
  print('Response body: ${response.body}');
}
