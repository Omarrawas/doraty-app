import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/lesson.dart';
import '../../models/flashcard.dart';
import 'settings_service.dart';
import 'supabase_service.dart';
import '../utils/error_utils.dart';

class AIService {
  // Mock fallback if nothing is configured
  static const String _openaiApiKey = ''; // Optional
  static const String _openaiBaseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> askQuestion({
    required Lesson lesson,
    required String question,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final geminiKey = SettingsService().getGeminiApiKey();
      if (_openaiApiKey.isEmpty && (geminiKey == null || geminiKey.isEmpty)) {
        // Add a small delay for natural feel
        await Future.delayed(const Duration(seconds: 1));
        return _getMockResponse(question);
      }

      if (geminiKey != null && geminiKey.isNotEmpty) {
        return _askGemini(geminiKey, lesson, question, history);
      }

      return _askOpenAI(lesson, question, history);
    } catch (e) {
      debugPrint('AI Error: $e');
      return ErrorUtils.getFriendlyErrorMessage(e);
    }
  }

  Future<String> _askGemini(String apiKey, Lesson lesson, String question, List<Map<String, String>> history) async {
    final baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';
    
    final context = _buildContext(lesson);
    final systemPrompt = 'أنك مساعد تعليمي ذكي لمنصة دوراتي (Doraty). '
        'قدم إجابات واضحة ومفيدة بناءً على محتوى الدرس المقدم. '
        'عنوان الدرس: "${lesson.title}". '
        'المحتوى: $context. '
        'أجب دائماً باللغة العربية.';

    // Gemini requires alternating roles: user, model, user, model...
    // We combine system prompt with the first user message or handle it as a single turn
    final List<Map<String, dynamic>> contents = [];
    
    // Combine system instructions with the actual question for the first turn if history is empty
    if (history.isEmpty) {
      contents.add({
        'role': 'user',
        'parts': [{'text': '$systemPrompt\n\nالسؤال: $question'}]
      });
    } else {
      // If there is history, start with system prompt as first user message
      contents.add({
        'role': 'user',
        'parts': [{'text': systemPrompt}]
      });
      // Add a placeholder model response to keep alternation
      contents.add({
        'role': 'model',
        'parts': [{'text': 'حسناً، أنا جاهز لمساعدتك في هذا الدرس. تفضل بسؤالك.'}]
      });
      
      // Filter out empty messages and ensure no duplicate consecutive user roles
      final List<Map<String, String>> cleanedHistory = [];
      String? lastRole;
      
      for (var msg in history) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        if (role != lastRole && msg['content'] != null && msg['content']!.isNotEmpty) {
          cleanedHistory.add({'role': role, 'content': msg['content']!});
          lastRole = role;
        }
      }

      // Add history
      for (var msg in cleanedHistory) {
        contents.add({
          'role': msg['role'],
          'parts': [{'text': msg['content']}]
        });
      }
      
      // Add the current question, but check if we need to insert a placeholder if last was user
      if (lastRole == 'user') {
        contents.add({
          'role': 'model',
          'parts': [{'text': 'حسناً، فهمت. تفضل.'}]
        });
      }

      contents.add({
        'role': 'user',
        'parts': [{'text': question}]
      });
    }

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contents': contents}),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('Gemini Error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> _askOpenAI(Lesson lesson, String question, List<Map<String, String>> history) async {
    final context = _buildContext(lesson);
    final messages = [
      {
        'role': 'system',
        'content': 'You are a helpful educational assistant for the Doraty platform. '
            'Provide clear, concise, and helpful answers based on the lesson content provided. '
            'The lesson title is "${lesson.title}". context: $context'
      },
      ...history,
      {'role': 'user', 'content': question},
    ];

    final response = await http.post(
      Uri.parse(_openaiBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': messages,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI Error: ${response.statusCode}');
    }
  }

  Future<List<Flashcard>> generateFlashcards(Lesson lesson) async {
    final apiKey = SettingsService().getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key is required to generate flashcards');
    }

    final prompt = 'بناءً على محتوى الدرس التالي، قم بإنشاء 5 إلى 7 بطاقات استذكار (Flashcards). '
        'كل بطاقة يجب أن تحتوي على فكرة أساسية (سؤال أو مصطلح) في الواجهة (front) ومعلومة مفصلة أو تعريف في الخلف (back). '
        'نسق الإجابة كملف JSON فقط، عبارة عن قائمة من الكائنات بهذا الشكل بالضبط: '
        '[{"front": "سؤال", "back": "إجابة"}]'
        '\n\nمحتوى الدرس: ${_buildContext(lesson)}';

    final baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';
    
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{
          'role': 'user',
          'parts': [{'text': prompt}]
        }]
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String text = data['candidates'][0]['content']['parts'][0]['text'];
      
      // Clean up markdown code blocks if present
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final List<dynamic> jsonList = jsonDecode(text);
      return jsonList.map((e) => Flashcard(
        id: '',
        front: e['front'],
        back: e['back'],
        lessonId: lesson.id,
      )).toList();
    } else {
      throw Exception('Failed to generate flashcards: ${response.statusCode}');
    }
  }

  Future<void> saveFlashcards(List<Flashcard> cards) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;

    final data = cards.map((c) => {
      'user_id': userId,
      'lesson_id': c.lessonId!,
      'front': c.front,
      'back': c.back,
      'next_review_date': DateTime.now().toIso8601String(),
    }).toList();

    await SupabaseService.instance.client.from('flashcards').insert(data);
  }

  String _buildContext(Lesson lesson) {
    return 'Title: ${lesson.title}\nDescription: ${lesson.description}\n'
        'Content: ${lesson.content ?? lesson.contentMarkdown ?? lesson.contentHtml ?? ""}';
  }

  String _getMockResponse(String question) {
    // Basic mock logic to feel interactive
    if (question.contains('لخص') || question.contains('تلخيص')) {
      return '• هذا الدرس يتحدث عن المفاهيم الأساسية للمادة.\n'
             '• تم شرح كيفية تطبيق القواعد العلمية في المسائل.\n'
             '• ركز المعلم على الأخطاء الشائعة التي يقع فيها الطلاب.\n'
             '• ننصح بمراجعة الملاحظات الذكية التي قمت بتدوينها.';
    }
    
    return 'أنا المساعد الذكي الخاص بك في منصة Doraty. حالياً أنا في المرحلة التجريبية. '
           'يمكنني مساعدتك في فهم محتوى الدرس وتلخيصه والإجابة على استفساراتك. '
           '(ملاحظة: يتطلب تفعيل الخدمة الكاملة ربط مفتاح API الخاص بالذكاء الاصطناعي)';
  }
}
