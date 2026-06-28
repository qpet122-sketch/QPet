import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = const Color(0xFF004040);
    Color gold = const Color(0xFFC5A059);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: (isDark ? gold : primaryColor).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 80,
              color: iconColor ?? (isDark ? gold.withOpacity(0.5) : Colors.grey.shade400),
            ),
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds, curve: Curves.easeInOut)
          .shimmer(delay: 3.seconds, duration: 1.5.seconds),
          
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : primaryColor,
            ),
          ).animate().fadeIn(delay: 200.ms).moveY(begin: 10, end: 0),
          
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ).animate().fadeIn(delay: 400.ms),
          ),
        ],
      ),
    );
  }
}
