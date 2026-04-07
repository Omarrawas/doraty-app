import 'package:flutter/material.dart';
import 'dart:ui';
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

class _FAQScreenState extends State<FAQScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _headerAnimController;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar & Header Icon
              _buildHeader(isDark, locale),

              // FAQ List
              Expanded(
                child: filteredFaqs.isEmpty
                    ? _buildEmptyState(isDark, locale)
                    : _buildFaqList(filteredFaqs, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, String locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          // Animated Icon
          AnimatedBuilder(
            animation: _headerAnimController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 5 * _headerAnimController.value),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryPurple.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.help_center_rounded,
                    size: 64,
                    color: AppColors.primaryPurple.withOpacity(0.8),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Search Input with Glassmorphism
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.12),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.get('faq_search_hint', locale),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontFamily: 'Cairo',
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String locale) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 80,
          color: isDark ? Colors.white24 : Colors.black12,
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.get('no_results', locale) == 'no_results' 
              ? 'لم نتمكن من العثور على نتائج' 
              : AppStrings.get('no_results', locale),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black45,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildFaqList(List<Map<String, String>> filteredFaqs, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredFaqs.length,
      itemBuilder: (context, index) {
        return _buildPremiumFaqItem(
          filteredFaqs[index]['question']!,
          filteredFaqs[index]['answer']!,
          isDark,
        );
      },
    );
  }

  Widget _buildPremiumFaqItem(String question, String answer, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: AppColors.primaryPurple,
                collapsedIconColor: isDark ? Colors.white60 : Colors.black45,
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  question,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Text(
                      answer,
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                        height: 1.8,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
