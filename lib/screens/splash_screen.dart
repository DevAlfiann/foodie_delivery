import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../models/order_state.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _lottieAnimController;
  late AnimationController _textEntranceController;
  late AnimationController _textExitController;

  late Animation<Offset> _titleEntranceSlide;
  late Animation<double> _titleEntranceFade;
  late Animation<double> _titleEntranceScale;

  late Animation<Offset> _subEntranceSlide;
  late Animation<double> _subEntranceFade;
  late Animation<double> _subEntranceScale;

  late Animation<Offset> _textExitSlide;
  late Animation<double> _textExitFade;
  late Animation<double> _textExitScale;

  Timer? _failsafeTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _lottieAnimController = AnimationController(vsync: this);

    // Controller animasi masuk teks (Foodie Delivery & Pesan Lezat)
    _textEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Animasi judul: Masuk meluncur ke atas dengan scale & fade halus
    _titleEntranceSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.45),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textEntranceController,
      curve: const Interval(0.05, 0.85, curve: Curves.easeOutBack),
    ));

    _titleEntranceFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textEntranceController,
      curve: const Interval(0.05, 0.70, curve: Curves.easeOutCubic),
    ));

    _titleEntranceScale = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textEntranceController,
      curve: const Interval(0.05, 0.85, curve: Curves.easeOutBack),
    ));

    // Animasi subjudul ("Pesan Lezat, Sampai Cepat"): Masuk beriringan (staggered)
    _subEntranceSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.55),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textEntranceController,
      curve: const Interval(0.28, 0.98, curve: Curves.easeOutBack),
    ));

    _subEntranceFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textEntranceController,
      curve: const Interval(0.28, 0.88, curve: Curves.easeOutCubic),
    ));

    _subEntranceScale = Tween<double>(
      begin: 0.90,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textEntranceController,
      curve: const Interval(0.28, 0.98, curve: Curves.easeOutBack),
    ));

    // Controller animasi keluar teks (Foodie Delivery & Pesan Lezat)
    _textExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );

    _textExitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.32),
    ).animate(CurvedAnimation(
      parent: _textExitController,
      curve: Curves.easeInOutCubic,
    ));

    _textExitFade = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textExitController,
      curve: Curves.easeInCubic,
    ));

    _textExitScale = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _textExitController,
      curve: Curves.easeInCubic,
    ));

    // Mulai animasi masuk teks segera
    _textEntranceController.forward();

    // Failsafe timer (6 detik): Jika file JSON rusak atau gagal dimuat,
    // aplikasi tidak macet di splash screen dan tetap berpindah halaman.
    _failsafeTimer = Timer(const Duration(milliseconds: 6000), () async {
      if (mounted) {
        await _textExitController.forward();
      }
      _navigateToNextScreen();
    });
  }

  void _navigateToNextScreen() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    _failsafeTimer?.cancel();

    final Widget targetScreen = OrderState.instance.isLoggedIn
        ? const HomeScreen()
        : const LoginScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _failsafeTimer?.cancel();
    _lottieAnimController.dispose();
    _textEntranceController.dispose();
    _textExitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background solid white menyatu sempurna
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
            ),
          ),

          // Konten Utama Splash & Animasi Lottie
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Masking radial halus agar tepi animasi/jalan memudar ke putih (tanpa batas kotak)
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return RadialGradient(
                        center: Alignment.center,
                        radius: 0.70,
                        colors: const [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Lottie.asset(
                      'assets/animations/delivery.json',
                      controller: _lottieAnimController,
                      width: 280,
                      height: 280,
                      fit: BoxFit.contain,
                      onLoaded: (composition) {
                        // 1. Batalkan failsafe timer karena aset berhasil dimuat
                        _failsafeTimer?.cancel();

                        // 2. Set durasi controller tepat sesuai durasi bawaan file animasi
                        _lottieAnimController.duration = composition.duration;

                        // 3. Putar penuh dari frame pertama hingga akhir
                        _lottieAnimController.forward().then((_) async {
                          // Mainkan animasi keluar smooth untuk teks Foodie Delivery & Pesan Lezat
                          if (mounted) {
                            await _textExitController.forward();
                          }
                          // Jeda singkat (160ms) agar transisi sangat nyaman
                          await Future.delayed(const Duration(milliseconds: 160));
                          _navigateToNextScreen();
                        });
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.18),
                                blurRadius: 28,
                                spreadRadius: 4,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            size: 54,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Animasi Keluar Bersama (Foodie Delivery & Pesan Lezat)
                  SlideTransition(
                    position: _textExitSlide,
                    child: FadeTransition(
                      opacity: _textExitFade,
                      child: ScaleTransition(
                        scale: _textExitScale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Judul Brand dengan Animasi Masuk Halus
                            SlideTransition(
                              position: _titleEntranceSlide,
                              child: FadeTransition(
                                opacity: _titleEntranceFade,
                                child: ScaleTransition(
                                  scale: _titleEntranceScale,
                                  child: Text(
                                    'Foodie Delivery',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Subjudul Tagline dengan Animasi Masuk Halus
                            SlideTransition(
                              position: _subEntranceSlide,
                              child: FadeTransition(
                                opacity: _subEntranceFade,
                                child: ScaleTransition(
                                  scale: _subEntranceScale,
                                  child: Text(
                                    'Pesan Lezat, Sampai Cepat',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Indikator Loading
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Menyiapkan menu terbaik...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
