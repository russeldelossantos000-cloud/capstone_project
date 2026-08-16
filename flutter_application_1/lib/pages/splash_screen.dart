import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoFade;
  late Animation<double>   _textFade;
  late Animation<Offset>   _textSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.55, curve: Curves.elasticOut)));

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.35, curve: Curves.easeOut)));

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.85, curve: Curves.easeOut)));

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.85, curve: Curves.easeOut)));

    _ctrl.forward().then((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            loggedIn ? const HomePage() : const LoginPage(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        // Background grid lines
        CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),

        // Radial glow
        Center(child: Container(
          width: 320, height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppColors.primary.withOpacity(0.12),
              Colors.transparent,
            ]),
          ),
        )),

        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo
         ScaleTransition(
  scale: _logoScale,
  child: FadeTransition(
    opacity: _logoFade,
    child: Container(
      width: 120, // Match your image width
      height: 120, // Match your image height
      padding: const EdgeInsets.all(0), // Gap between image and border
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary, // Your border color
          width: 1.0,               // Border thickness
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.jpg',
          fit: BoxFit.cover,
        ),
      ),
    ),
  ),
),
          const SizedBox(height: 28),

          // Brand text
          FadeTransition(
            opacity: _textFade,
            child: SlideTransition(
              position: _textSlide,
              child: Column(children: [
                const Text("DI2'S MICOS",
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 5)),
                const SizedBox(height: 4),
                const Text("BIKESHOP",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 8)),
                const SizedBox(height: 40),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      color: AppColors.primary.withOpacity(0.6),
                      strokeWidth: 2),
                ),
              ]),
            ),
          ),
        ])),

        // Version tag bottom
        Positioned(
          bottom: 32, left: 0, right: 0,
          child: FadeTransition(
            opacity: _textFade,
            child: const Text("v1.0.0",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 2)),
          ),
        ),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C1C1C)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
