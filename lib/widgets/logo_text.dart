import 'package:flutter/material.dart';

class LogoText extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;

  const LogoText({
    super.key,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo.jpg',
          height: fontSize * 1.4,
          width: fontSize * 1.4,
          fit: BoxFit.contain,
        ),
        SizedBox(width: fontSize * 0.3),
        Text(
          'Real-Insta',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: const Color(0xFF262626),
          ),
        ),
      ],
    );
  }
}
