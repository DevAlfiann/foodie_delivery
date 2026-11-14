import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

/// Modal / Overlay Full-Screen Animasi Kupon/Voucher Diterapkan
/// dengan efek background blur & radial glow yang sama persis seperti PaymentSuccessOverlay
class CouponAppliedOverlay extends StatefulWidget {
  final String voucherCode;
  final double discountPercent;
  final double discountAmount;

  const CouponAppliedOverlay({
    super.key,
    required this.voucherCode,
    required this.discountPercent,
    required this.discountAmount,
  });

  /// Helper statis untuk memanggil overlay animasi kupon dari halaman mana pun
  static Future<void> show(
    BuildContext context, {
    required String voucherCode,
    required double discountPercent,
    required double discountAmount,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return CouponAppliedOverlay(
            voucherCode: voucherCode,
            discountPercent: discountPercent,
            discountAmount: discountAmount,
          );
        },
      ),
    );
  }

  @override
  State<CouponAppliedOverlay> createState() => _CouponAppliedOverlayState();
}

class _CouponAppliedOverlayState extends State<CouponAppliedOverlay>
    with TickerProviderStateMixin {
  // 1. Controller untuk Intro (Blur 0 -> 15 & Background Fade In)
  late AnimationController _introController;
  late Animation<double> _blurAnimation;
  late Animation<double> _introFadeAnimation;

  // 2. Controller Animasi Lottie (One-Shot)
  late AnimationController _lottieController;

  // 3. Controller Text Scale & Fade-In
  late AnimationController _textController;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textScaleAnimation;

  // 4. Controller Outro (Blur 15 -> 0 & Fade Out)
  late AnimationController _outroController;
  late Animation<double> _outroFadeAnimation;

  Timer? _outroTimer;
  Timer? _fallbackTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    // 1. Setup Intro: Blur (0.0 ke 15.0) dan fade-in background (450ms)
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
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
        _triggerOutroAndDismiss();
      }
    });

    // 3. Setup Text Scale & Fade Animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _textScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutBack),
    );

    // 4. Setup Outro Fade-Out (350ms)
    _outroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
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

    // Fallback timer: jika animasi lottie memakan waktu lebih dari 2.5 detik
    _fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !_isDismissing) {
        _triggerOutroAndDismiss();
      }
    });
  }

  void _triggerOutroAndDismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _fallbackTimer?.cancel();

    // Beri jeda halus 200ms setelah animasi selesai
    _outroTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      _outroController.forward().then((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
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
        final currentOpacity =
            _introFadeAnimation.value * _outroFadeAnimation.value;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _triggerOutroAndDismiss,
            child: Stack(
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

                // 2. Lapisan warna gelap transparan bergradasi ke hijau mint gelap glowing di tengah (persis seperti payment success)
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

                // 3. Konten Tengah: Lottie apply coupon.json + Teks Kupon Berhasil Digunakan
                Center(
                  child: Opacity(
                    opacity: currentOpacity.clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animasi Lottie apply coupon.json (One-Shot) dengan Glow Aura di belakangnya
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFA3F69C).withValues(alpha: 0.38),
                                      blurRadius: 65,
                                      spreadRadius: 18,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF1B5E20).withValues(alpha: 0.5),
                                      blurRadius: 90,
                                      spreadRadius: 30,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 230,
                                height: 230,
                                child: Lottie.asset(
                                  'assets/animations/apply coupon.json',
                                  controller: _lottieController,
                                  fit: BoxFit.contain,
                                  repeat: false,
                                  onLoaded: (composition) {
                                    _lottieController.duration = composition.duration;
                                    _fallbackTimer?.cancel();
                                    _fallbackTimer = Timer(
                                      composition.duration + const Duration(milliseconds: 1400),
                                      () {
                                        if (mounted && !_isDismissing) {
                                          _triggerOutroAndDismiss();
                                        }
                                      },
                                    );
                                    _lottieController.forward(from: 0.0);
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    _triggerOutroAndDismiss();
                                    return const Center(
                                      child: Icon(
                                        Icons.discount_rounded,
                                        size: 90,
                                        color: Color(0xFFA3F69C),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Teks Kupon Diterapkan dengan efek scale dan fade-in
                          ScaleTransition(
                            scale: _textScaleAnimation,
                            child: FadeTransition(
                              opacity: _textFadeAnimation,
                              child: Column(
                                children: [
                                  Text(
                                    'Kupon Berhasil Dipakai!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.45),
                                          blurRadius: 18,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Badge Voucher & Diskon
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFA3F69C).withValues(alpha: 0.45),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFA3F69C).withValues(alpha: 0.15),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.confirmation_number_rounded,
                                          size: 16,
                                          color: Color(0xFFA3F69C),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${widget.voucherCode} • Hemat ${(widget.discountPercent * 100).toInt()}%',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFA3F69C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),
                                  Text(
                                    'Hemat \$${widget.discountAmount.toStringAsFixed(2)} pada pesanan ini',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.8),
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
          ),
        );
      },
    );
  }
}
