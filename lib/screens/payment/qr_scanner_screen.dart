import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_utils.dart';
import '../../core/services/database_service.dart';

class QrScannerScreen extends StatefulWidget {
  QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() => _isProcessing = true);
        cameraController.stop(); // Stop scanning while processing
        
        await _processCode(code);
      }
    }
  }

  Future<void> _processCode(String code) async {
    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = _db.currentUserId;
      if (userId == null) {
        throw Exception('يرجى تسجيل الدخول أولاً');
      }
      
      final result = await _db.redeemQrCode(code, userId);
      if (mounted) Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false, // Force user to acknowledge
            builder: (ctx) => AlertDialog(
              title: Text('تم بنجاح!', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64),
                  SizedBox(height: 16),
                  Text(
                    result['message'] ?? 'تم تفعيل الكود بنجاح',
                    textAlign: TextAlign.center,
                  ),
                  if (result['courses_enrolled'] != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'تم تفعيل ${result['courses_enrolled']} مادة/مواد',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context, true); // Return success to previous screen
                  },
                  child: Text('موافق'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          _showErrorDialog(result['message'] ?? 'كود غير صالح');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showErrorDialog(ErrorUtils.getFriendlyErrorMessage(e));
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isProcessing = false);
              cameraController.start(); // Resume scanning
            },
            child: Text('حاول مرة أخرى'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مسح كود QR'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            color: AppColors.getTextColor(context),
            icon: Icon(Icons.flash_on, color: Colors.yellow),
            iconSize: 32.0,
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            color: AppColors.getTextColor(context),
            icon: Icon(Icons.cameraswitch),
            iconSize: 32.0,
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: AppColors.primaryPurple,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'وجه الكاميرا نحو الكود للمسح',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.getTextColor(context, secondary: true),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Overlay Shape Painter (Basic Implementation)
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRect(Rect.fromCenter(
        center: rect.center,
        width: cutOutSize,
        height: cutOutSize,
      ));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    // final borderWidthSize = width / 2; // Unused
    // final height = rect.height; // Unused
    // final borderOffset = borderWidth / 2; // Unused
    final mBorderLength = borderLength > cutOutSize / 2 + borderWidth * 2
        ? borderWidth * 2
        : borderLength;
    final mCutOutSize = cutOutSize < width ? cutOutSize : width - borderWidth;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: mCutOutSize,
      height: mCutOutSize,
    );

    canvas.saveLayer(
      rect,
      backgroundPaint,
    );

    canvas.drawRect(
      rect,
      backgroundPaint,
    );

    // Draw cut out
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cutOutRect,
        Radius.circular(borderRadius),
      ),
      boxPaint,
    );

    canvas.restore();

    final borderPath = Path()
      ..moveTo(cutOutRect.left, cutOutRect.top + mBorderLength)
      ..lineTo(cutOutRect.left, cutOutRect.top + borderRadius)
      ..arcToPoint(
        Offset(cutOutRect.left + borderRadius, cutOutRect.top),
        radius: Radius.circular(borderRadius),
      )
      ..lineTo(cutOutRect.left + mBorderLength, cutOutRect.top)
      ..moveTo(cutOutRect.right, cutOutRect.top + mBorderLength)
      ..lineTo(cutOutRect.right, cutOutRect.top + borderRadius)
      ..arcToPoint(
        Offset(cutOutRect.right - borderRadius, cutOutRect.top),
        radius: Radius.circular(borderRadius),
        clockwise: false,
      )
      ..lineTo(cutOutRect.right - mBorderLength, cutOutRect.top)
      ..moveTo(cutOutRect.right, cutOutRect.bottom - mBorderLength)
      ..lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius)
      ..arcToPoint(
        Offset(cutOutRect.right - borderRadius, cutOutRect.bottom),
        radius: Radius.circular(borderRadius),
      )
      ..lineTo(cutOutRect.right - mBorderLength, cutOutRect.bottom)
      ..moveTo(cutOutRect.left, cutOutRect.bottom - mBorderLength)
      ..lineTo(cutOutRect.left, cutOutRect.bottom - borderRadius)
      ..arcToPoint(
        Offset(cutOutRect.left + borderRadius, cutOutRect.bottom),
        radius: Radius.circular(borderRadius),
        clockwise: false,
      )
      ..lineTo(cutOutRect.left + mBorderLength, cutOutRect.bottom);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
