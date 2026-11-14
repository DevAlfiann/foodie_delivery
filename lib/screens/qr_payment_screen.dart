import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/order_state.dart';
import '../widgets/capsule_toast.dart';
import '../widgets/payment_success_overlay.dart';

class QRPaymentScreen extends StatefulWidget {
  final double totalAmount;
  final String orderId;

  const QRPaymentScreen({
    super.key,
    required this.totalAmount,
    required this.orderId,
  });

  @override
  State<QRPaymentScreen> createState() => _QRPaymentScreenState();
}

class _QRPaymentScreenState extends State<QRPaymentScreen> {
  int _secondsLeft = 256; // 04:16 = 4 * 60 + 16 = 256 detik
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        if (mounted) setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _formattedTotalAmount {
    return '\$${widget.totalAmount.toStringAsFixed(2)}';
  }

  String get _ticketCode {
    // Menghasilkan format kode karcis seperti '20-L6N8C-0001'
    final raw = widget.orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final code = raw.length >= 5 ? raw.substring(0, 5) : raw.padRight(5, 'X');
    return '20-$code-0001';
  }

  void _confirmPayment() {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    CapsuleToast.show(
      context,
      message: 'Pembayaran QRIS Berhasil Diverifikasi!',
      icon: Icons.check_circle_rounded,
      duration: const Duration(seconds: 4),
    );

    OrderState.instance.setPaymentMethod('QRIS');

    PaymentSuccessOverlay.show(
      context,
      orderId: widget.orderId,
      totalAmount: widget.totalAmount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F5A31).withValues(alpha: 0.94),
                    const Color(0xFF1B6B3E).withValues(alpha: 0.84),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F5A31).withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 1.0,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Pembayaran QRIS',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),

                    // ============================================
                    // 1. HEADER: LOGO QRIS & LOGO GPN
                    // ============================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo QRIS di kiri
                        _buildQRISHeaderLogo(),

