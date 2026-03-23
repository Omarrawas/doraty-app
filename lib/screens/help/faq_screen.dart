import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/dynamic_gradient_background.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> _getFaqs(BuildContext context, String locale) {
    return [
      {
        'question': AppStrings.get('faq_how_subscribe', locale),
        'answer': AppStrings.get('faq_how_subscribe_ans', locale),
      },
      {
        'question': AppStrings.get('faq_payment_methods', locale),
        'answer': AppStrings.get('faq_payment_methods_ans', locale),
      },
      {
        'question': AppStrings.get('faq_certificate', locale),
        'answer': AppStrings.get('faq_certificate_ans', locale),
      },
      {
        'question': AppStrings.get('faq_contact_teacher', locale),
        'answer': AppStrings.get('faq_contact_teacher_ans', locale),
      },
      {
        'question': AppStrings.get('faq_support', locale),
        'answer': AppStrings.get('faq_support_ans', locale),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final faqs = _getFaqs(context, locale);
    
    final filteredFaqs = faqs.where((faq) {
      final q = faq['question']!.toLowerCase();
      final a = faq['answer']!.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return q.contains(query) || a.contains(query);
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          AppStrings.get('faq', locale),
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      hintText: AppStrings.get('faq_search_hint', locale),
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontFamily: 'Cairo'),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.white38 : Colors.black38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
                ),
              ),

              // FAQ List
              Expanded(
                child: filteredFaqs.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.get('no_results', locale) == 'no_results' ? 'لم يتم العثور على نتائج' : AppStrings.get('no_results', locale),
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontFamily: 'Cairo'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filteredFaqs.length,
                        itemBuilder: (context, index) {
                          return _buildFaqItem(
                            filteredFaqs[index]['question']!,
                            filteredFaqs[index]['answer']!,
                            isDark,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.primaryPurple,
          collapsedIconColor: isDark ? Colors.white38 : Colors.black38,
          title: Text(
            question,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              fontFamily: 'Cairo',
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                answer,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                  height: 1.6,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
