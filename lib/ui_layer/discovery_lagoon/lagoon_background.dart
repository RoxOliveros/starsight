import 'package:flutter/material.dart';

class LagoonBackground extends StatelessWidget {
  final Widget child;

  const LagoonBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFBEBC6),
        image: DecorationImage(
          image: AssetImage('assets/images/backgrounds/bg_game_lagoon.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
