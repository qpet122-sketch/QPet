import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // إضافة الاستيراد المفقود
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:vet/home/qr_scanner_view.dart';
import 'package:vet/home/home_screen.dart';
import 'package:vet/main.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // إضافة الاستيراد المفقود لـ kIsWeb

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
        String message = isAr ? 'حدث خطأ غير متوقع' : 'An unexpected error occurred';
        
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            message = isAr ? 'خطأ في البريد الإلكتروني أو كلمة المرور' : 'Invalid email or password.';
            break;
          case 'invalid-email':
            message = isAr ? 'تنسيق البريد الإلكتروني غير صحيح' : 'Invalid email format.';
            break;
          case 'user-disabled':
            message = isAr ? 'هذا الحساب تم تعطيله' : 'This account has been disabled.';
            break;
          case 'email-already-in-use':
            message = isAr ? 'هذا البريد مستخدم بالفعل، قم بتسجيل الدخول' : 'Email already in use. Try logging in.';
            break;
          case 'weak-password':
            message = isAr ? 'كلمة المرور ضعيفة جداً' : 'Password is too weak.';
            break;
          case 'channel-error':
            message = isAr ? 'يرجى التأكد من ملء جميع الحقول' : 'Please make sure all fields are filled.';
            break;
          case 'too-many-requests':
            message = isAr ? 'تم إرسال الكثير من الطلبات، حاول لاحقاً' : 'Too many requests. Try again later.';
            break;
        }

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'خطأ في الاتصال بالسيرفر' : 'Connection error'))
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle(bool isAr) async {
    setState(() => isLoading = true);
    try {
      // استخدام الـ Web Client ID الموحد لضمان التوافق
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? '582369930164-5noked6uv2mkrus9334akofqho03urmq.apps.googleusercontent.com' : null,
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // التحقق مما إذا كان المستخدم جديداً
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'name': user.displayName ?? user.email?.split('@').first ?? 'Guest',
            'email': user.email,
            'role': 'owner',
            'createdAt': FieldValue.serverTimestamp(),
            'petIds': []
          });
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (c) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'خطأ في تسجيل الدخول بجوجل' : 'Google Sign-In Error: $e'))
        );
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        ),
      ),
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
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return isAr ? "أدخل البريد الإلكتروني" : "Enter email";
                              }
                              final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (!emailRegExp.hasMatch(value.trim())) {
                                return isAr ? "بريد إلكتروني غير صالح" : "Invalid email";
                              }
                              return null;
                            },
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
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return isAr ? "أدخل كلمة المرور" : "Enter password";
                              }
                              if (value.length < 6) {
                                return isAr ? "كلمة المرور يجب أن تكون 6 أحرف على الأقل" : "Password must be at least 6 characters";
                              }
                              return null;
                            },
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
                          
                          // زر جوجل
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton.icon(
                              onPressed: isLoading ? null : () => _signInWithGoogle(isAr),
                              icon: SvgPicture.asset('assets/google_icon.svg', height: 24),
                              label: Text(
                                isAr ? 'دخول بواسطة جوجل' : 'Sign in with Google',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
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
