import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_utils.dart';
import '../../core/services/database_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  bool _isProcessing = false;
  final MobileScannerController cameraController = MobileScannerController();
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() => _isProcessing = true);
        cameraController.stop();
        await _processCode(code);
      }
    }
  }

  Future<void> _processCode(String code) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      ),
    );

    try {
      final userId = _db.currentUserId;
      if (userId == null) throw Exception('يرجى تسجيل الدخول أولاً');
      
      final result = await _db.redeemQrCode(code, userId);
      if (mounted) Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        if (mounted) {
          await _showGlassResultDialog(
            title: 'تم بنجاح!',
            message: result['message'] ?? 'تم تفعيل الكود بنجاح',
            isSuccess: true,
            extra: result['courses_enrolled'] != null ? 'تم تفعيل ${result['courses_enrolled']} مادة' : null,
          );
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        if (mounted) _showGlassResultDialog(title: 'خطأ', message: result['message'] ?? 'كود غير صالح', isSuccess: false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showGlassResultDialog(title: 'خطأ', message: ErrorUtils.getFriendlyErrorMessage(e), isSuccess: false);
      }
    }
  }

  Future<void> _showGlassResultDialog({required String title, required String message, required bool isSuccess, String? extra}) async {
    return showDialog(
      context: context,
      barrierDismissible: !isSuccess,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.getSurfaceColor(context).withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                size: 72,
              ),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo')),
              if (extra != null) ...[
                const SizedBox(height: 10),
                Text(extra, style: TextStyle(color: AppColors.getMutedTextColor(context), fontSize: 13, fontFamily: 'Cairo')),
              ],
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (!isSuccess) {
                    setState(() => _isProcessing = false);
                    cameraController.start();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? Colors.greenAccent.withOpacity(0.2) : Colors.white10,
                  foregroundColor: isSuccess ? Colors.greenAccent : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(isSuccess ? 'موافق' : 'حاول مرة أخرى', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('مسح كود QR', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          // Gradient Dark Overlay for focus
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
          // Scanner UI
          _buildScannerOverlay(),
          // Action Buttons
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGlassButton(
                  icon: Icons.flash_on_rounded,
                  onTap: () => cameraController.toggleTorch(),
                ),
                const SizedBox(width: 30),
                _buildGlassButton(
                  icon: Icons.flip_camera_ios_rounded,
                  onTap: () => cameraController.switchCamera(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.7;
        return Stack(
          children: [
            Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryPurple.withOpacity(0.5), width: 2),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            // Corner Borders
            Center(
              child: CustomPaint(
                size: Size(size, size),
                painter: ScannerCornersPainter(color: AppColors.primaryPurple),
              ),
            ),
            // Animated Scan Line
            Center(
              child: AnimatedBuilder(
                animation: _scanLineController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, (size * 0.8) * (_scanLineController.value - 0.5)),
                    child: Container(
                      width: size * 0.9,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primaryPurple.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: constraints.maxHeight * 0.5 + size * 0.6,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Text(
                    'وجه الكاميرا نحو الكود',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم تفعيل المواد تلقائياً عند المسح',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ScannerCornersPainter extends CustomPainter {
  final Color color;
  ScannerCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const length = 40.0;
    const radius = 24.0;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(0, length)
        ..lineTo(0, radius)
        ..arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius))
        ..lineTo(length, 0),
      paint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius))
        ..lineTo(size.width, length),
      paint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - length)
        ..lineTo(size.width, size.height - radius)
        ..arcToPoint(Offset(size.width - radius, size.height), radius: const Radius.circular(radius))
        ..lineTo(size.width - length, size.height),
      paint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(length, size.height)
        ..lineTo(radius, size.height)
        ..arcToPoint(Offset(0, size.height - radius), radius: const Radius.circular(radius))
        ..lineTo(0, size.height - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
