import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet/home/login_view.dart';
import 'package:vet/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vet/home/home_screen.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      titleAr: 'متجر QPet المتكامل',
      titleEn: 'QPet All-in-One Shop',
      descAr: 'تسوق أفضل المنتجات والمستلزمات لأليفك بسهولة وأمان.',
      descEn: 'Shop the best products and supplies for your pet easily and safely.',
      image: 'assets/onboarding1.jpg',
    ),
    OnboardingItem(
      titleAr: 'عناية فائقة بأليفك',
      titleEn: 'Premium Pet Care',
      descAr: 'نوفر لك كل ما يحتاجه أليفك من أطعمة وإكسسوارات وعناية طبية.',
      descEn: 'We provide everything your pet needs from food, accessories, and medical care.',
      image: 'assets/onboarding2.jpg',
    ),
    OnboardingItem(
      titleAr: 'هوية رقمية ذكية',
      titleEn: 'Smart Digital Identity',
      descAr: 'أنشئ بروفايل رقمي لأليفك مع كود QR لسهولة التعرف عليه والوصول لبياناته.',
      descEn: 'Create a digital profile for your pet with a QR code for easy identification.',
      image: 'assets/onboarding3.png',
    ),
  ];

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      final user = FirebaseAuth.instance.currentUser;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => user != null ? const HomeScreen() : const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    const Color primaryGreen = Color(0xFF004040);
    const Color royalGold = Color(0xFFC5A059);
    const Color customGoldBg = Color(0xFFFAF3ED);

    return Scaffold(
      backgroundColor: customGoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // اللوجو في الأعلى
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Image.asset('assets/final_logo-Photoroom.png', height: 80),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        Container(
                          height: 320,
                          padding: const EdgeInsets.all(20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.asset(_items[index].image, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            isAr ? _items[index].titleAr : _items[index].titleEn,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 45),
                          child: Text(
                            isAr ? _items[index].descAr : _items[index].descEn,
                            style: TextStyle(
                              fontSize: 16, 
                              color: primaryGreen.withOpacity(0.7),
                              height: 1.5
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? royalGold : primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _items.length - 1) {
                          _finishOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royalGold,
                        foregroundColor: Colors.black87,
                        elevation: 4,
                        shadowColor: royalGold.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(
                        _currentPage == _items.length - 1
                            ? (isAr ? 'ابدأ الآن' : 'Get Started')
                            : (isAr ? 'التالي' : 'Next'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      isAr ? 'تخطي' : 'Skip',
                      style: TextStyle(color: primaryGreen.withOpacity(0.6), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingItem {
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final String image;

  OnboardingItem({
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    required this.image,
  });
}
