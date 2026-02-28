import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/ai_service.dart';
import '../../models/lesson.dart';

class AIAssistantScreen extends StatefulWidget {
  final Lesson lesson;

  const AIAssistantScreen({super.key, required this.lesson});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasGeminiKey = false;

  @override
  void initState() {
    super.initState();
    _checkGeminiKey();
    // Add welcome message
    _messages.add(ChatMessage(
      text:
          'أهلاً بك! أنا مساعدك الدراسي الذكي في منصة دوراتي. كيف يمكنني مساعدتك في درس "${widget.lesson.title}"؟',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _checkGeminiKey() async {
    final key = await SettingsService().getGeminiApiKey();
    if (mounted) {
      setState(() {
        _hasGeminiKey = key != null && key.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Get AI response
      // Pass history excluding the message we just added
      final response = await _aiService.askQuestion(
        lesson: widget.lesson,
        question: text,
        history: _messages.sublist(0, _messages.length - 1).map((m) => {
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.text,
        }).toList(),
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'عذراً، حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAction(String action) async {
    String question = '';
    if (action == 'summarize') {
      question = 'لخص لي هذا الدرس في نقاط سريعة.';
    } else if (action == 'key_points') {
      question = 'ما هي أهم المفاهيم التي يجب أن أركز عليها في هذا الدرس؟';
    } else if (action == 'q_and_a') {
      question = 'اطرح علي سؤالين لاختبار مدى فهمي لهذا الدرس.';
    }

    if (question.isNotEmpty) {
      _sendMessage(question);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryPurple.withOpacity(0.1),
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildChatList()),
            if (_isLoading) _buildLoadingIndicator(),
            _buildQuickActions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 15,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const CircleAvatar(
                backgroundColor: AppColors.primaryPurple,
                radius: 18,
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مساعد دوراتي الذكي',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_hasGeminiKey)
                IconButton(
                  icon: const Icon(Icons.link_off_rounded, color: Colors.orangeAccent),
                  tooltip: 'ربط Gemini',
                  onPressed: _showLinkGeminiDialog,
                )
              else
                IconButton(
                  icon: const Icon(Icons.link_rounded, color: Colors.greenAccent),
                  tooltip: 'تم الربط',
                  onPressed: _showLinkGeminiDialog,
                ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
                tooltip: 'مسح المحادثة',
                onPressed: () {
                  setState(() {
                    _messages.clear();
                    _messages.add(ChatMessage(
                      text: 'تم مسح المحادثة. كيف يمكنني مساعدتك في درس "${widget.lesson.title}"؟',
                      isUser: false,
                      timestamp: DateTime.now(),
                    ));
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: message.isUser
                  ? const LinearGradient(
                      colors: [AppColors.primaryPurple, Color(0xFF9D4EDD)],
                    )
                  : LinearGradient(
                      colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(message.isUser ? 16 : 0),
                bottomRight: Radius.circular(message.isUser ? 0 : 16),
              ),
              border: message.isUser
                  ? null
                  : Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // Left for AI
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'جاري التفكير...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildActionButton('✨ تلخيص الدرس', () => _handleAction('summarize')),
          _buildActionButton('📌 أهم النقاط', () => _handleAction('key_points')),
          _buildActionButton('❓ اختبرني', () => _handleAction('q_and_a')),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        15,
        20,
        MediaQuery.of(context).padding.bottom + 15,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _messageController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'اسأل المساعد الذكي...',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: AppColors.primaryPurple,
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showLinkGeminiDialog() async {
    final currentKey = await SettingsService().getGeminiApiKey();
    if (!mounted) return;
    
    final TextEditingController keyController = TextEditingController(
      text: currentKey ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'ربط مفتاح API (Gemini)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'للحصول على أفضل تجربة، يمكنك استخدام مفتاح API الخاص بك من Google Gemini.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: keyController,
              textAlign: TextAlign.left,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'أدخل مفتاح API هنا...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.vpn_key, color: Colors.white24),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _launchURL('https://aistudio.google.com/app/apikey'),
              child: const Text(
                'كيف أحصل على مفتاح API؟',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = keyController.text.trim();
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              await SettingsService().setGeminiApiKey(newKey.isEmpty ? null : newKey);
              
              if (mounted) {
                navigator.pop();
                _checkGeminiKey();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      newKey.isEmpty ? 'تم إزالة الربط' : 'تم ربط Gemini بنجاح',
                      textAlign: TextAlign.right,
                    ),
                    backgroundColor: newKey.isEmpty ? Colors.grey : Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
