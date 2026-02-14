import 'package:flutter/material.dart';

import '../home_screen.dart';
import '../services/secure_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  late List<AnimationController> _slideControllers;
  late List<_SlideAnimations> _animations;

  static const _slides = [
    _SlideData(
      icon: Icons.speed,
      title: 'Choose Your Meter',
      description:
          'Select gas, water, or electricity — the app supports all three utility types with dedicated recognition.',
    ),
    _SlideData(
      icon: Icons.camera_alt_rounded,
      title: 'Snap a Photo',
      description:
          'Point your camera at the meter display and tap capture. AI reads the digits instantly.',
    ),
    _SlideData(
      icon: Icons.dashboard_rounded,
      title: 'Track & Calculate',
      description:
          'View all readings on your dashboard, set tariffs, and calculate your utility bills automatically.',
    ),
  ];

  static const _badges = [
    _Badge('Gas', Icons.local_fire_department, Color(0xFFEF4444)),
    _Badge('Water', Icons.water_drop, Color(0xFF3B82F6)),
    _Badge('Electricity', Icons.bolt, Color(0xFFF59E0B)),
  ];

  @override
  void initState() {
    super.initState();

    _slideControllers = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      ),
    );

    _animations = _slideControllers.map((c) => _SlideAnimations(c)).toList();

    _slideControllers[0].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _slideControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _slideControllers[page].forward(from: 0);
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await SecureStorage.setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4F46E5),
              Color(0xFF6366F1),
              Color(0xFF818CF8),
              Color(0xFF3B82F6),
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    final anims = _animations[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon
                          AnimatedBuilder(
                            animation: anims.controller,
                            builder: (context, _) => Opacity(
                              opacity: anims.iconOpacity.value,
                              child: Transform.scale(
                                scale: anims.iconScale.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.15),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    slide.icon,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Badges (slide 0 only)
                          if (index == 0) ...[
                            const SizedBox(height: 24),
                            AnimatedBuilder(
                              animation: anims.controller,
                              builder: (context, _) => Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_badges.length, (i) {
                                  final badge = _badges[i];
                                  final t = Interval(
                                    0.4 + i * 0.1,
                                    0.7 + i * 0.1,
                                    curve: Curves.easeOutBack,
                                  ).transform(anims.controller.value);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: Transform.scale(
                                      scale: t,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(badge.icon,
                                                size: 18, color: badge.color),
                                            const SizedBox(width: 6),
                                            Text(
                                              badge.label,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Title
                          SlideTransition(
                            position: anims.titleSlide,
                            child: FadeTransition(
                              opacity: anims.titleOpacity,
                              child: Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Description
                          SlideTransition(
                            position: anims.descSlide,
                            child: FadeTransition(
                              opacity: anims.descOpacity,
                              child: Text(
                                slide.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Page indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    );
                  }),
                ),
              ),

              // Button
              Padding(
                padding:
                    const EdgeInsets.only(left: 32, right: 32, bottom: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: Text(_currentPage < 2 ? 'Next' : 'Get Started'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideAnimations {
  final AnimationController controller;
  late final Animation<double> iconScale;
  late final Animation<double> iconOpacity;
  late final Animation<double> titleOpacity;
  late final Animation<Offset> titleSlide;
  late final Animation<double> descOpacity;
  late final Animation<Offset> descSlide;

  _SlideAnimations(this.controller) {
    iconScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    iconOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    descOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    descSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String description;

  const _SlideData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _Badge {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge(this.label, this.icon, this.color);
}
