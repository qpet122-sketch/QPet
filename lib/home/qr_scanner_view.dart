import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vet/home/edit_pet_view.dart';
import 'package:vet/main.dart';
import 'package:image_picker/image_picker.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with WidgetsBindingObserver {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, 
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
  );
  bool isPermissionGranted = false;
  bool isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    setState(() => isPermissionGranted = status.isGranted);
    if (isPermissionGranted) {
      Future.delayed(const Duration(milliseconds: 500), () { if (mounted) controller.start(); });
    }
  }

  Future<void> _pickAndScanImage() async {
    if (isProcessing) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => isProcessing = true);
    controller.stop();
    
    try {
      final BarcodeCapture? result = await controller.analyzeImage(image.path);
      if (result != null && result.barcodes.isNotEmpty) {
        final code = result.barcodes.first.rawValue;
        if (code != null) await _processResult(code);
      } else {
        setState(() => isProcessing = false);
        bool isAr = MyApp.of(context).locale.languageCode == 'ar';
        _showErrorDialog(isAr ? 'لم يتم العثور على رمز QR في هذه الصورة.' : 'No QR code found in this image.');
        controller.start();
      }
    } catch (e) {
      setState(() => isProcessing = false);
      _showErrorDialog('Error: $e');
      controller.start();
    }
  }

  String _extractIdFromUrl(String data) {
    if (data.contains('/')) {
      return data.split('/').last.trim();
    }
    return data.trim();
  }

  Future<void> _processResult(String code) async {
    final petId = _extractIdFromUrl(code);
    try {
      final doc = await FirebaseFirestore.instance.collection('pets').doc(petId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentUser = FirebaseAuth.instance.currentUser;
        String? role;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          role = userDoc.data()?['role'];
        }

        if (mounted && role == 'doctor') {
          bool isAr = MyApp.of(context).locale.languageCode == 'ar';
          bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
          Color textColor = isDark ? Colors.white : Colors.black87;
          Color gold = const Color(0xFFC5A059);

          bool proceed = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              title: Text(isAr ? 'تم التعرف على أليف' : 'Pet Recognized', style: TextStyle(color: textColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
                  const SizedBox(height: 15),
                  Text('${isAr ? 'الاسم:' : 'Name:'} ${data['animalName']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                  Text('ID: $petId', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(isAr ? 'إغلاق' : 'Close', style: const TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: ElevatedButton.styleFrom(backgroundColor: isDark ? gold : Theme.of(context).primaryColor, foregroundColor: isDark ? Colors.black87 : Colors.white),
                  child: Text(isAr ? 'فتح السجل' : 'Open Record'),
                ),
              ],
            ),
          ) ?? false;

          if (!proceed) {
            setState(() => isProcessing = false);
            controller.start();
            return;
          }
        }

        if (mounted) _showResultSheet(petId, data);
      } else {
        if (mounted) {
          setState(() => isProcessing = false);
          bool isAr = MyApp.of(context).locale.languageCode == 'ar';
          _showErrorDialog(isAr ? 'عذراً، هذا الرمز غير مسجل لدينا.' : 'Sorry, this code is not registered.');
          controller.start();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isProcessing = false);
        _showErrorDialog('Error: $e');
        controller.start();
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (isProcessing || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    setState(() => isProcessing = true);
    controller.stop();
    await _processResult(code);
  }

  void _showResultSheet(String petId, Map<String, dynamic> data) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;
    bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color gold = const Color(0xFFC5A059);

    bool alreadyLinked = false;
    List<String> myPetIds = [];
    String? role;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      myPetIds = List<String>.from(userDoc.data()?['petIds'] ?? []);
      alreadyLinked = myPetIds.contains(petId);
      role = userDoc.data()?['role'];
    }

    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.pets, color: isDark ? gold : primaryColor, size: 40),
                if (currentUser != null)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => (role == 'doctor' || alreadyLinked) ? Navigator.pop(context, 'edit') : _verifyPassword(petId, data, true),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(isAr ? 'بيانات الأليف' : 'Pet Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 20),
            _buildDataRow(isAr ? 'الاسم:' : 'Name:', data['animalName'], textColor),
            _buildDataRow(isAr ? 'النوع:' : 'Type:', data['animalType'], textColor),
            _buildDataRow(isAr ? 'الصاحب:' : 'Owner:', data['ownerName'], textColor),
            _buildDataRow(isAr ? 'الهاتف:' : 'Phone:', data['ownerPhone'], textColor),
            const SizedBox(height: 30),
            if (currentUser != null && role == 'owner' && !alreadyLinked)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _verifyPassword(petId, data, false), icon: const Icon(Icons.add_task), label: Text(isAr ? 'إضافة إلى أليفي' : 'Add to My Pet'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: isDark ? gold : primaryColor), foregroundColor: isDark ? gold : primaryColor))),
              ),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context, 'close'), style: ElevatedButton.styleFrom(backgroundColor: isDark ? gold : primaryColor, foregroundColor: isDark ? Colors.black87 : Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(isAr ? 'إغلاق' : 'Close', style: const TextStyle(fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (result == 'edit') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => EditPetView(petId: petId, initialData: data)));
    } else {
      Navigator.pop(context);
    }
  }

  void _verifyPassword(String petId, Map<String, dynamic> data, bool forEdit) {
    final passController = TextEditingController();
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color gold = const Color(0xFFC5A059);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(forEdit ? (isAr ? 'كلمة سر التعديل' : 'Edit Password') : (isAr ? 'كلمة سر الإضافة' : 'Add Password'), style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAr ? 'أدخل كلمة السر الخاصة بهذا الأليف' : 'Enter the password for this pet', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(controller: passController, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: isAr ? 'كلمة السر' : 'Password', hintStyle: const TextStyle(color: Colors.grey), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? gold : Theme.of(context).primaryColor))), autofocus: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (passController.text == data['editPassword']) {
                Navigator.pop(c);
                if (forEdit) {
                  Navigator.pop(context); 
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => EditPetView(petId: petId, initialData: data)));
                } else {
                  final user = FirebaseAuth.instance.currentUser;
                  final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
                  final userDoc = await userRef.get();
                  final List petIds = List.from(userDoc.data()?['petIds'] ?? []);
                  if (petIds.length >= 2) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'عذراً، يمكنك إضافة حيوانين فقط كحد أقصى' : 'Sorry, you can only add up to 2 pets'), backgroundColor: Colors.orange));
                    return;
                  }
                  await userRef.update({'petIds': FieldValue.arrayUnion([petId])});
                  await FirebaseFirestore.instance.collection('pets').doc(petId).update({'ownerUid': user.uid});
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تمت الإضافة إلى أليفي بنجاح!' : 'Added to My Pet successfully!'), backgroundColor: Colors.green));
                  }
                }
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(isAr ? 'عذراً، رمز التعديل غير صحيح. يرجى التأكد من الرمز والمحاولة مرة أخرى.' : 'Oops! Incorrect edit password. Please check the code and try again.', style: const TextStyle(fontWeight: FontWeight.bold)))]), backgroundColor: Colors.red.shade800, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 3)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? gold : Theme.of(context).primaryColor, foregroundColor: isDark ? Colors.black87 : Colors.white),
            child: Text(isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(isAr ? 'ماسح QPet' : 'QPet Scanner'), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.image), onPressed: _pickAndScanImage, tooltip: isAr ? 'مسح من المعرض' : 'Scan from Gallery')]),
      body: !isPermissionGranted ? Center(child: Text(isAr ? 'يرجى إعطاء إذن الكاميرا' : 'Please grant camera permission', style: const TextStyle(color: Colors.white))) :
      Stack(children: [MobileScanner(controller: controller, onDetect: _onDetect), Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Theme.of(context).primaryColor, width: 4), borderRadius: BorderRadius.circular(20)))), if (isProcessing) Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))]),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(context: context, builder: (c) => AlertDialog(content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
  }

  Widget _buildDataRow(String l, String? v, Color textColor) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v ?? '?', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))]));

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); controller.dispose(); super.dispose(); }
}
