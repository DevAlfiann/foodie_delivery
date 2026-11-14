import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../screens/digital_receipt_screen.dart';

/// Modal / Overlay Full-Screen Transisi Payment Success yang sangat smooth dan elegan
class PaymentSuccessOverlay extends StatefulWidget {
  final String orderId;
  final double totalAmount;

  const PaymentSuccessOverlay({
    super.key,
    required this.orderId,
    required this.totalAmount,
  });

  /// Helper statis untuk memanggil overlay transisi dari mana saja (Cart, QRIS, dsb.)
  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required double totalAmount,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return PaymentSuccessOverlay(
            orderId: orderId,
            totalAmount: totalAmount,
          );
        },
      ),
    );
  }

  @override
  State<PaymentSuccessOverlay> createState() => _PaymentSuccessOverlayState();
}

class _PaymentSuccessOverlayState extends State<PaymentSuccessOverlay>
    with TickerProviderStateMixin {
  // 1. Controller untuk Intro (Blur 0 -> 15 & Background Fade In)
  late AnimationController _introController;
  late Animation<double> _blurAnimation;
  late Animation<double> _introFadeAnimation;

  // 2. Controller Animasi Lottie (One-Shot, tidak looping)
  late AnimationController _lottieController;

  // 3. Controller Text Scale & Fade-In
  late AnimationController _textController;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textScaleAnimation;

  // 4. Controller Outro (Blur 15 -> 0 & Fade Out 400ms)
  late AnimationController _outroController;
  late Animation<double> _outroFadeAnimation;

  Timer? _outroTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Setup Intro: Blur (0.0 ke 15.0) dan fade-in background
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _blurAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );

    _introFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOut),
    );

    // 2. Setup Lottie Controller (One-Shot)
    _lottieController = AnimationController(vsync: this);
    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerOutroAndNavigate();
      }
    });

    // 3. Setup Text Scale & Fade Animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _textScaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutBack),
    );

    // 4. Setup Outro Fade-Out (400ms)
    _outroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _outroFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _outroController, curve: Curves.easeInOut),
    );

    // Jalankan Intro
    _introController.forward().then((_) {
      if (mounted) {
        _textController.forward();
      }
    });
  }

  void _triggerOutroAndNavigate() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Beri jeda singkat 150ms agar pengguna menikmati frame akhir Lottie
    _outroTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      // 1. Jalankan outro fade out sinkron (400ms)
      _outroController.forward();

      // 2. Bersamaan navigasikan langsung ke halaman ReceiptScreen dengan Slide Up + Fade In
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) =>
              DigitalReceiptScreen(
            orderId: widget.orderId,
            totalAmount: widget.totalAmount,
            initialCelebration: false,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.15),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _outroTimer?.cancel();
    _introController.dispose();
    _lottieController.dispose();
    _textController.dispose();
    _outroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _outroController]),
      builder: (context, child) {
        final currentBlur = _blurAnimation.value * _outroFadeAnimation.value;
        final currentOpacity = _introFadeAnimation.value * _outroFadeAnimation.value;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. BackdropFilter dengan efek blur (animasi 0.0 -> 15.0 -> 0.0)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: currentBlur.clamp(0.0, 15.0),
                    sigmaY: currentBlur.clamp(0.0, 15.0),
                  ),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),

              // 2. Lapisan warna gelap transparan bergradasi ke hijau mint gelap glowing di tengah
              Positioned.fill(
                child: Opacity(
                  opacity: currentOpacity.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.95,
                        colors: [
                          // Hijau mint gelap glowing di tengah
                          const Color(0xFF0F3A24).withValues(alpha: 0.88),
                          // Lapisan gelap transparan halus di luar
                          Colors.black.withValues(alpha: 0.45),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Konten Tengah: Lottie One-Shot + Teks 'Pembayaran Berhasil!'
              Center(
                child: Opacity(
                  opacity: currentOpacity.clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animasi Lottie Payment Successful (One-Shot, tidak looping)
                        SizedBox(
                          width: 320,
                          height: 210,
                          child: Lottie.asset(
                            'assets/animations/payment sucessful.json',
                            controller: _lottieController,
                            fit: BoxFit.contain,
                            repeat: false,
                            onLoaded: (composition) {
                              _lottieController.duration = composition.duration;
                              // Putar 1 siklus penuh dari awal
                              _lottieController.forward(from: 0.0);
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Lottie.asset(
                                'assets/animations/payment_success.json',
                                controller: _lottieController,
                                fit: BoxFit.contain,
                                repeat: false,
                                onLoaded: (composition) {
                                  _lottieController.duration = composition.duration;
                                  _lottieController.forward(from: 0.0);
                                },
                                errorBuilder: (ctx, err, st) {
                                  _triggerOutroAndNavigate();
                                  return const Center(
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 90,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Teks 'Pembayaran Berhasil!' dengan efek scale dan fade-in
                        ScaleTransition(
                          scale: _textScaleAnimation,
                          child: FadeTransition(
                            opacity: _textFadeAnimation,
                            child: Column(
                              children: [
                                Text(
                                  'Pembayaran Berhasil!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    shadows: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFA3F69C).withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '\$${widget.totalAmount.toStringAsFixed(2)} • ID: ${widget.orderId}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFA3F69C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
