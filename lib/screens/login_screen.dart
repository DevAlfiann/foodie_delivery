import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_state.dart';
import '../theme/app_colors.dart';
import '../widgets/capsule_toast.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberMe = true;
  bool _isLoading = false;
  bool _isSuccess = false;

  // State iOS Auth Segmented Tab (0: Masuk / Log In, 1: Daftar / Sign Up)
  int _authTabIndex = 0;

  // State interaksi smooth Apple & Google Login
  bool _isApplePressed = false;
  bool _isGooglePressed = false;
  bool _isAppleLoading = false;
  bool _isGoogleLoading = false;

  late AnimationController _pulseController;
  late AnimationController _driverEntranceController;
  late Animation<Offset> _driverEntranceSlide;
  late Animation<double> _driverEntranceFade;

  late AnimationController _driverRevController;
  late Animation<double> _driverRevAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Animasi driver meluncur dari kanan tak terlihat ke posisi biasanya
    _driverEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _driverEntranceSlide = Tween<Offset>(
      begin: const Offset(1.6, 0.0), // Tak terlihat dari sisi kanan
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _driverEntranceController,
      curve: Curves.easeOutCubic,
    ));

    _driverEntranceFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _driverEntranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    // Animasi bergerak seperti motor di-gas dan di-angkat (wheelie lift) berulang secara smooth
    _driverRevController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _driverRevAnimation = CurvedAnimation(
      parent: _driverRevController,
      curve: Curves.easeInOutSine,
    );

    // Jalankan entrance, setelah selesai mulai animasi motor di-gas & di-angkat terus-menerus
    _driverEntranceController.forward().then((_) {
      if (mounted) {
        _driverRevController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _pulseController.dispose();
    _driverEntranceController.dispose();
    _driverRevController.dispose();
    super.dispose();
  }

  void _triggerSocialLogin(String provider) async {
    if (_isLoading || _isAppleLoading || _isGoogleLoading) return;
    setState(() {
      if (provider == 'Apple') {
        _isAppleLoading = true;
      } else {
        _isGoogleLoading = true;
      }
    });

    // Simulasi autentikasi SSO iOS
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;

    setState(() {
      _isAppleLoading = false;
      _isGoogleLoading = false;
    });

    CapsuleToast.show(
      context,
      icon: provider == 'Apple' ? Icons.apple : Icons.g_mobiledata_rounded,
      title: 'Login Berhasil!',
      subtitle: 'Terhubung melalui $provider ID',
      duration: const Duration(seconds: 4),
    );

    // Simpan status sesi login
    OrderState.instance.isLoggedIn = true;

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _triggerLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _isSuccess = false;
      });

      // Simulate authentication
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;

      setState(() {
        _isSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isSuccess = false;
      });

      CapsuleToast.show(
        context,
        icon: Icons.verified_user_rounded,
        title: _authTabIndex == 0 ? 'Login Berhasil!' : 'Pendaftaran Berhasil!',
        subtitle: _authTabIndex == 0
            ? 'Selamat datang kembali di Foodie Delivery'
            : 'Akun Anda telah aktif, selamat menikmati menu terbaik',
        duration: const Duration(seconds: 5),
      );

      // Simpan status login di sesi
      OrderState.instance.isLoggedIn = true;

      // Navigate to Home Screen
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHeroHeader(context),
              _buildInteractionCard(context),
              _buildFooter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      padding: EdgeInsets.only(
        top: topPadding + 14,
        left: 20,
        right: 20,
        bottom: 52,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient organic background circle blur
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            left: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryFixed.withValues(alpha: 0.12),
              ),
            ),
          ),

          // Main Header Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top status badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.38),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.eco, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'FAST • FRESH • ECO',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '18 min avg',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title and Hero Image Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Text Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/foto.png',
                              width: 38,
                              height: 38,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Image.asset(
                                'assets/images/logo.png',
                                width: 38,
                                height: 38,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Foodie',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hot meals, right at your door.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cravings satisfied in taps.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Rider Photo with Entrance Animation & Continuous Smooth Motorcycle Rev/Lift Animation
                  AnimatedBuilder(
                    animation: Listenable.merge([_driverEntranceController, _driverRevController]),
                    builder: (context, child) {
                      final rev = _driverRevAnimation.value;
                      // Animasi motor di-gas & di-angkat (wheelie lift):
                      // Rotasi naik di roda belakang (-0.11 rad ≈ -6.3 derajat)
                      final tiltAngle = -0.11 * rev;
                      // Roda depan dan motor terangkat ke atas (-8.0 px)
                      final liftY = -8.0 * rev;
                      // Sentakan akselerasi motor ke depan saat di-gas (-3.5 px)
                      final surgeX = -3.5 * rev;

                      return SlideTransition(
                        position: _driverEntranceSlide,
                        child: FadeTransition(
                          opacity: _driverEntranceFade,
                          child: Transform.translate(
                            offset: Offset(surgeX, liftY),
                            child: Transform(
                              alignment: Alignment.bottomRight, // Tumpuan roda belakang
                              transform: Matrix4.rotationZ(tiltAngle),
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 115,
                      height: 115,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/rider.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/rider (2).png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  child: const Center(
                                    child: Icon(
                                      Icons.delivery_dining,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionCard(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.93),
                    Colors.white.withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFF161C27).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // iOS Cupertino Segmented Tab Bar (Masuk / Daftar)
                    _buildIosSegmentedAuthTab(),

                    const SizedBox(height: 20),

                    // Title & Food Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _authTabIndex == 0 ? 'Selamat Datang' : 'Buat Akun Baru',
                                  key: ValueKey<int>(_authTabIndex),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.onSurface,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _authTabIndex == 0
                                    ? 'Masuk untuk nikmati kuliner favoritmu'
                                    : 'Daftar sekarang & nikmati promo lezat',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryContainer.withValues(alpha: 0.20),
                              width: 1.2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lunch_dining,
                              color: AppColors.primaryContainer,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Full Name input jika tab "Daftar" aktif
                    if (_authTabIndex == 1) ...[
                      Text(
                        'Nama Lengkap',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.onSurface,
                          fontSize: 14,
                        ),
                        decoration: _buildIosInputDecoration(
                          hint: 'Alex Pratama',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (val) {
                          if (_authTabIndex == 1 && (val == null || val.trim().isEmpty)) {
                            return 'Silakan masukkan nama lengkap Anda';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Identifier input (Email or phone)
                    Text(
                      'Email atau Nomor Ponsel',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurface,
                        fontSize: 14,
                      ),
                      decoration: _buildIosInputDecoration(
                        hint: 'alex@example.com',
                        icon: Icons.alternate_email_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Silakan masukkan email atau no. ponsel';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password Input
                    Text(
                      'Kata Sandi',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurface,
                        fontSize: 14,
                      ),
                      decoration: _buildIosInputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: AppColors.outline,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Silakan masukkan kata sandi Anda';
                        }
                        if (val.length < 6) {
                          return 'Kata sandi minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Controls: Remember me & Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _rememberMe = !_rememberMe;
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _rememberMe
                                      ? AppColors.primaryContainer
                                      : AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: _rememberMe
                                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ingat saya',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_authTabIndex == 0)
                          TextButton(
                            onPressed: () {
                              CapsuleToast.show(
                                context,
                                message: 'Tautan reset sandi telah dikirim ke email',
                                icon: Icons.mail_outline_rounded,
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Lupa Sandi?',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primaryContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Primary CTA Log In / Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _triggerLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: AppColors.primaryContainer.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _isSuccess
                                      ? const Icon(Icons.check_circle, color: Colors.white, size: 20)
                                      : const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isSuccess ? 'Siap Menyajikan!' : 'Memeriksa Dapur...',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _authTabIndex == 0 ? 'Masuk Sekarang' : 'Daftar Akun Baru',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Divider: Or continue with
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: AppColors.surfaceContainerHighest, thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ATAU MASUK DENGAN',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.outline,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: AppColors.surfaceContainerHighest, thickness: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Social Sign-in Buttons: Apple & Google with Smooth Interactive Physics
                    Row(
                      children: [
                        // Apple SSO Button (Smooth iOS Native Style)
                        Expanded(
                          child: _buildSmoothSocialButton(
                            provider: 'Apple',
                            title: 'Apple',
                            icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                            isPressed: _isApplePressed,
                            isLoading: _isAppleLoading,
                            backgroundColor: const Color(0xFF000000),
                            textColor: Colors.white,
                            onPressedDown: () => setState(() => _isApplePressed = true),
                            onPressedUp: () => setState(() => _isApplePressed = false),
                            onTap: () => _triggerSocialLogin('Apple'),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Google SSO Button (Smooth iOS Frosted Glass Style)
                        Expanded(
                          child: _buildSmoothSocialButton(
                            provider: 'Google',
                            title: 'Google',
                            icon: _buildGoogleIcon(),
                            isPressed: _isGooglePressed,
                            isLoading: _isGoogleLoading,
                            backgroundColor: Colors.white,
                            textColor: AppColors.onSurface,
                            borderColor: const Color(0xFFE2E8F0),
                            onPressedDown: () => setState(() => _isGooglePressed = true),
                            onPressedUp: () => setState(() => _isGooglePressed = false),
                            onTap: () => _triggerSocialLogin('Google'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Segmented Control iOS (Masuk / Daftar) dengan Slider Halus
  Widget _buildIosSegmentedAuthTab() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Sliding Liquid Glass Pill Indicator
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: _authTabIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tab Items Row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_authTabIndex != 0) {
                      setState(() => _authTabIndex = 0);
                    }
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.plusJakartaSans(
                        color: _authTabIndex == 0 ? AppColors.onSurface : AppColors.onSurfaceVariant,
                        fontSize: 13.5,
                        fontWeight: _authTabIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                      ),
                      child: const Text('Masuk'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_authTabIndex != 1) {
                      setState(() => _authTabIndex = 1);
                    }
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.plusJakartaSans(
                        color: _authTabIndex == 1 ? AppColors.onSurface : AppColors.onSurfaceVariant,
                        fontSize: 13.5,
                        fontWeight: _authTabIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                      ),
                      child: const Text('Daftar Akun'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Input Decoration bergaya iOS Glassmorphic
  InputDecoration _buildIosInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.outlineVariant,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: AppColors.outline,
        size: 20,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryContainer, width: 2.0),
      ),
    );
  }

  // Tombol Social Login iOS dengan Efek Pegas Halus (Spring Physics)
  Widget _buildSmoothSocialButton({
    required String provider,
    required String title,
    required Widget icon,
    required bool isPressed,
    required bool isLoading,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onPressedDown,
    required VoidCallback onPressedUp,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressedDown(),
      onTapUp: (_) {
        onPressedUp();
        onTap();
      },
      onTapCancel: () => onPressedUp(),
      child: AnimatedScale(
        scale: isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor ?? Colors.transparent,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: provider == 'Apple' ? 0.14 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        provider == 'Apple' ? Colors.white : AppColors.primary,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: Text(
        'G',
        style: GoogleFonts.poppins(
          color: const Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 19,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Sign Up prompt
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _authTabIndex == 0 ? "Belum memiliki akun?" : "Sudah memiliki akun?",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() {
                  _authTabIndex = _authTabIndex == 0 ? 1 : 0;
                });
              },
              child: Text(
                _authTabIndex == 0 ? 'Daftar Sekarang' : 'Masuk',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primaryContainer,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Contactless drop-off & real-time GPS tracking
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Pengantaran higienis & pelacakan GPS real-time',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.outline,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
