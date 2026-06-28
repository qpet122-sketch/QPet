import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PetLoading extends StatelessWidget {
  const PetLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const green = Color(0xff004040);
    const gold = Color(0xffC5A059);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Icon(
              Icons.pets,
              color: green,
              size: 75,
            )
                .animate(onPlay: (c) => c.repeat())
                .moveY(
              begin: 0,
              end: -12,
              duration: 500.ms,
              curve: Curves.easeOut,
            )
                .then()
                .moveY(
              begin: -12,
              end: 0,
              duration: 500.ms,
              curve: Curves.easeIn,
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                6,
                    (index) => Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.pets,
                    color: gold,
                    size: 18,
                  )
                      .animate(
                    delay: Duration(
                        milliseconds: index * 180),
                    onPlay: (c) => c.repeat(),
                  )
                      .fadeIn(duration: 350.ms)
                      .scale(begin: const Offset(.6, .6))
                      .then()
                      .fadeOut(duration: 350.ms),
                ),
              ),
            ),

            const SizedBox(height: 30),

            Text(
              "Preparing your pet...",
              style: TextStyle(
                color: isDark ? Colors.white : green,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Please wait a moment",
              style: TextStyle(
                color:
                isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}