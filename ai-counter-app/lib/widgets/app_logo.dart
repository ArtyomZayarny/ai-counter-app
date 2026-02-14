import 'package:flutter/material.dart';

/// App logo: three utility icons, each in a colored circle, arranged in a triangle
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, required this.size});

  Widget _iconCircle({
    required IconData icon,
    required Color color,
    required double circleSize,
  }) {
    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: circleSize * 0.55,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleSize = size * 0.38;

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
            top: size * 0.08,
            child: _iconCircle(
              icon: Icons.local_fire_department,
              color: Colors.orange,
              circleSize: circleSize,
            ),
          ),
          // Water icon (bottom-left)
          Positioned(
            bottom: size * 0.08,
            left: size * 0.08,
            child: _iconCircle(
              icon: Icons.water_drop,
              color: const Color(0xFF3B82F6),
              circleSize: circleSize,
            ),
          ),
          // Electricity icon (bottom-right)
          Positioned(
            bottom: size * 0.08,
            right: size * 0.08,
            child: _iconCircle(
              icon: Icons.bolt,
              color: Colors.amber,
              circleSize: circleSize,
            ),
          ),
        ],
      ),
    );
  }
}
