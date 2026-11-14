import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Frame iPhone 13 Midnight/Black untuk membungkus aplikasi saat dijalankan
/// di Web / Chrome atau Desktop agar tidak melebar dan tetap menggunakan
/// rasio asli iPhone 13 (390 x 844 pt).
class IPhone13Frame extends StatefulWidget {
  final Widget child;

  const IPhone13Frame({
    super.key,
    required this.child,
  });

  @override
  State<IPhone13Frame> createState() => _IPhone13FrameState();
}

class _IPhone13FrameState extends State<IPhone13Frame> {
  late Timer _clockTimer;
  String _currentTime = '09:41';
  bool _forceFullscreen = false;

  // Ukuran standar layar iPhone 13 (logical pixels)
  static const double _screenWidth = 390.0;
  static const double _screenHeight = 844.0;
  static const double _bezelThickness = 12.0;
  static const double _deviceWidth = _screenWidth + (_bezelThickness * 2); // 414.0
  static const double _deviceHeight = _screenHeight + (_bezelThickness * 2); // 868.0
  static const double _outerCornerRadius = 52.0;
  static const double _screenCornerRadius = 42.0;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) => _updateTime());
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _currentTime = '$hour:$minute';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Jika layar asli pengguna sudah kecil (mobile browser < 480px)
        // atau jika pengguna memilih mode fullscreen, tampilkan langsung tanpa frame
        final isMobileViewport = constraints.maxWidth < 480;

        if (isMobileViewport || _forceFullscreen) {
          return widget.child;
        }

        // Tampilan Desktop / Web Browser dengan iPhone 13 Frame realistis
        return Scaffold(
          backgroundColor: const Color(0xFF0B0F17),
          body: Stack(
            children: [
              // 1. Ambient Studio Backdrop (Gradient & Glow halus)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.1,
                      colors: [
                        Color(0xFF1E2638),
                        Color(0xFF0A0D14),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Lingkaran Ambient Light di belakang bodi iPhone
              Center(
                child: Container(
                  width: 520,
                  height: 940,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0A00FF87),
                        blurRadius: 180,
                        spreadRadius: 60,
                      ),
                      BoxShadow(
                        color: Color(0x0838BDF8),
                        blurRadius: 160,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. iPhone 13 Device Container (Centered & Auto-scaled to Viewport)
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _deviceWidth + 16, // Extra space for physical buttons
                        height: _deviceHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Tombol Fisik Samping (Hardware Buttons)
                            _buildHardwareButtons(),

                            // Chassis / Bodi Utama iPhone 13
                            Container(
                              width: _deviceWidth,
                              height: _deviceHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFF181A1F), // Midnight Black matte finish
                                borderRadius: BorderRadius.circular(_outerCornerRadius),
                                border: Border.all(
                                  color: const Color(0xFF2E323B), // Metallic chamfered outer rim
                                  width: 1.8,
                                ),
                                boxShadow: const [
                                  // Bayangan realistis multi-layer
                                  BoxShadow(
                                    color: Color(0xA6000000),
                                    blurRadius: 55,
                                    spreadRadius: 8,
                                    offset: Offset(0, 24),
                                  ),
                                  BoxShadow(
                                    color: Color(0x59000000),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(_bezelThickness),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(_screenCornerRadius),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(_screenCornerRadius),
                                    child: ScaffoldMessenger(
                                      child: Stack(
                                        children: [
                                          // Layar Aplikasi Utama (Scoped MediaQuery 390 x 844)
                                          Positioned.fill(
                                            child: MediaQuery(
                                              data: MediaQuery.of(context).copyWith(
                                                size: const Size(_screenWidth, _screenHeight),
                                                padding: const EdgeInsets.only(top: 47, bottom: 34),
                                                viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
                                                viewInsets: EdgeInsets.zero,
                                                devicePixelRatio: 3.0,
                                              ),
                                              child: SizedBox(
                                                width: _screenWidth,
                                                height: _screenHeight,
                                                child: widget.child,
                                              ),
                                            ),
                                          ),

                                          // Status Bar & iPhone 13 Notch (Non-blocking touch)
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            child: IgnorePointer(
                                              child: _buildIPhone13TopHeader(),
                                            ),
                                          ),

                                          // iOS Home Indicator Bar (Non-blocking touch)
                                          Positioned(
                                            bottom: 8,
                                            left: 0,
                                            right: 0,
                                            child: IgnorePointer(
                                              child: _buildHomeIndicator(),
                                            ),
                                          ),
                                        ],
                                      ),
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
                ),
              ),

              // 4. Subtle Top Controls / Toolbar (Desktop Helper)
              Positioned(
                top: 14,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge Info Device
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xE6161B26),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0x14FFFFFF),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.phone_iphone_rounded,
                            color: Color(0xFF00FF87),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'iPhone 13 • 390 × 844',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tombol Toggle Fullscreen / Frame
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        setState(() {
                          _forceFullscreen = !_forceFullscreen;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xE6161B26),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0x14FFFFFF),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _forceFullscreen
                                  ? Icons.phone_iphone_rounded
                                  : Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _forceFullscreen ? 'Mode HP' : 'Layar Penuh',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Tombol fisik perangkat (Silent switch, Volume, Power) di sisi luar chassis
  Widget _buildHardwareButtons() {
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sisi Kiri: Silent Switch
          Positioned(
            left: 2,
            top: 100,
            child: Container(
              width: 3.5,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF2C3038),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(2)),
                boxShadow: [
                  BoxShadow(color: Color(0x66000000), blurRadius: 2),
                ],
              ),
            ),
          ),

          // Sisi Kiri: Volume Up
          Positioned(
            left: 2,
            top: 140,
            child: Container(
              width: 3.5,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF2C3038),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(2)),
                boxShadow: [
                  BoxShadow(color: Color(0x66000000), blurRadius: 2),
                ],
              ),
            ),
          ),

          // Sisi Kiri: Volume Down
          Positioned(
            left: 2,
            top: 200,
            child: Container(
              width: 3.5,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF2C3038),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(2)),
                boxShadow: [
                  BoxShadow(color: Color(0x66000000), blurRadius: 2),
                ],
              ),
            ),
          ),

          // Sisi Kanan: Power / Side Button
          Positioned(
            right: 2,
            top: 155,
            child: Container(
              width: 3.5,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF2C3038),
                borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
                boxShadow: [
                  BoxShadow(color: Color(0x66000000), blurRadius: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bagian Atas: Notch iPhone 13 (lebih ramping dari iPhone 12) + Jam + Indikator Baterai
  Widget _buildIPhone13TopHeader() {
    return SizedBox(
      height: 47,
      child: Stack(
        children: [
          // Jam di sebelah kiri Notch
          Positioned(
            left: 26,
            top: 13,
            child: Text(
              _currentTime,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                shadows: const [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Notch iPhone 13 di Tengah
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 154,
              height: 29,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Speaker Grill (Earpiece horizontal halus di bagian paling atas)
                  Positioned(
                    top: 5,
                    child: Container(
                      width: 44,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25272C),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: const Color(0xFF333740),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Sensor Face ID (Sebelah Kiri)
                  Positioned(
                    left: 28,
                    top: 11,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141518),
                        border: Border.all(
                          color: const Color(0xFF222428),
                          width: 0.6,
                        ),
                      ),
                    ),
                  ),

                  // Kamera Depan TrueDepth (Sebelah Kanan Speaker)
                  Positioned(
                    right: 26,
                    top: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFF1D2235), // Pantulan sapphire biru tua
                            Color(0xFF090A0E),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF282C36),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 2.5,
                          height: 2.5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF3F4E75),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Indikator Sinyal, WiFi & Baterai di sebelah kanan Notch
          Positioned(
            right: 22,
            top: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 4 Bars Sinyal Seluler
                _buildSignalBars(),
                const SizedBox(width: 5),

                // Ikon WiFi
                const Icon(
                  Icons.wifi_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 5),

                // Ikon Baterai iOS
                _buildBatteryIcon(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4 Bar indikator sinyal seluler khas iOS
  Widget _buildSignalBars() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(4, true),
        const SizedBox(width: 1.5),
        _bar(6.5, true),
        const SizedBox(width: 1.5),
        _bar(9, true),
        const SizedBox(width: 1.5),
        _bar(11.5, true),
      ],
    );
  }

  Widget _bar(double height, bool filled) {
    return Container(
      width: 2.8,
      height: height,
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white24,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  /// Indikator Baterai iOS dengan terminal tip di sebelah kanan
  Widget _buildBatteryIcon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 21,
          height: 11,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3.5),
            border: Border.all(
              color: Colors.white,
              width: 1.2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
        Container(
          width: 1.5,
          height: 4.5,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(1),
            ),
          ),
        ),
      ],
    );
  }

  /// Home Indicator Bar di bagian bawah layar iPhone
  Widget _buildHomeIndicator() {
    return Center(
      child: Container(
        width: 134,
        height: 5,
        decoration: const BoxDecoration(
          color: Color(0xD9FFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(100)),
          boxShadow: [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
