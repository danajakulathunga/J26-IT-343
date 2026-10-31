import 'package:flutter/material.dart';
import 'package:bananaguard_ai/core/constants.dart';

class ScanFab extends StatelessWidget {
  final VoidCallback onPressed;

  const ScanFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryGreen.withOpacity(0.40),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.85),
            width: 3.5,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.camera_alt_rounded,
            color: AppConstants.accentYellow,
            size: 30,
          ),
        ),
      ),
    );
  }
}
