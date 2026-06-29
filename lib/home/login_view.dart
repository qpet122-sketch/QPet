import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vet/home/qr_scanner_view.dart';
import 'package:vet/home/home_screen.dart';
import 'package:vet/main.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isLogin = true;
  bool _obscurePassword = true;
  String selectedRole = 'owner';

  Future<void> _submit(bool isAr) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim()
        );
      } else {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim()
        );
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': selectedRole,
          'createdAt': FieldValue.serverTimestamp()
        });
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => const HomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? (isAr ? 'خطأ' : 'Error'))));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _forgotPassword(bool isAr) async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'برجاء إدخال البريد الإلكتروني أولاً' : 'Please enter your email first'))
      );
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr 
              ? 'تم إرسال الرابط لبريدك، تأكد من فحص البريد الوارد والرسائل المزعجة (Spam)' 
              : 'Reset link sent! Please check your inbox and Spam folder'), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;

    final screenSize = MediaQuery.of(context).size;
    final double logoSize = screenSize.height * 0.22; // حجم اللوجو 22% من طول الشاشة

    Color primaryColor = const Color(0xFF004040);
    Color gold = const Color(0xFFC5A059);
    Color customGoldBg = const Color(0xFFFAF3ED);

    Color actionColor = isDark ? gold : primaryColor;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : customGoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    'assets/final_logo-Photoroom.png',
                    width: logoSize, 
                    height: logoSize, 
                    fit: BoxFit.contain
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                const SizedBox(height: 20),

                Card(
                  color: cardBg,
                  elevation: isDark ? 0 : 4,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: isDark ? BorderSide(color: gold.withOpacity(0.1)) : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLogin ? (isAr ? 'تسجيل الدخول' : 'Login') : (isAr ? 'إنشاء حساب' : 'Sign Up'),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: actionColor)
                          ),
                          const SizedBox(height: 32),
                          if (!isLogin) ...[
                            TextFormField(
                              controller: _nameController,
                              style: TextStyle(color: textColor),
                              mouseCursor: SystemMouseCursors.text, // إضافة المؤشر للويب
                              decoration: InputDecoration(
                                labelText: isAr ? 'الاسم الكامل' : 'Full Name',
                                labelStyle: const TextStyle(color: Colors.grey),
                                prefixIcon: Icon(Icons.person, color: actionColor),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: actionColor, width: 1.5)),
                              ),
                              validator: (v) => v!.isEmpty ? (isAr ? 'برجاء إدخال الاسم' : 'Please enter your name') : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            style: TextStyle(color: textColor),
                            mouseCursor: SystemMouseCursors.text, // إضافة المؤشر للويب
                            decoration: InputDecoration(
                              labelText: isAr ? 'البريد الإلكتروني' : 'Email',
                              labelStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: Icon(Icons.email, color: actionColor),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: actionColor, width: 1.5)),
                            ),
                            validator: (v) => v!.isEmpty || !v.contains('@') ? (isAr ? 'بريد غير صالح' : 'Invalid Email') : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: textColor),
                            mouseCursor: SystemMouseCursors.text, // إضافة المؤشر للويب
                            decoration: InputDecoration(
                              labelText: isAr ? 'كلمة المرور' : 'Password',
                              labelStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: Icon(Icons.lock, color: actionColor),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: actionColor, width: 1.5)),
                            ),
                            validator: (v) => v!.length < 6 ? (isAr ? 'كلمة المرور قصيرة' : 'Password too short') : null,
                          ),
                          if (isLogin)
                            Align(
                              alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _forgotPassword(isAr),
                                child: Text(
                                  isAr ? 'نسيت كلمة المرور؟' : 'Forgot Password?',
                                  style: TextStyle(color: actionColor, fontSize: 13),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : () => _submit(isAr),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: actionColor,
                                foregroundColor: isDark ? Colors.black87 : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                              ),
                              child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? (isAr ? 'دخول' : 'Login') : (isAr ? 'تسجيل' : 'Register'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => setState(() => isLogin = !isLogin),
                            child: Text(
                              isLogin ? (isAr ? 'ليس لديك حساب؟ سجل الآن' : 'No account? Sign Up') : (isAr ? 'لديك حساب بالفعل؟ سجل دخولك' : 'Have an account? Login'),
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                            )
                          ),
                          const Divider(height: 40, color: Colors.white10),
                          TextButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const QrScannerView())),
                            icon: Icon(Icons.qr_code_scanner, color: gold),
                            label: Text(isAr ? 'دخول سريع كزائر' : 'Guest Quick Access', style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
