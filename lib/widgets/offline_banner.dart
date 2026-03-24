import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/sync_service.dart';

/// A banner that appears when the device is offline OR a sync is in progress.
/// Add it at the top of any Scaffold body that needs sync awareness.
///
/// Usage:
/// ```dart
/// Column(children: [
///   OfflineBanner(),
///   Expanded(child: myContent),
/// ])
/// ```
class OfflineBanner extends StatefulWidget {
  OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final _sync = SyncService();

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!_sync.isOffline && !_sync.isSyncing) return SizedBox.shrink();

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: _sync.isOffline ? Colors.red.shade700 : Colors.orange.shade700,
      child: Row(
        children: [
          Icon(
            _sync.isOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
            color: AppColors.getTextColor(context),
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            _sync.isOffline
                ? 'أنت غير متصل — يعمل بالبيانات المخزنة'
                : 'جاري مزامنة البيانات...',
            style: TextStyle(
              color: AppColors.getTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
            ),
          ),
          if (_sync.isSyncing) ...[
            Spacer(),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
