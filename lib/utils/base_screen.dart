import 'package:flutter/material.dart';
import '../utils/colors.dart';
class BaseScreen extends StatelessWidget {
  final Widget child;
  final bool hasIllustrations; // Flag for background drawings

  const BaseScreen({Key? key, required this.child, this.hasIllustrations = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Conditional Background: Image if `hasIllustrations` is true, plain color otherwise
          Positioned.fill(
            child: hasIllustrations
                ? Image.asset(
              'assets/images/bg_with_drawings.png',
              fit: BoxFit.cover,
            )
                : Container(color: AppColors.bgColor),
          ),

          // Page Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
