import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A custom animated loader with three bouncing utility dots (fire, water, bolt).
class CustomLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const CustomLoader({super.key, this.size = 48, this.color});

  @override
  State<CustomLoader> createState() => _CustomLoaderState();
}

class _CustomLoaderState extends State<CustomLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.size * 0.3;
    final icons = [
      (Icons.local_fire_department, Colors.orange),
      (Icons.water_drop, const Color(0xFF60A5FA)),
      (Icons.bolt, Colors.amber),
    ];

    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final delay = index * 0.15;
              final t = (_controller.value - delay) % 1.0;
              final bounce = math.sin(t * math.pi) * (widget.size * 0.25);
              final scale = 0.7 + 0.3 * math.sin(t * math.pi);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: dotSize * 0.35),
                child: Transform.translate(
                  offset: Offset(0, -bounce.abs()),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: widget.color ?? icons[index].$2.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(dotSize * 0.3),
                      ),
                      child: Icon(
                        icons[index].$1,
                        size: dotSize * 0.7,
                        color: widget.color ?? icons[index].$2,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Centered custom loader in a full-screen context (e.g. replacing CircularProgressIndicator).
class FullScreenLoader extends StatelessWidget {
  final String? message;

  const FullScreenLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CustomLoader(size: 48),
          if (message != null) ...[
            const SizedBox(height: 20),
            Text(
              message!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
