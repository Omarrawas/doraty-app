import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../models/session.dart';

class SessionsManagementScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const SessionsManagementScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<SessionsManagementScreen> createState() =>
      _SessionsManagementScreenState();
}

class _SessionsManagementScreenState extends State<SessionsManagementScreen> {
  List<Session> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.instance.client
          .from('sessions')
          .select()
          .eq('course_id', widget.courseId)
          .order('scheduled_at', ascending: true);
      setState(() {
        _sessions = (response as List)
            .map((e) => Session.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSession(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkNavy,
        title: const Text('حذف الجلسة', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذه الجلسة؟',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.instance.client
        .from('sessions')
        .delete()
        .eq('id', id);
    _loadSessions();
  }

  void _showSessionDialog([Session? existing]) {
    showDialog(
      context: context,
      builder: (ctx) => _SessionFormDialog(
        courseId: widget.courseId,
        existing: existing,
        onSaved: _loadSessions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إدارة الجلسات',
                style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo')),
            Text(widget.courseTitle,
                style: TextStyle(
                    color: AppColors.primaryPurple.withOpacity(0.8),
                    fontSize: 12,
                    fontFamily: 'Cairo')),
          ],
        ),
        iconTheme: IconThemeData(color: AppColors.getTextColor(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh,
                color: AppColors.getTextColor(context).withOpacity(0.7)),
            onPressed: _loadSessions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSessionDialog(),
        backgroundColor: AppColors.primaryPurple,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('جلسة جديدة',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo')),
      ),
      body: DynamicGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryPurple))
              : _sessions.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _sessions.length,
                      itemBuilder: (_, i) => _SessionCard(
                        session: _sessions[i],
                        onEdit: () => _showSessionDialog(_sessions[i]),
                        onDelete: () => _deleteSession(_sessions[i].id),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_camera_back_outlined,
                size: 72,
                color: AppColors.getMutedTextColor(context).withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('لا توجد جلسات بعد',
                style: TextStyle(
                    color: AppColors.getTextColor(context, secondary: true),
                    fontSize: 16,
                    fontFamily: 'Cairo')),
            const SizedBox(height: 8),
            Text('اضغط + لإضافة أول جلسة',
                style: TextStyle(
                    color: AppColors.getMutedTextColor(context),
                    fontSize: 13,
                    fontFamily: 'Cairo')),
          ],
        ),
      );
}

// ── Session Card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SessionCard(
      {required this.session, required this.onEdit, required this.onDelete});

  Color get _statusColor => switch (session.status) {
        SessionStatus.liveNow => const Color(0xFFEF4444),
        SessionStatus.completed => const Color(0xFF22C55E),
        SessionStatus.cancelled => Colors.grey,
        _ => AppColors.primaryPurple,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE، d MMMM yyyy  •  hh:mm a', 'ar');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: isDark ? 0.05 : 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _statusColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor.withOpacity(0.5)),
                    ),
                    child: Text(session.statusLabel,
                        style: TextStyle(
                            color: _statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 20,
                        color:
                            AppColors.getTextColor(context, secondary: true)),
                    onPressed: onEdit,
                    tooltip: 'تعديل',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.redAccent),
                    onPressed: onDelete,
                    tooltip: 'حذف',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                      style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo')),
                  if (session.description != null &&
                      session.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(session.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.getTextColor(context,
                                secondary: true),
                            fontSize: 13,
                            fontFamily: 'Cairo')),
                  ],
                  const SizedBox(height: 12),
                  // Date row
                  _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      text: fmt.format(session.scheduledAt.toLocal())),
                  const SizedBox(height: 6),
                  _InfoRow(
                      icon: Icons.timer_outlined,
                      text: '${session.durationMinutes} دقيقة'),
                  if (session.location != null &&
                      session.location!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: session.location!),
                  ],
                  if (session.joinUrl != null &&
                      session.joinUrl!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                        icon: Icons.video_call_outlined,
                        text: session.platformLabel),
                  ],
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    children: [
                      if (session.joinUrl != null && session.isJoinable)
                        Expanded(
                          child: _ActionBtn(
                            label: 'انضم للجلسة',
                            icon: Icons.video_call_rounded,
                            color: const Color(0xFF22C55E),
                            onTap: () => launchUrl(Uri.parse(session.joinUrl!)),
                          ),
                        ),
                      if (session.joinUrl != null && session.isJoinable)
                        const SizedBox(width: 8),
                      if (session.recordingUrl != null &&
                          session.recordingUrl!.isNotEmpty)
                        Expanded(
                          child: _ActionBtn(
                            label: 'التسجيل',
                            icon: Icons.play_circle_outline,
                            color: const Color(0xFF8B5CF6),
                            onTap: () =>
                                launchUrl(Uri.parse(session.recordingUrl!)),
                          ),
                        ),
                      if (session.status == SessionStatus.completed &&
                          (session.recordingUrl == null ||
                              session.recordingUrl!.isEmpty))
                        Expanded(
                          child: _ActionBtn(
                            label: 'أضف التسجيل',
                            icon: Icons.add_link,
                            color: Colors.orange,
                            onTap: onEdit,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primaryPurple.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: AppColors.getTextColor(context, secondary: true),
                      fontSize: 13,
                      fontFamily: 'Cairo'))),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo')),
            ],
          ),
        ),
      );
}

// ── Session Form Dialog ──────────────────────────────────────────────────────

class _SessionFormDialog extends StatefulWidget {
  final String courseId;
  final Session? existing;
  final VoidCallback onSaved;

