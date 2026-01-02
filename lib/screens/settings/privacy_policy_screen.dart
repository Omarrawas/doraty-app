import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('سياسة الخصوصية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('1. مقدمة'),
                    _buildSectionContent(
                      'نحن في "دوراتي" نولي أهمية قصوى لخصوصية بياناتك. تشرح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية معلوماتك الشخصية عند استخدام تطبيقنا.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('2. البيانات التي نجمعها'),
                    _buildSectionContent(
                      'قد نجمع المعلومات التالية:\n'
                      '- المعلومات الشخصية: الاسم، رقم الهاتف، والبريد الإلكتروني عند التسجيل.\n'
                      '- بيانات الاستخدام: معلومات حول كيفية تفاعلك مع التطبيق والدورات التي تشاهدها.\n'
                      '- بيانات الجهاز: نوع الجهاز ونظام التشغيل لأغراض تحسين الأداء.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('3. استخدام البيانات'),
                    _buildSectionContent(
                      'نستخدم بياناتك للأغراض التالية:\n'
                      '- تقديم خدماتنا التعليمية وتحسينها.\n'
                      '- التواصل معك بخصوص تحديثات التطبيق أو الدورات الجديدة.\n'
                      '- ضمان أمان حسابك ومنع الاحتيال.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('4. حماية البيانات'),
                    _buildSectionContent(
                      'نحن نتخذ تدابير أمنية تقنية وتنظيمية مناسبة لحماية بياناتك من الوصول غير المصرح به أو التغيير أو الإفصاح أو الإتلاف.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('5. مشاركة البيانات'),
                    _buildSectionContent(
                      'نحن لا نبيع أو نؤجر بياناتك الشخصية لأطراف ثالثة. قد نشارك البيانات فقط مع مقدمي الخدمات الذين يساعدوننا في تشغيل التطبيق (مثل خدمات الاستضافة) بموجب اتفاقيات سرية صارمة.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('6. حقوقك'),
                    _buildSectionContent(
                      'لديك الحق في الوصول إلى بياناتك الشخصية، وتصحيحها، أو طلب حذفها في أي وقت من خلال إعدادات التطبيق أو التواصل معنا.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('7. التغييرات على السياسة'),
                    _buildSectionContent(
                      'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر. سيتم إخطارك بأي تغييرات جوهرية من خلال التطبيق.',
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'آخر تحديث: 01/01/2026',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.secondaryGold,
        ),
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        height: 1.6,
      ),
      textAlign: TextAlign.justify,
    );
  }
}
