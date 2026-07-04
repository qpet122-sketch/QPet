import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vet/home/home_screen.dart';
import 'package:vet/home/login_view.dart';
import 'package:vet/home/onboarding_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _startFlow();
  }

  Future<void> _startFlow() async {
    // الانتظار لعرض اللوجو
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    // 1. التحقق من وجود تحديث إجباري
    bool needsUpdate = await _checkForUpdate();
    if (needsUpdate) return; // سيبقى في الـ Splash مع رسالة التحديث

    // 2. المتابعة الطبيعية للتطبيق
    _navigateToNext();
  }

  Future<bool> _checkForUpdate() async {
    try {
      // جلب بيانات الإصدار من Firebase
      final doc = await FirebaseFirestore.instance.collection('config').doc('contact_info').get();
      if (!doc.exists) return false;

      final latestVersion = doc.data()?['latestVersion'] ?? "1.0.0";
      final downloadUrl = doc.data()?['appDownloadUrl'] ?? "";

      // جلب إصدار التطبيق الحالي
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // مقارنة الإصدارات (بافتراض صيغة 1.0.0)
      if (_isVersionLower(currentVersion, latestVersion)) {
        _showUpdateDialog(latestVersion, downloadUrl);
        return true;
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
    return false;
  }

  bool _isVersionLower(String current, String latest) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      if (latestParts[i] > c) return true;
      if (latestParts[i] < c) return false;
    }
    return false;
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFFC5A059)),
            SizedBox(width: 10),
            Text("Update Available"),
          ],
        ),
        content: Text(
          "A new version ($version) of QPet is available. Please update to continue using the app.",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004040),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
  }

  _navigateToNext() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
    User? user = FirebaseAuth.instance.currentUser;
    Widget nextScreen = !onboardingDone ? const OnboardingView() : (user != null ? const HomeScreen() : const LoginView());
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFAF3ED),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/final_logo-Photoroom.png',
                width: 250,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
