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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _generateQrOnlyPdf(isAr),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(isAr ? 'ملف الرموز' : 'QR Codes PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? goldColor : primaryColor,
                          side: BorderSide(color: isDark ? goldColor : primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _generatePasswordsOnlyPdf(isAr),
                        icon: const Icon(Icons.password_rounded),
                        label: Text(isAr ? 'ملف كلمات السر' : 'Passwords PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? goldColor : primaryColor,
                          side: BorderSide(color: isDark ? goldColor : primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                  ],
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
        // توليد الملفين تلقائياً بعد النجاح
        _generateQrOnlyPdf(isAr).then((_) => _generatePasswordsOnlyPdf(isAr));
      }
    } catch (e) {
      setState(() => isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generateQrOnlyPdf(bool isAr) async {
    final pdf = pw.Document();
    final fontBold = await PdfGoogleFonts.amiriBold();

    for (var pet in _newlyCreatedPets) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12), // تصغير حواف الإطار
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('QPet ID: ${pet['id']}', style: pw.TextStyle(fontSize: 14, font: fontBold)), // تصغير الخط قليلاً
                  pw.SizedBox(height: 4), // تقليل المسافة لـ 4 كما طلبت
                  pw.BarcodeWidget(
                    data: pet['url'],
                    barcode: pw.Barcode.qrCode(),
                    width: 200, // تصغير الرمز ليتناسب مع الإطار الصغير
                    height: 200,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: isAr ? 'الرموز' : 'QR_Codes');
  }

  Future<void> _generatePasswordsOnlyPdf(bool isAr) async {
    final pdf = pw.Document();
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
            child: pw.Text(isAr ? 'ملف كلمات السر فقط' : 'Passwords Only Report', 
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: fontBold)),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            cellStyle: pw.TextStyle(font: font),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
            },
            headers: isAr ? ['المعرف (ID)', 'كلمة السر'] : ['Pet ID', 'Password'],
            data: _newlyCreatedPets.map((pet) => [
              pet['id'].toString(),
              pet['password'].toString(),
            ]).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: isAr ? 'كلمات_السر' : 'Passwords');
  }
}
