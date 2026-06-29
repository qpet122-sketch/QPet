import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vet/main.dart';

class BulkExportView extends StatefulWidget {
  const BulkExportView({super.key});

  @override
  State<BulkExportView> createState() => _BulkExportViewState();
}

class _BulkExportViewState extends State<BulkExportView> {
  bool isExporting = false;

  Future<List<Map<String, dynamic>>> _fetchAllPets() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('pets').orderBy('petIndex').get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['url'] = 'https://mohamedyasser37.github.io/qpet1/#/pet/${doc.id}';
      return data;
    }).toList();
  }

  Future<void> _exportQrCodes(bool isAr) async {
    setState(() => isExporting = true);
    try {
      final pets = await _fetchAllPets();
      final pdf = pw.Document();
      final fontBold = await PdfGoogleFonts.amiriBold();

      // تحميل صورة اللوجو مرة واحدة قبل البدء
      final logoData = (await rootBundle.load('assets/final_logo-Photoroom.png')).buffer.asUint8List();
      final logoImage = pw.MemoryImage(logoData);

      for (var pet in pets) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) => pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('QPet SmartID #${pet['id']}', style: pw.TextStyle(fontSize: 14, font: fontBold)),
                    pw.SizedBox(height: 4),
                    pw.Stack(
                      alignment: pw.Alignment.center,
                      children: [
                        pw.BarcodeWidget(
                          data: pet['url'],
                          barcode: pw.Barcode.qrCode(),
                          width: 200,
                          height: 200,
                        ),
                        pw.Container(
                          width: 40, height: 40,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Image(logoImage, width: 30),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: isAr ? 'كافة_الرموز' : 'All_QR_Codes');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Future<void> _exportPasswords(bool isAr) async {
    setState(() => isExporting = true);
    try {
      final pets = await _fetchAllPets();
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.amiriRegular();
      final fontBold = await PdfGoogleFonts.amiriBold();

      for (var pet in pets) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            build: (context) => pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(15)),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(isAr ? 'بيانات تعديل الحساب' : 'Account Edit Details', style: pw.TextStyle(fontSize: 12, font: fontBold, color: PdfColors.teal)),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Column(
                            children: [
                              pw.Text('ID', style: pw.TextStyle(fontSize: 10, font: font)),
                              pw.Text('${pet['id']}', style: pw.TextStyle(fontSize: 16, font: fontBold)),
                            ],
                          ),
                          pw.Container(width: 1, height: 30, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 20)),
                          pw.Column(
                            children: [
                              pw.Text(isAr ? 'كلمة السر' : 'Password', style: pw.TextStyle(fontSize: 10, font: font)),
                              pw.Text(pet['editPassword'] ?? '---', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: fontBold, letterSpacing: 3)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text('QPet Smart ID System', style: pw.TextStyle(fontSize: 8, font: font, color: PdfColors.grey600)),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: isAr ? 'كافة_كلمات_السر' : 'All_Passwords');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color gold = const Color(0xFFC5A059);

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Text(isAr ? 'تصدير السجلات' : 'Export Records', style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.folder_zip_outlined, size: 100, color: isDark ? gold : primaryColor),
              const SizedBox(height: 32),
              Text(
                isAr ? 'تصدير كافة السجلات المخزنة في النظام' : 'Export all stored records in the system',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              if (isExporting)
                const CircularProgressIndicator()
              else ...[
                _exportButton(
                  isAr ? 'تحميل كافة الرموز (PDF)' : 'Export All QR Codes',
                  Icons.qr_code_2_rounded,
                  isDark ? gold : primaryColor,
                  () => _exportQrCodes(isAr),
                  isDark
                ),
                const SizedBox(height: 16),
                _exportButton(
                  isAr ? 'تحميل كافة كلمات السر (PDF)' : 'Export All Passwords',
                  Icons.password_rounded,
                  isDark ? gold : primaryColor,
                  () => _exportPasswords(isAr),
                  isDark
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportButton(String title, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: isDark ? Colors.black87 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
        ),
      ),
    );
  }
}
