import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NoInternetView extends StatelessWidget {
  final VoidCallback onRetry;
  const NoInternetView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
    const Color primaryGreen = Color(0xFF004040);
    const Color gold = Color(0xFFC5A059);
    final bool isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAF3ED),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds),
                    const Icon(Icons.wifi_off_rounded, size: 80, color: primaryGreen),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  isAr ? "لا يوجد اتصال بالإنترنت" : "No Internet Connection",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : primaryGreen,
                  ),
                ).animate().fadeIn(duration: 600.ms).moveY(begin: 20, end: 0),
                const SizedBox(height: 16),
                Text(
                  isAr 
                    ? "يرجى التحقق من اتصال الشبكة الخاص بك والمحاولة مرة أخرى للوصول إلى كافة خدمات QPet."
                    : "Please check your network connection and try again to access all QPet services.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      isAr ? "إعادة المحاولة" : "Try Again",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(delay: 5.seconds, duration: 2.seconds),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
