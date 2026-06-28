import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vet/main.dart';

class ProfileEditView extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProfileEditView({super.key, required this.userData});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController; // حقل رقم الموبايل
  late TextEditingController _fbController;
  late TextEditingController _tgController;
  late TextEditingController _waController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _fbController = TextEditingController(text: widget.userData['facebook'] ?? '');
    _tgController = TextEditingController(text: widget.userData['telegram'] ?? '');
    _waController = TextEditingController(text: widget.userData['whatsapp'] ?? '');

    // إذا كان رقم الهاتف فارغاً في البروفايل، نحاول جلبه من أحد الحيوانات المرتبطة
    if (_phoneController.text.isEmpty) {
      _fetchPhoneFromPets();
    }
  }

  Future<void> _fetchPhoneFromPets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final petsSnapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('ownerUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (petsSnapshot.docs.isNotEmpty && mounted) {
        final petPhone = petsSnapshot.docs.first.data()['ownerPhone'];
        if (petPhone != null && petPhone.toString().isNotEmpty) {
          setState(() {
            _phoneController.text = petPhone.toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching phone from pets: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _fbController.dispose();
    _tgController.dispose();
    _waController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newName = _nameController.text.trim();
        final newPhone = _phoneController.text.trim();

        // 1. تحديث بيانات المستخدم الأساسية
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': newName,
          'phone': newPhone,
          'facebook': _fbController.text.trim(),
          'telegram': _tgController.text.trim(),
          'whatsapp': _waController.text.trim(),
        });

        // 2. مزامنة البيانات مع كافة الحيوانات المرتبطة بهذا المستخدم
        final petsSnapshot = await FirebaseFirestore.instance
            .collection('pets')
            .where('ownerUid', isEqualTo: user.uid)
            .get();

        if (petsSnapshot.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in petsSnapshot.docs) {
            batch.update(doc.reference, {
              'ownerPhone': newPhone,
              'ownerName': newName, // مزامنة الاسم أيضاً لضمان الدقة
            });
          }
          await batch.commit();
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color gold = const Color(0xFFC5A059);
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Text(isAr ? 'تعديل الملف الشخصي' : 'Edit Profile', style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(isAr ? 'المعلومات الأساسية' : 'Basic Info', Icons.person_outline, isDark ? gold : primaryColor),
              _buildField(_nameController, isAr ? 'الاسم بالكامل' : 'Full Name', Icons.person, isDark, primaryColor, gold),
              const SizedBox(height: 16),
              _buildField(_phoneController, isAr ? 'رقم الموبايل' : 'Mobile Number', Icons.phone_android, isDark, primaryColor, gold, keyboardType: TextInputType.phone),
              const SizedBox(height: 32),
              
              _buildSectionTitle(isAr ? 'وسائل التواصل الاجتماعي' : 'Social Media', Icons.share_outlined, isDark ? gold : primaryColor),
              
              _buildSocialField(_fbController, 'Facebook', 'https://facebook.com/yourprofile', Icons.facebook, Colors.blue, isDark, gold),
              const SizedBox(height: 16),
              _buildSocialField(_tgController, 'Telegram', 'https://t.me/username', Icons.telegram, Colors.lightBlue, isDark, gold),
              const SizedBox(height: 16),
              _buildSocialField(_waController, 'WhatsApp', '0123456789', null, Colors.green, isDark, gold, isWhatsApp: true),
              
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? gold : primaryColor,
                  foregroundColor: isDark ? Colors.black87 : Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(isAr ? 'حفظ التعديلات' : 'Save Changes', 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 20), 
    child: Row(children: [
      Icon(icon, color: color, size: 22), 
      const SizedBox(width: 12), 
      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))
    ])
  );

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool isDark, Color primary, Color gold, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: isDark ? gold : primary),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? gold : primary, width: 1.5)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent,
      ),
      validator: (v) => v!.isEmpty ? (MyApp.of(context).locale.languageCode == 'ar' ? 'مطلوب' : 'Required') : null,
    );
  }

  Widget _buildSocialField(TextEditingController controller, String label, String hint, IconData? icon, Color iconColor, bool isDark, Color gold, {bool isWhatsApp = false}) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade400),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: isWhatsApp 
            ? SvgPicture.asset('assets/WhatsApp.svg', width: 22, height: 22)
            : Icon(icon, color: isDark ? gold.withOpacity(0.8) : iconColor),
        ),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? gold : iconColor, width: 1.5)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent,
      ),
    );
  }
}