                        // Logo GPN di kanan
                        _buildGPNHeaderLogo(),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ============================================
                    // 2. TEKS INSTRUKSI & HITUNG MUNDUR (COUNTDOWN)
                    // ============================================
                    Text(
                      'Tunjukkan kode di bawah ini ke konsumen',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF222222),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'berlaku : ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF222222),
                          ),
                        ),
                        Text(
                          _formattedTime,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(
                              0xFFE53935,
                            ), // Merah / pink persis screenshot
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ============================================
                    // 3. QR CODE KASIR STANDAR INDONESIA
                    // ============================================
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CustomPaint(
                          size: const Size(250, 250),
                          painter: _IndonesianQRISPainter(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 34),

                    // ============================================
                    // 4. TAGIHAN SEBESAR & NOMINAL ORANYE
                    // ============================================
                    Text(
                      'TAGIHAN SEBESAR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _formattedTotalAmount,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0D631B), // Warna hijau Foodie
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 18),

                    // ============================================
                    // 5. KODE KARCIS
                    // ============================================
                    Text(
                      'KODE KARCIS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF222222),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _ticketCode,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF222222),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ============================================
            // 6. ACTION: CEK STATUS PEMBAYARAN (SIMULASI LUNAS)
            // ============================================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF0D631B,
                  ), // Warna Hijau Foodie Brand
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Memverifikasi Pembayaran...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.check_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Cek Status Pembayaran',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // WIDGET LOGO QRIS RESMI
  // ============================================
  Widget _buildQRISHeaderLogo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text(
              'QRIS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.8,
              ),
            ),
          ),
          // Corner bracket top-left
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black, width: 2.5),
                  left: BorderSide(color: Colors.black, width: 2.5),
                ),
              ),
            ),
          ),
          // Corner bracket bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 2.5),
                  right: BorderSide(color: Colors.black, width: 2.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // WIDGET LOGO GPN (GERBANG PEMBAYARAN NASIONAL)
  // ============================================
  Widget _buildGPNHeaderLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Garuda Merah GPN
        CustomPaint(size: const Size(32, 22), painter: _GPNWingsPainter()),
        const SizedBox(height: 1),
        Text(
          'GPN',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF003366), // Biru khas GPN
            letterSpacing: 0.8,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

// ============================================
// CUSTOM PAINTER SAYAP GARUDA GPN
// ============================================
class _GPNWingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    final path = Path();
    // Gambar bentuk sayap burung garuda melayang ke kanan
    path.moveTo(size.width * 0.1, size.height * 0.85);
    path.lineTo(size.width * 0.35, size.height * 0.55);
    path.lineTo(size.width * 0.25, size.height * 0.5);
    path.lineTo(size.width * 0.65, size.height * 0.25);
    path.lineTo(size.width * 0.5, size.height * 0.22);
    path.lineTo(size.width * 0.95, size.height * 0.05); // Ujung sayap teratas
    path.lineTo(size.width * 0.8, size.height * 0.45);
    path.lineTo(size.width * 0.92, size.height * 0.42);
    path.lineTo(size.width * 0.65, size.height * 0.75);
    path.lineTo(size.width * 0.78, size.height * 0.72);
    path.lineTo(size.width * 0.45, size.height * 0.95);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================
// CUSTOM PAINTER QR CODE INDONESIAN QRIS DENSE MATRIX
// ============================================
class _IndonesianQRISPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blackPaint = Paint()..color = Colors.black;
    final whitePaint = Paint()..color = Colors.white;

    // Gambar background putih
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), whitePaint);

    const int gridCount = 29;
    final double moduleSize = size.width / gridCount;

    // Helper untuk menggambar modul kotak hitam
    void drawModule(int col, int row) {
      if (col >= 0 && col < gridCount && row >= 0 && row < gridCount) {
        canvas.drawRect(
          Rect.fromLTWH(
            col * moduleSize,
            row * moduleSize,
            moduleSize,
            moduleSize,
          ),
          blackPaint,
        );
      }
    }

    // Helper untuk 3 Finder Patterns (7x7 kotak sudut)
    void drawFinder(int startCol, int startRow) {
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          if (r == 0 || r == 6 || c == 0 || c == 6) {
            drawModule(startCol + c, startRow + r);
          } else if (r >= 2 && r <= 4 && c >= 2 && c <= 4) {
            drawModule(startCol + c, startRow + r);
          }
        }
      }
    }

    // Gambar 3 Finder Patterns
    drawFinder(0, 0); // Kiri Atas
    drawFinder(gridCount - 7, 0); // Kanan Atas
    drawFinder(0, gridCount - 7); // Kiri Bawah

    // Alignment pattern (5x5) di kanan bawah
    const int alignCol = gridCount - 9;
    const int alignRow = gridCount - 9;
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        if (r == 0 || r == 4 || c == 0 || c == 4 || (r == 2 && c == 2)) {
          drawModule(alignCol + c, alignRow + r);
        }
      }
    }

    // Timing patterns
    for (int i = 7; i < gridCount - 7; i += 2) {
      drawModule(i, 6);
      drawModule(6, i);
    }

    // Deterministik pseudorandom data modules untuk menghasilkan QR yang padat & mirip gambar asli
    // Matriks data boolean
    for (int r = 0; r < gridCount; r++) {
      for (int c = 0; c < gridCount; c++) {
        // Lewati area finder pattern
        if (r <= 7 && c <= 7) continue;
        if (r <= 7 && c >= gridCount - 8) continue;
        if (r >= gridCount - 8 && c <= 7) continue;
        // Lewati area alignment pattern
        if (r >= alignRow - 1 &&
            r <= alignRow + 5 &&
            c >= alignCol - 1 &&
            c <= alignCol + 5)
          continue;
        // Lewati timing pattern
        if (r == 6 || c == 6) continue;

        // Formula hash deterministik yang menciptakan kepadatan QR code kasir
        final int hash = (r * 37 + c * 23 + (r ^ c) * 17 + ((r * c) % 7)) % 100;
        if (hash < 49) {
          drawModule(c, r);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
