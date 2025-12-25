import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;

class CertificateService {
  /// Generate and share certificate PDF
  Future<void> downloadCertificate({
    required String studentName,
    required String courseName,
    required String instructorName,
    required DateTime date, // Completion date
  }) async {
    final pdf = pw.Document();

    // Load Arabic Font (Cairo)
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Border
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.blue900,
                    width: 5,
                  ),
                ),
              ),
              pw.Container(
                margin: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.amber,
                    width: 2,
                  ),
                ),
              ),

              // Content
              pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Title
                    pw.Text(
                      'شهادة إتمام دورة',
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 40,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    pw.Text(
                      'تشهد منصة دراستي أن الطالب',
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 20,
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    // Student Name
                    pw.Text(
                      studentName,
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 30,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    pw.Text(
                      'قد أتم بنجاح دورة',
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 20,
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    // Course Name
                    pw.Text(
                      courseName,
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 28,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 40),

                    // Footer (Instructor & Date)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text(
                              'التاريخ',
                              textDirection: pw.TextDirection.rtl,
                              style: pw.TextStyle(font: font, fontSize: 18),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              intl.DateFormat('yyyy/MM/dd').format(date),
                              style: pw.TextStyle(font: font, fontSize: 16),
                            ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              'المدرس',
                              textDirection: pw.TextDirection.rtl,
                              style: pw.TextStyle(font: font, fontSize: 18),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              instructorName,
                              textDirection: pw.TextDirection.rtl,
                              style: pw.TextStyle(font: fontBold, fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 40),
                    // Logo or Footer Text
                    pw.Text(
                      'Doraty Academy',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                        color: PdfColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Share the file
    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'certificate_$courseName.pdf');
  }
}
