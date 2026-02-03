import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/constants/app_strings.dart';

class DiscussionsTab extends StatefulWidget {
  final String courseId;

  const DiscussionsTab({super.key, required this.courseId});

  @override
  State<DiscussionsTab> createState() => _DiscussionsTabState();
}

class _DiscussionsTabState extends State<DiscussionsTab> {
  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  Widget build(BuildContext context) {
    final isAr = Provider.of<LocaleProvider>(context).locale == 'ar';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upcoming_rounded,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 24),
            Text(
              _t('discussions_coming_soon'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'نحن نعمل على تطوير تجربة مناقشة متكاملة لك.'
                  : 'We are working on developing a comprehensive discussion experience for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
