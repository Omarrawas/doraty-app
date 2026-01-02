import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('الشروط والأحكام', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    _buildSectionTitle('1. قبول الشروط'),
                    _buildSectionContent(
                      'باستخدامك لتطبيق "دوراتي"، فإنك توافق على الالتزام بهذه الشروط والأحكام. إذا كنت لا توافق على أي جزء من هذه الشروط، يرجى عدم استخدام التطبيق.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('2. الحسابات والتسجيل'),
                    _buildSectionContent(
                      'يجب عليك تقديم معلومات دقيقة وكاملة عند إنشاء حساب. أنت مسؤول عن الحفاظ على سرية كلمة المرور الخاصة بك وعن جميع الأنشطة التي تحدث تحت حسابك.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('3. الملكية الفكرية'),
                    _buildSectionContent(
                      'جميع المحتويات الموجودة في التطبيق، بما في ذلك النصوص، الرسومات، الشعارات، الصور، ومقاطع الفيديو، هي ملك لـ "دوراتي" أو المرخصين لها ومحمية بقوانين حقوق النشر والعلامات التجارية.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('4. الاستخدام المقبول'),
                    _buildSectionContent(
                      'تتعهد بعدم استخدام التطبيق لأي غرض غير قانوني أو محظور. يمنع نسخ أو توزيع أو تعديل أي جزء من المحتوى التعليمي دون إذن خظي مسبق.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('5. الاشتراكات والدفع'),
                    _buildSectionContent(
                      'بعض الدورات قد تكون مدفوعة. عند الشراء، أنت توافق على دفع جميع الرسوم والضرائب المطبقة. جميع عمليات الشراء نهائية وغير قابلة للاسترداد إلا وفقاً لتقديرنا الخاص.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('6. تحديد المسؤولية'),
                    _buildSectionContent(
                      'نسعى جاهدين لضمان دقة المعلومات المقدمة، ولكننا لا نضمن خلو التطبيق من الأخطاء. لن نكون مسؤولين عن أي أضرار مباشرة أو غير مباشرة تنشأ عن استخدامك للتطبيق.',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('7. إنهاء الخدمة'),
                    _buildSectionContent(
                      'نحتفظ بالحق في إنهاء أو تعليق وصولك إلى التطبيق فوراً، دون إشعار مسبق، لأي سبب كان، بما في ذلك انتهاك هذه الشروط.',
                    ),
                   const SizedBox(height: 20),
                    _buildSectionTitle('8. القانون الواجب التطبيق'),
                    _buildSectionContent(
                      'تخضع هذه الشروط وتفسر وفقاً لقوانين الجمهورية العربية السورية.',
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
