import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vet/main.dart';

class AddAnimalView extends StatefulWidget {
  const AddAnimalView({super.key});

  @override
  State<AddAnimalView> createState() => _AddAnimalViewState();
}

class _AddAnimalViewState extends State<AddAnimalView> {
  final _countController = TextEditingController(text: '1');
  bool isSaving = false;

  // قائمة لتخزين بيانات الحيوانات المنشأة حديثاً
  List<Map<String, dynamic>> _newlyCreatedPets = [];

  String _generateRandomPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(Random().nextInt(chars.length))));
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color goldColor = const Color(0xFFC5A059);

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Text(isAr ? 'إنشاء رموز QPet' : 'Generate QPet Codes', style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor, 
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.qr_code_2_rounded, size: 100, color: isDark ? goldColor : primaryColor),
              const SizedBox(height: 32),
              Text(
                isAr ? 'كم عدد الرموز التي تود إنشاؤها؟' : 'How many codes do you want to generate?', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 16)
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _countController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '1',
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? goldColor : primaryColor, width: 2)),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : () => _generateMultiplePets(isAr),
                  icon: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    isSaving 
                        ? (isAr ? 'جاري الإنشاء...' : 'Generating...') 
                        : (isAr ? 'إنشاء الرموز وحفظها' : 'Generate & Save'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? goldColor : primaryColor, 
                    foregroundColor: isDark ? Colors.black87 : Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 4
                  ),
                ),
              ),
              if (_newlyCreatedPets.isNotEmpty) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _generatePdfReport(isAr),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(isAr ? 'تحميل ملف الرموز' : 'Download PDF Report'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? goldColor : primaryColor,
                    side: BorderSide(color: isDark ? goldColor : primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateMultiplePets(bool isAr) async {
    int count = int.tryParse(_countController.text) ?? 1;
    if (count <= 0) return;
    if (count > 50) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'الحد الأقصى 50 في المرة الواحدة' : 'Maximum 50 at a time')));
      return;
    }

    setState(() {
      isSaving = true;
      _newlyCreatedPets = [];
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('pets').orderBy(FieldPath.documentId).get();
      int startId = 1;
      if (querySnapshot.docs.isNotEmpty) {
        List<int> existingIds = querySnapshot.docs.map((doc) => int.tryParse(doc.id) ?? 0).toList();
        existingIds.sort();
        startId = existingIds.last + 1;
      }

      final batch = FirebaseFirestore.instance.batch();
      List<Map<String, dynamic>> results = [];

      for (int i = 0; i < count; i++) {
        int currentId = startId + i;
        String password = _generateRandomPassword();
        String petIdStr = currentId.toString();
        
        Map<String, dynamic> petData = {
          'animalName': 'أليف',
          'animalType': '',
          'gender': '',
          'sterilizationStatus': '',
          'ownerName': '',
          'ownerPhone': '',
          'editPassword': password,
          'timestamp': FieldValue.serverTimestamp(),
          'petIndex': currentId,
          'vaccinations_list': [],
          'surgeries_list': [],
          'medications_list': [],
          'allergies_list': [],
          'chronic_diseases_list': [],
        };

        batch.set(FirebaseFirestore.instance.collection('pets').doc(petIdStr), petData);
        
        results.add({
          'id': petIdStr,
          'password': password,
          'url': 'https://mohamedyasser37.github.io/qpet1/#/pet/$petIdStr'
        });
      }

      await batch.commit();

      setState(() {
        _newlyCreatedPets = results;
        isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'تم إنشاء $count رمز بنجاح' : '$count codes created successfully'),
            backgroundColor: Colors.green,
          )
        );
        _generatePdfReport(isAr); // فتح ملف الـ PDF تلقائياً بعد النجاح
      }
    } catch (e) {
      setState(() => isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generatePdfReport(bool isAr) async {
    final pdf = pw.Document();
    
    // تحميل خطوط واضحة
    final font = await PdfGoogleFonts.amiriRegular();
    final fontBold = await PdfGoogleFonts.amiriBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(isAr ? 'رموز التعريف الذكية - QPet' : 'QPet Smart ID Codes', 
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: fontBold, color: PdfColors.teal900)),
                    pw.Text(isAr ? 'تقرير الإنشاء الجماعي' : 'Batch Generation Report', 
                      style: pw.TextStyle(fontSize: 12, font: font, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(DateTime.now().toString().split(' ').first, style: pw.TextStyle(font: font)),
              ],
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Wrap(
            spacing: 20,
            runSpacing: 20,
            children: _newlyCreatedPets.map((pet) {
              return pw.Container(
                width: (PdfPageFormat.a4.width - 100) / 2, 
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(15)),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    // إطار داخلي للبيانات الأساسية - تم تصغيره ليكون مضغوطاً جداً
                    pw.Container(
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(' QPet SmartID #${pet['id']}', style: pw.TextStyle(fontSize: 8, font: fontBold, color: PdfColors.teal)),
                          pw.SizedBox(height: 3),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey200), 
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))
                            ),
                            child: pw.BarcodeWidget(
                              data: pet['url'],
                              barcode: pw.Barcode.qrCode(),
                              width: 80,
                              height: 80,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    // الـ ID وكلمة السر معاً
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 5),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Column(
                            children: [
                              pw.Text('ID', style: pw.TextStyle(fontSize: 7, font: font)),
                              pw.Text('${pet['id']}', style: pw.TextStyle(fontSize: 12, font: fontBold)),
                            ],
                          ),
                          pw.Container(width: 1, height: 20, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 10)),
                          pw.Column(
                            children: [
                              pw.Text(isAr ? 'كلمة السر' : 'Password', style: pw.TextStyle(fontSize: 7, font: font)),
                              pw.Text(pet['password'], style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: fontBold, letterSpacing: 2)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
