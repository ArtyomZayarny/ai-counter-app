import 'package:flutter/material.dart';

/// App logo: a stylized "Y" made of three utility icons arranged in a triangle
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gas icon (top)
          Positioned(
            top: size * 0.12,
            child: Icon(
              Icons.local_fire_department,
              size: size * 0.28,
              color: Colors.orange,
            ),
          ),
          // Water icon (bottom-left)
          Positioned(
            bottom: size * 0.14,
            left: size * 0.12,
            child: Icon(
              Icons.water_drop,
              size: size * 0.25,
              color: const Color(0xFF3B82F6),
            ),
          ),
          // Light icon (bottom-right)
          Positioned(
            bottom: size * 0.14,
            right: size * 0.12,
            child: Icon(
              Icons.bolt,
              size: size * 0.25,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }
}
