import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/order_state.dart';
import '../theme/app_colors.dart';
import '../widgets/capsule_toast.dart';
import 'home_screen.dart';
import 'live_tracking_screen.dart';

class DigitalReceiptScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount;

  const DigitalReceiptScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
    bool initialCelebration = false,
  });

  @override
  State<DigitalReceiptScreen> createState() => _DigitalReceiptScreenState();
}

class _DigitalReceiptScreenState extends State<DigitalReceiptScreen>
    with TickerProviderStateMixin {
  late AnimationController _printController;
  late Animation<double> _printProgressAnimation;

  late AnimationController _ledController;
  late Animation<double> _ledAnimation;

  late AnimationController _stampController;
  late Animation<double> _stampScaleAnimation;
  late Animation<double> _stampOpacityAnimation;

  bool _isPrinting = true;

  final OrderState _orderState = OrderState.instance;

  @override
  void initState() {
    super.initState();

    // 1. Controller untuk animasi kertas keluar dari mesin (2400 ms smooth feeding)
    _printController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _printProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _printController, curve: Curves.easeInOutCubic),
    );

    // 2. Controller LED mesin berkedip selama mencetak
    _ledController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _ledAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ledController, curve: Curves.easeInOut));

    // 3. Controller stempel LUNAS (650 ms dengan bounce effect)
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _stampScaleAnimation = Tween<double>(begin: 2.5, end: 1.0).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.bounceOut),
    );

    _stampOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _stampController, curve: Curves.easeIn));

    // Mulai animasi cetak struk langsung saat layar struk dibuka
    _startPrintingSequence();
  }

  void _startPrintingSequence() {
    setState(() {
      _isPrinting = true;
    });

    _ledController.repeat(reverse: true);
    _stampController.reset();
    _printController.reset();

    // Delay halus 200ms sebelum mesin mulai menarik kertas
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _printController.forward().then((_) {
        if (!mounted) return;
        _ledController.stop();
        setState(() {
          _isPrinting = false;
        });

        // Setelah kertas selesai keluar penuh, jeda 200ms lalu STEMPEL basah jatuh
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          _stampController.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    _printController.dispose();
    _ledController.dispose();
    _stampController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.92),
                    Colors.white.withValues(alpha: 0.76),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ),
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.0,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 17,
                      color: AppColors.onSurface,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Struk Transaksi POS',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cetak Ulang',
            onPressed: _startPrintingSequence,
            icon: const Icon(Icons.replay_rounded, color: AppColors.primary),
          ),
          IconButton(
            onPressed: () {
              CapsuleToast.show(
                context,
                message: 'Tautan struk digital disalin!',
                icon: Icons.link_rounded,
              );
            },
            icon: const Icon(
              Icons.share_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            _buildCelebrationHeader(),
            const SizedBox(height: 16),
            _buildPrinterWithEmergingReceipt(),
            const SizedBox(height: 20),
            _buildBottomButtons(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.verified, color: Colors.white, size: 28),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.task_alt, color: AppColors.primary, size: 14),
              const SizedBox(width: 4),
              Text(
                'Pembayaran Terverifikasi!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Struk Resmi Transaksi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Order ID: ${widget.orderId} • Mesin Thermal POS Cetak Otomatis',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Mesin Cetak Thermal POS di atas dengan kertas struk keluar pelan-pelan ke bawah
  Widget _buildPrinterWithEmergingReceipt() {
    return Column(
      children: [
        // 1. MESIN CETAK THERMAL POS
        _buildThermalPrinterHead(),

        // 2. KERTAS STRUK YANG KELUAR DARI MESIN
        AnimatedBuilder(
          animation: Listenable.merge([_printController, _stampController]),
          builder: (context, child) {
            final progress = _printProgressAnimation.value;
            // Micro-vibration saat mesin mencetak
            final microVibration = _isPrinting
                ? sin(progress * 48 * pi) * 0.4
                : 0.0;

            return Transform.translate(
              offset: Offset(microVibration, 0),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: progress,
                  child: child,
                ),
              ),
            );
          },
          child: _buildReceiptPaperContent(),
        ),
      ],
    );
  }

  /// Unit Kepala Mesin Cetak Thermal (Sleek POS Device Header)
  Widget _buildThermalPrinterHead() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF4A5568), width: 1.0),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FOODIE POS-80',
                      style: GoogleFonts.sourceCodePro(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'THERMAL PRINTER',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFA0AEC0),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // LED Power (Solid Hijau)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PWR',
                    style: GoogleFonts.sourceCodePro(
                      color: const Color(0xFFA0AEC0),
                      fontSize: 8,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // LED Print (Berkedip saat cetak, solid saat selesai)
                  AnimatedBuilder(
                    animation: _ledController,
                    builder: (context, child) {
                      final opacity = _isPrinting ? _ledAnimation.value : 1.0;
                      return Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _isPrinting
                              ? Color.fromRGBO(56, 189, 248, opacity)
                              : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isPrinting
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF10B981))
                                      .withValues(alpha: opacity * 0.7),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isPrinting ? 'PRINT' : 'READY',
                    style: GoogleFonts.sourceCodePro(
                      color: _isPrinting
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF10B981),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Celah Pemotong Kertas / Printer Feed Slot (Metallic Slit)
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF718096), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kertas struk kasir dengan tekstur authentic, barcode, dan cap LUNAS
  Widget _buildReceiptPaperContent() {
    final cartItems = _orderState.cartItems;
    final discountAmount = _orderState.discountAmount;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kop Restoran & Order ID
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Foodie Express Delivery",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Thermal Printed Official Receipt',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          widget.orderId,
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Metadata Transaksi
                    _buildReceiptMetaRow(
                      'Waktu Cetak',
                      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} • ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB',
                    ),
                    const SizedBox(height: 5),
                    _buildReceiptMetaRow(
                      'Metode Pembayaran',
                      '${_orderState.paymentMethod} (Lunas)',
                    ),
                    const SizedBox(height: 5),
                    _buildReceiptMetaRow(
                      'No. Transaksi',
                      'TXN-${widget.orderId.replaceAll('#', '')}-POS',
                    ),

                    const SizedBox(height: 14),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Daftar Item Makanan
                    Text(
                      'Rincian Menu:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (cartItems.isEmpty) ...[
                      _buildReceiptItemRow('Milano Truffle Pizza', 1, 14.50),
                    ] else ...[
                      for (final item in cartItems)
                        _buildReceiptItemRow(
                          item.title,
                          item.quantity,
                          item.totalPrice,
                        ),
                    ],

                    const SizedBox(height: 14),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Ringkasan Rincian Biaya & Diskon
                    _buildReceiptMetaRow(
                      'Subtotal Pesanan',
                      '\$${_orderState.subtotal.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 5),
                    _buildReceiptMetaRow(
                      'Biaya Pengantaran (Ongkir)',
                      '\$2.00',
                    ),
                    const SizedBox(height: 5),
                    _buildReceiptMetaRow(
                      'Diskon Ongkir (Promo Foodie)',
                      '-\$2.00',
                      valueColor: AppColors.primary,
                    ),
                    const SizedBox(height: 5),
                    _buildReceiptMetaRow(
                      'Biaya Layanan & Pengemasan',
                      '\$0.50',
                    ),
                    const SizedBox(height: 5),
                    _buildReceiptMetaRow(
                      'Diskon Biaya Layanan',
                      '-\$0.50',
                      valueColor: AppColors.primary,
                    ),

                    // Diskon Voucher yang diterapkan
                    if (_orderState.voucherDiscountPercent > 0) ...[
                      const SizedBox(height: 5),
                      _buildReceiptMetaRow(
                        'Diskon Voucher (${_orderState.selectedVoucher})',
                        '-\$${discountAmount.toStringAsFixed(2)}',
                        valueColor: AppColors.primary,
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Total Dibayar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL LUNAS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          '\$${widget.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Barcode kasir
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 38,
                            width: 220,
                            child: CustomPaint(painter: _BarcodePainter()),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'FD-${widget.orderId.replaceAll('#', '')}-8892',
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 10,
                              letterSpacing: 2.0,
                              color: AppColors.outline,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Simpan struk ini sebagai bukti pembayaran yang sah.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              color: AppColors.outline,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bagian Bawah Kertas Bergerigi (Zigzag Tear Edge)
              SizedBox(
                height: 10,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ZigZagTearEdgePainter(
                    color: const Color(0xFFF3F4F6),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. STEMPEL BASAH MERAH "LUNAS • PAID"
        Positioned(
          top: 130,
          right: 28,
          child: AnimatedBuilder(
            animation: _stampController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -0.22,
                child: Transform.scale(
                  scale: _stampScaleAnimation.value,
                  child: Opacity(
                    opacity: _stampOpacityAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error, width: 2.4),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LUNAS • PAID',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            'FOODIE OFFICIAL CERTIFIED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFD1D5DB)),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildReceiptItemRow(String title, int quantity, double price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$title × $quantity',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '\$${price.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptMetaRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        // Tombol Cetak Ulang Animasi
        OutlinedButton.icon(
          onPressed: _startPrintingSequence,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(
            'Cetak Ulang Struk',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.2),
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(23),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Tombol Lacak Pesanan
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    LiveTrackingScreen(orderId: widget.orderId),
              ),
            );
          },
          icon: const Icon(Icons.moped, size: 20),
          label: Text(
            'Lacak Pesanan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            elevation: 3,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Download PDF
        TextButton.icon(
          onPressed: () {
            CapsuleToast.show(
              context,
              message: 'File PDF Struk berhasil disimpan ke perangkat!',
              icon: Icons.picture_as_pdf_rounded,
            );
          },
          icon: const Icon(
            Icons.picture_as_pdf,
            size: 18,
            color: AppColors.outline,
          ),
          label: Text(
            'Download File PDF Struk',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.outline,
            ),
          ),
        ),
      ],
    );
  }
}

/// Painter untuk efek sobekan kertas bergerigi (Zigzag tear-off edge)
class _ZigZagTearEdgePainter extends CustomPainter {
  final Color color;
  const _ZigZagTearEdgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    const toothWidth = 8.0;
    const toothHeight = 6.0;
    final count = (size.width / toothWidth).ceil();

    for (int i = 0; i < count; i++) {
      final x1 = i * toothWidth + (toothWidth / 2);
      final y1 = size.height - toothHeight;
      final x2 = (i + 1) * toothWidth;
      final y2 = size.height;
      path.lineTo(x1, y1);
      path.lineTo(x2, y2);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF161C27);
    final pattern = [
      3,
      1,
      2,
      4,
      1,
      3,
      2,
      1,
      4,
      2,
      1,
      3,
      2,
      4,
      1,
      2,
      3,
      1,
      2,
      4,
      1,
      3,
      2,
      1,
      4,
      1,
      2,
      3,
      2,
      4,
      1,
      2,
      3,
    ];

    double totalPatternWidth = 0;
    for (int i = 0; i < pattern.length; i++) {
      totalPatternWidth += pattern[i] * 1.8;
      if (i < pattern.length - 1) {
        totalPatternWidth += 1.2;
      }
    }

    // Geser simetris ke tengah/kanan agar persis di center struk
    double currentX = ((size.width - totalPatternWidth) / 2).clamp(
      0.0,
      size.width,
    );
    bool isBar = true;

    for (int width in pattern) {
      final barWidth = width * 1.8;
      if (isBar && currentX + barWidth <= size.width) {
        canvas.drawRect(
          Rect.fromLTWH(currentX, 0, barWidth, size.height),
          paint,
        );
      }
      currentX += barWidth + 1.2;
      isBar = !isBar;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter untuk efek background hijau berputar memutar ke tengah logo sukses
class GreenRotatingAuraPainter extends CustomPainter {
  final double rotationAngle;
  final double pulseValue;
  final int rayCount;
  final double maxOpacity;

  GreenRotatingAuraPainter({
    required this.rotationAngle,
    required this.pulseValue,
    this.rayCount = 18,
    this.maxOpacity = 0.16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;

    // 1. Concentric pulsing ambient ripples (riak berdenyut memusat)
    for (int i = 1; i <= 3; i++) {
      final rippleProgress = (pulseValue + (i * 0.33)) % 1.0;
      final rippleRadius = maxRadius * (0.30 + rippleProgress * 0.65);
      final rippleOpacity = (1.0 - rippleProgress) * maxOpacity * 1.5;

      final ripplePaint = Paint()
        ..color = const Color(0xFF2E7D32).withValues(alpha: rippleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;

      canvas.drawCircle(center, rippleRadius, ripplePaint);
    }

    // 2. Rotating rays into center (pancaran berputar spiral ke arah tengah logo)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    final rayPaint = Paint()..style = PaintingStyle.fill;
    final angleStep = (2 * pi) / rayCount;

    for (int i = 0; i < rayCount; i++) {
      final currentAngle = i * angleStep;
      final path = Path();
      path.moveTo(0, 0);

      final rayAngleSpread = angleStep * 0.45;
      final x1 = maxRadius * 1.25 * cos(currentAngle - rayAngleSpread / 2);
      final y1 = maxRadius * 1.25 * sin(currentAngle - rayAngleSpread / 2);
      final x2 = maxRadius * 1.25 * cos(currentAngle + rayAngleSpread / 2);
      final y2 = maxRadius * 1.25 * sin(currentAngle + rayAngleSpread / 2);

      path.lineTo(x1, y1);
      path.lineTo(x2, y2);
      path.close();

      final rayColor = (i % 2 == 0)
          ? const Color(0xFF0D631B)
                .withValues(alpha: maxOpacity * (0.75 + 0.25 * pulseValue))
          : const Color(
              0xFF4CAF50,
            ).withValues(alpha: maxOpacity * 0.6 * (0.75 + 0.25 * pulseValue));

      rayPaint.color = rayColor;
      canvas.drawPath(path, rayPaint);
    }

    canvas.restore();

    // 3. Radial Gradient Core Glow memancar lembut dari pusat logo
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          const Color(0xFFE8F5E9).withValues(alpha: 0.95),
          const Color(0xFFCBFFC2).withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant GreenRotatingAuraPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.rayCount != rayCount ||
        oldDelegate.maxOpacity != maxOpacity;
  }
}
