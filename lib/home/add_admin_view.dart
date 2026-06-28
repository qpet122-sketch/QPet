import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vet/main.dart';

class AddAdminView extends StatefulWidget {
  const AddAdminView({super.key});

  @override
  State<AddAdminView> createState() => _AddAdminViewState();
}

class _AddAdminViewState extends State<AddAdminView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  Future<void> _createAdmin(bool isAr) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      // إنشاء نسخة ثانوية من Firebase لإنشاء الحساب الجديد دون تسجيل خروج الادمين الحالي
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // حفظ بيانات الادمين الجديد في Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'doctor',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // مسح النسخة الثانوية بعد الانتهاء
      await secondaryApp.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تم إضافة الادمين بنجاح' : 'Admin added successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color goldColor = const Color(0xFFC5A059);
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Text(isAr ? 'إضافة ادمين جديد' : 'Add New Admin', style: TextStyle(color: isDark ? Colors.white : Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Icon(Icons.admin_panel_settings, size: 80, color: goldColor),
              const SizedBox(height: 32),
              _buildTextField(
                _nameController, 
                isAr ? 'اسم الادمين' : 'Admin Name', 
                Icons.person, 
                isDark, 
                primaryColor, 
                goldColor,
                (v) => v!.isEmpty ? (isAr ? 'مطلوب' : 'Required') : null
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _emailController, 
                isAr ? 'البريد الإلكتروني' : 'Email', 
                Icons.email, 
                isDark, 
                primaryColor, 
                goldColor,
                (v) => v!.isEmpty || !v.contains('@') ? (isAr ? 'بريد غير صالح' : 'Invalid Email') : null
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isAr ? 'كلمة المرور' : 'Password',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.lock, color: isDark ? goldColor : primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? goldColor : primaryColor)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.length < 6 ? (isAr ? 'كلمة المرور قصيرة' : 'Too short') : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _createAdmin(isAr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? goldColor : primaryColor,
                    foregroundColor: isDark ? Colors.black87 : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(isAr ? 'إنشاء حساب ادمين' : 'Create Admin Account', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isDark, Color primary, Color gold, String? Function(String?)? validator) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: isDark ? gold : primary),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? gold : primary)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }
}
