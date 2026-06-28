import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _navigateToNext();
  }

  _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
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
      backgroundColor: Color(0xffFAF3ED),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/final_logo.jpeg',
                width: 250,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 50),
              // const CircularProgressIndicator(
              //   valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004040)),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