  const _SessionFormDialog({
    required this.courseId,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_SessionFormDialog> createState() => _SessionFormDialogState();
}

class _SessionFormDialogState extends State<_SessionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _joinUrlCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _recordingCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _maxAttendeesCtrl;

  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  SessionPlatform _platform = SessionPlatform.zoom;
  SessionStatus _status = SessionStatus.upcoming;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _joinUrlCtrl = TextEditingController(text: e?.joinUrl ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _recordingCtrl = TextEditingController(text: e?.recordingUrl ?? '');
    _durationCtrl =
        TextEditingController(text: (e?.durationMinutes ?? 60).toString());
    _maxAttendeesCtrl =
        TextEditingController(text: e?.maxAttendees?.toString() ?? '');
    if (e != null) {
      _scheduledAt = e.scheduledAt;
      _platform = e.platform;
      _status = e.status;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _joinUrlCtrl,
      _locationCtrl,
      _recordingCtrl,
      _durationCtrl,
      _maxAttendeesCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final payload = {
      'course_id': widget.courseId,
      'title': _titleCtrl.text.trim(),
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'scheduled_at': _scheduledAt.toIso8601String(),
      'duration_minutes': int.tryParse(_durationCtrl.text) ?? 60,
      'join_url':
          _joinUrlCtrl.text.trim().isEmpty ? null : _joinUrlCtrl.text.trim(),
      'platform': _platform.name,
      'location':
          _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      'recording_url': _recordingCtrl.text.trim().isEmpty
          ? null
          : _recordingCtrl.text.trim(),
      'status': Session.fromJson({
        'id': '',
        'course_id': '',
        'title': '',
        'scheduled_at': _scheduledAt.toIso8601String(),
        'status': _statusName(_status),
      }).toJson()['status'],
      'max_attendees': _maxAttendeesCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_maxAttendeesCtrl.text),
    };

    try {
      if (widget.existing != null) {
        await SupabaseService.instance.client
            .from('sessions')
            .update(payload)
            .eq('id', widget.existing!.id);
      } else {
        await SupabaseService.instance.client.from('sessions').insert(payload);
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _statusName(SessionStatus s) => switch (s) {
        SessionStatus.liveNow => 'live_now',
        SessionStatus.completed => 'completed',
        SessionStatus.cancelled => 'cancelled',
        _ => 'upcoming',
      };

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final dateFmt = DateFormat('EEEE، d MMM yyyy  •  hh:mm a', 'ar');

    return Dialog(
      backgroundColor: AppColors.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title bar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                        color: AppColors.primaryPurple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      isEdit ? 'تعديل الجلسة' : 'جلسة جديدة',
                      style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo'),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close,
                          color:
                              AppColors.getTextColor(context, secondary: true),
                          size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _field('عنوان الجلسة *', _titleCtrl,
                    validator: (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null),
                _field('وصف الجلسة (اختياري)', _descCtrl, maxLines: 2),

                // Date picker
                Text('موعد الجلسة *',
                    style: TextStyle(
                        color: AppColors.getTextColor(context, secondary: true),
                        fontSize: 13,
                        fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.getInputFillColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primaryPurple.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 12),
                        Text(dateFmt.format(_scheduledAt),
                            style: TextStyle(
                                color: AppColors.getTextColor(context),
                                fontSize: 13,
                                fontFamily: 'Cairo')),
                        const Spacer(),
                        Icon(Icons.edit,
                            size: 14,
                            color: AppColors.getMutedTextColor(context)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                        child: _field('المدة (دقيقة)', _durationCtrl,
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field('أقصى عدد مشاركين', _maxAttendeesCtrl,
                            keyboardType: TextInputType.number)),
                  ],
                ),

                // Platform dropdown
                _label('المنصة'),
                DropdownButtonFormField<SessionPlatform>(
                  value: _platform,
                  dropdownColor: AppColors.getSurfaceColor(context),
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: _inputDeco(),
                  items: SessionPlatform.values
                      .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(_platformLabel(p),
                              style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontFamily: 'Cairo'))))
                      .toList(),
                  onChanged: (v) => setState(() => _platform = v!),
                ),
                const SizedBox(height: 16),

                _field('رابط الانضمام (Zoom / Meet...)', _joinUrlCtrl),
                _field('المكان (للحضوري)', _locationCtrl),
                _field('رابط التسجيل (بعد الجلسة)', _recordingCtrl),

                // Status dropdown
                _label('الحالة'),
                DropdownButtonFormField<SessionStatus>(
                  value: _status,
                  dropdownColor: AppColors.getSurfaceColor(context),
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: _inputDeco(),
                  items: SessionStatus.values
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(_statusLabel(s),
                              style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontFamily: 'Cairo'))))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ الجلسة',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Cairo')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _platformLabel(SessionPlatform p) => switch (p) {
        SessionPlatform.zoom => 'Zoom',
        SessionPlatform.meet => 'Google Meet',
        SessionPlatform.youtube => 'YouTube Live',
        SessionPlatform.teams => 'Microsoft Teams',
        _ => 'رابط مخصص',
      };

  String _statusLabel(SessionStatus s) => switch (s) {
        SessionStatus.upcoming => '🕐 قادمة',
        SessionStatus.liveNow => '🔴 مباشر الآن',
        SessionStatus.completed => '✅ منتهية',
        SessionStatus.cancelled => '❌ ملغاة',
      };

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
              color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
          decoration: _inputDeco(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                color: AppColors.getTextColor(context, secondary: true),
                fontSize: 13,
                fontFamily: 'Cairo')),
      );

  InputDecoration _inputDeco() => InputDecoration(
        filled: true,
        fillColor: AppColors.getInputFillColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.primaryPurple.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.primaryPurple.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryPurple, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
