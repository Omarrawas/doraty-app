import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/discount_code.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/empty_state.dart';
import 'package:intl/intl.dart';

class DiscountCodesManagementScreen extends StatefulWidget {
  const DiscountCodesManagementScreen({super.key});

  @override
  State<DiscountCodesManagementScreen> createState() => _DiscountCodesManagementScreenState();
}

class _DiscountCodesManagementScreenState extends State<DiscountCodesManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<DiscountCode> _codes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() => _isLoading = true);
    try {
      final response = await _dbService.client
          .from('discount_codes')
          .select()
          .order('created_at', ascending: false);
      
      final List<dynamic> data = response;
      setState(() {
        _codes = data.map((json) => DiscountCode.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading discount codes: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCodeStatus(DiscountCode code) async {
    try {
      await _dbService.client
          .from('discount_codes')
          .update({'is_active': !code.isActive})
          .eq('id', code.id);
      _loadCodes();
    } catch (e) {
      debugPrint('Error toggling code status: $e');
    }
  }

  Future<void> _deleteCode(String id) async {
    try {
      await _dbService.client.from('discount_codes').delete().eq('id', id);
      _loadCodes();
    } catch (e) {
      debugPrint('Error deleting code: $e');
    }
  }

  void _showAddCodeDialog() {
    final codeController = TextEditingController();
    final percentController = TextEditingController();
    final limitController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة كود خصم جديد', textAlign: TextAlign.right),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'كود الخصم (مثل: NEWYEAR)', alignLabelWithHint: true),
                  textAlign: TextAlign.right,
                  textCapitalization: TextCapitalization.characters,
                ),
                TextField(
                  controller: percentController,
                  decoration: const InputDecoration(labelText: 'نسبة الخصم (%)', alignLabelWithHint: true),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: limitController,
                  decoration: const InputDecoration(labelText: 'حد الاستخدام (اختياري)', alignLabelWithHint: true),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(selectedDate == null ? 'تاريخ الانتهاء' : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.isEmpty || percentController.text.isEmpty) return;
                
                try {
                  await _dbService.client.from('discount_codes').insert({
                    'code': codeController.text.trim().toUpperCase(),
                    'discount_percent': int.parse(percentController.text),
                    'usage_limit': limitController.text.isEmpty ? null : int.parse(limitController.text),
                    'valid_until': selectedDate?.toIso8601String(),
                    'is_active': true,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadCodes();
                } catch (e) {
                  debugPrint('Error creating code: $e');
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة أكواد الخصم'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCodeDialog,
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient(context)),
        child: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShimmerLoader.rectangular(height: 100),
                ),
              )
            : _codes.isEmpty
                ? ProfessionalEmptyState(
                    title: 'لا توجد أكواد خصم',
                    message: 'لا توجد أكواد خصم حالياً. اضغط + لإضافة كود جديد.',
                    icon: Icons.discount_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _codes.length,
                    itemBuilder: (context, index) {
                      final code = _codes[index];
                      return _buildCodeCard(code);
                    },
                  ),
      ),
    );
  }

  Widget _buildCodeCard(DiscountCode code) {
    final bool isExpired = code.validUntil != null && DateTime.now().isAfter(code.validUntil!);
    final bool isLimitReached = code.usageLimit != null && code.usageCount >= code.usageLimit!;
    final bool isEffectivelyActive = code.isActive && !isExpired && !isLimitReached;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
                  ),
                  child: Text(
                    code.code,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryPurple),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: code.isActive,
                  onChanged: (val) => _toggleCodeStatus(code),
                  activeColor: AppColors.primaryPurple,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteCode(code.id),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem('الخصم', '${code.discountPercent}%'),
                _buildInfoItem('الاستخدام', '${code.usageCount} / ${code.usageLimit ?? '∞'}'),
                _buildInfoItem('الحالة', isEffectivelyActive ? 'فعال' : (isExpired ? 'منتهي' : 'متوقف'), 
                  color: isEffectivelyActive ? Colors.green : Colors.red),
              ],
            ),
            if (code.validUntil != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'تاريخ الانتهاء: ${DateFormat('yyyy-MM-dd').format(code.validUntil!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
