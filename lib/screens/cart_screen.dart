import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../models/order_state.dart';
import '../theme/app_colors.dart';
import '../widgets/capsule_toast.dart';
import '../widgets/coupon_applied_overlay.dart';
import '../widgets/payment_success_overlay.dart';
import 'home_screen.dart';
import 'live_tracking_screen.dart';
import 'qr_payment_screen.dart';

class CartScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBackToHome;

  const CartScreen({super.key, this.showBackButton = true, this.onBackToHome});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final OrderState _orderState = OrderState.instance;

  // Controller map interaktif (bisa digeser & zoom pada menu checkout)
  late final TransformationController _checkoutMapController;

  // Detail metode pembayaran spesifik
  bool _hasSelectedPayment = false;
  String _selectedPaymentCategory = 'QRIS'; // 'QRIS', 'Card', 'EWallet', 'COD'
  String _selectedPaymentTitle = 'Pilih Metode Pembayaran';
  String _selectedPaymentSubtitle =
      'Ketuk untuk memilih QRIS, Kartu Debit, E-Wallet, atau COD';
  IconData _selectedPaymentIcon = Icons.payment_rounded;
  Color _selectedPaymentColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _checkoutMapController = TransformationController();
    _orderState.addListener(_onStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _centerCheckoutMap(_orderState.selectedAddressIndex);
      }
    });
  }

  @override
  void dispose() {
    _checkoutMapController.dispose();
    _orderState.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _centerCheckoutMap(int addressIndex, [Size? viewportSize]) {
    final vSize = viewportSize ?? const Size(360, 185);
    const baseW = 1024.0;
    const baseH = 1024.0;
    const scale = 1.6;

    double targetNormalizedX = 0.2690;
    double targetNormalizedY = 0.4104;

    switch (addressIndex) {
      case 1: // Kantor
        targetNormalizedX = 0.5083;
        targetNormalizedY = 0.1294;
        break;
      case 2: // Apartemen
        targetNormalizedX = 0.5278;
        targetNormalizedY = 0.3967;
        break;
      case 0: // Rumah
      default:
        targetNormalizedX = 0.2690;
        targetNormalizedY = 0.4104;
        break;
    }

    final tx = (vSize.width / 2) - (targetNormalizedX * baseW * scale);
    final ty = (vSize.height / 2) - (targetNormalizedY * baseH * scale);

    final minTx = vSize.width - (baseW * scale);
    const maxTx = 0.0;
    final clampedTx = minTx <= maxTx ? tx.clamp(minTx, maxTx) : minTx / 2;

    final minTy = vSize.height - (baseH * scale);
    const maxTy = 0.0;
    final clampedTy = minTy <= maxTy ? ty.clamp(minTy, maxTy) : minTy / 2;

    _checkoutMapController.value = Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(clampedTx, clampedTy, 0.0);
  }

  void _proceedToCheckout() {
    _orderState.placeNewOrder();
    final activeId = _orderState.activeOrderId;
    final total = _orderState.grandTotal;

    if (_selectedPaymentCategory == 'QRIS') {
      // Buka langsung pembayaran QRIS seperti di gambar
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              QRPaymentScreen(totalAmount: total, orderId: activeId),
        ),
      );
    } else if (_selectedPaymentCategory == 'Card') {
      // Langsung verifikasi kartu debit dan buka overlay perayaan pembayaran berhasil
      _orderState.setPaymentMethod(_selectedPaymentTitle);

      PaymentSuccessOverlay.show(
        context,
        orderId: activeId,
        totalAmount: total,
      );
    } else if (_selectedPaymentCategory == 'EWallet') {
      // Langsung proses potong saldo e-wallet dan buka overlay perayaan pembayaran berhasil
      _orderState.setPaymentMethod(_selectedPaymentTitle);

      PaymentSuccessOverlay.show(
        context,
        orderId: activeId,
        totalAmount: total,
      );
    } else if (_selectedPaymentCategory == 'COD') {
      // Cash on Delivery: langsung konfirmasi pesanan dan buka Live Tracking
      CapsuleToast.show(
        context,
        message: 'Pesanan COD Berhasil! Siapkan uang tunai saat kurir tiba 💵',
        icon: Icons.payments_rounded,
        duration: const Duration(seconds: 5),
      );

      _orderState.setPaymentMethod('Cash on Delivery (COD)');

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LiveTrackingScreen(orderId: activeId),
          ),
        );
      });
    }
  }

  void _showAddressSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Alamat Pengantaran',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '3 Alamat Tersedia',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...List.generate(OrderState.demoAddressOptions.length, (index) {
                final addr = OrderState.demoAddressOptions[index];
                final isSelected = _orderState.selectedAddressIndex == index;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    _orderState.setAddressIndex(index);
                    _centerCheckoutMap(index);
                    Navigator.of(ctx).pop();
                    CapsuleToast.show(
                      context,
                      message: 'Alamat diubah: ${addr.title}',
                      icon: Icons.check_circle_rounded,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE8F5E9)
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.outlineVariant.withValues(alpha: 0.5),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            index == 0
                                ? Icons.home_rounded
                                : (index == 1
                                      ? Icons.business_rounded
                                      : Icons.apartment_rounded),
                            color: isSelected
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    addr.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Terpilih',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                addr.fullAddress,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Resto: ${addr.restaurantName} • Driver: ${addr.driverName}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.outline,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentMethodSelector() {
    String? expandedCategory; // 'Card' or 'EWallet'

    final savedCards = [
      {
        'bank': 'BCA Prioritas',
        'type': 'Mastercard Platinum',
        'last4': '8812',
        'color': const Color(0xFF003882),
        'isPrimary': true,
      },
      {
        'bank': 'Mandiri',
        'type': 'Platinum Visa',
        'last4': '4291',
        'color': const Color(0xFF002B49),
        'isPrimary': false,
      },
    ];

    final ewallets = [
      {
        'name': 'GoPay',
        'balance': 'Rp 245.000',
        'color': const Color(0xFF00AED6),
        'icon': Icons.account_balance_wallet_rounded,
        'tag': 'Saldo Cukup',
      },
      {
        'name': 'OVO',
        'balance': 'Rp 180.000',
        'color': const Color(0xFF4C3494),
        'icon': Icons.wallet_rounded,
        'tag': 'Cashback 10%',
      },
      {
        'name': 'DANA',
        'balance': 'Rp 310.000',
        'color': const Color(0xFF118EEA),
        'icon': Icons.payment_rounded,
        'tag': 'Terhubung',
      },
      {
        'name': 'ShopeePay',
        'balance': 'Rp 95.000',
        'color': const Color(0xFFEE4D2D),
        'icon': Icons.shopping_bag_outlined,
        'tag': 'Diskon Rp5rb',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.payment_rounded,
                            color: AppColors.primaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pilih Metode Pembayaran',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                'Pilih pembayaran untuk melanjutkan checkout',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ===================================
                    // 1. OPSI QRIS (INSTANT SELECT)
                    // ===================================
                    _buildPaymentOptionTile(
                      title: 'QRIS',
                      subtitle: 'QR Code Standar Pembayaran Nasional (GoPay, OVO, Dana, BCA, dll)',
                      badge: 'Populer ⚡',
                      icon: Icons.qr_code_2,
                      iconColor: AppColors.primary,
                      isSelected:
                          _hasSelectedPayment &&
                          _selectedPaymentCategory == 'QRIS',
                      onTap: () {
                        setState(() {
                          _hasSelectedPayment = true;
                          _selectedPaymentCategory = 'QRIS';
                          _selectedPaymentTitle = 'QRIS';
                          _selectedPaymentSubtitle =
                              'QR Code Standar Pembayaran Nasional';
                          _selectedPaymentIcon = Icons.qr_code_2;
                          _selectedPaymentColor = AppColors.primary;
                        });
                        _orderState.setPaymentMethod('QRIS');
                        Navigator.of(ctx).pop();
                        CapsuleToast.show(
                          context,
                          message: 'Metode dipilih: QRIS',
                          icon: Icons.qr_code_2,
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ===================================
                    // 2. OPSI KARTU DEBIT (EXPANDABLE)
                    // ===================================
                    _buildExpandablePaymentTile(
                      title: 'Kartu Debit',
                      subtitle:
                          _hasSelectedPayment &&
                              _selectedPaymentCategory == 'Card'
                          ? _selectedPaymentTitle
                          : 'Pilih kartu debit yang ingin digunakan',
                      badge: '${savedCards.length} Kartu Tersedia',
                      icon: Icons.credit_card_rounded,
                      iconColor: const Color(0xFF1E88E5),
                      isExpanded: expandedCategory == 'Card',
                      isSelected:
                          _hasSelectedPayment &&
                          _selectedPaymentCategory == 'Card',
                      onHeaderTap: () {
                        setModalState(() {
                          expandedCategory = (expandedCategory == 'Card')
                              ? null
                              : 'Card';
                        });
                      },
                      expandedContent: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),
                          const SizedBox(height: 10),
                          Text(
                            'PILIH KARTU DEBIT ANDA:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...savedCards.map((card) {
                            final isCardSelected =
                                _hasSelectedPayment &&
                                _selectedPaymentCategory == 'Card' &&
                                _selectedPaymentTitle.contains(
                                  card['last4'] as String,
                                );

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _hasSelectedPayment = true;
                                  _selectedPaymentCategory = 'Card';
                                  _selectedPaymentTitle =
                                      'Kartu Debit ${card['bank']} •••• ${card['last4']}';
                                  _selectedPaymentSubtitle =
                                      '${card['type']} • Pembayaran Otomatis';
                                  _selectedPaymentIcon =
                                      Icons.credit_card_rounded;
                                  _selectedPaymentColor =
                                      card['color'] as Color;
                                });
                                _orderState.setPaymentMethod(
                                  'Kartu Debit ${card['bank']} •••• ${card['last4']}',
                                );
                                Navigator.of(ctx).pop();
                                CapsuleToast.show(
                                  context,
                                  message:
                                      'Kartu dipilih: ${card['bank']} (•••• ${card['last4']})',
                                  icon: Icons.credit_card_rounded,
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isCardSelected
                                      ? const Color(0xFFE3F2FD)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCardSelected
                                        ? const Color(0xFF1E88E5)
                                        : const Color(0xFFE0E0E0),
                                    width: isCardSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: card['color'] as Color,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.payment,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                card['bank'] as String,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.onSurface,
                                                    ),
                                              ),
                                              if (card['isPrimary'] ==
                                                  true) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF1E88E5,
                                                    ).withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Utama',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: const Color(
                                                            0xFF1E88E5,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            '${card['type']} •••• ${card['last4']}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isCardSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked,
                                      color: isCardSelected
                                          ? const Color(0xFF1E88E5)
                                          : AppColors.outline,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          // Tombol Tambah Kartu Baru
                          InkWell(
                            onTap: () {
                              CapsuleToast.show(
                                context,
                                message: 'Fitur pendaftaran kartu debit baru segera dibuka',
                                icon: Icons.add_card_rounded,
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Color(0xFF1E88E5),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+ Tambah Kartu Debit Baru',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E88E5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ===================================
                    // 3. OPSI E-WALLET (EXPANDABLE)
                    // ===================================
                    _buildExpandablePaymentTile(
                      title: 'E-Wallet',
                      subtitle:
                          _hasSelectedPayment &&
                              _selectedPaymentCategory == 'EWallet'
                          ? _selectedPaymentTitle
                          : 'GoPay, OVO, DANA, ShopeePay',
                      badge: 'Otomatis',
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFF8E24AA),
                      isExpanded: expandedCategory == 'EWallet',
                      isSelected:
                          _hasSelectedPayment &&
                          _selectedPaymentCategory == 'EWallet',
                      onHeaderTap: () {
                        setModalState(() {
                          expandedCategory = (expandedCategory == 'EWallet')
                              ? null
                              : 'EWallet';
                        });
                      },
                      expandedContent: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),
                          const SizedBox(height: 10),
                          Text(
                            'PILIH DOMPET DIGITAL DENGAN SALDO TERSEDIA:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...ewallets.map((wallet) {
                            final isWalletSelected =
                                _hasSelectedPayment &&
                                _selectedPaymentCategory == 'EWallet' &&
                                _selectedPaymentTitle.contains(
                                  wallet['name'] as String,
                                );

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _hasSelectedPayment = true;
                                  _selectedPaymentCategory = 'EWallet';
                                  _selectedPaymentTitle =
                                      '${wallet['name']} (Saldo ${wallet['balance']})';
                                  _selectedPaymentSubtitle =
                                      'Pembayaran instan langsung potong saldo';
                                  _selectedPaymentIcon =
                                      wallet['icon'] as IconData;
                                  _selectedPaymentColor =
                                      wallet['color'] as Color;
                                });
                                _orderState.setPaymentMethod(
                                  '${wallet['name']} (Saldo ${wallet['balance']})',
                                );
                                Navigator.of(ctx).pop();
                                CapsuleToast.show(
                                  context,
                                  message:
                                      'E-Wallet dipilih: ${wallet['name']} • ${wallet['balance']}',
                                  icon: wallet['icon'] as IconData,
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isWalletSelected
                                      ? (wallet['color'] as Color).withValues(
                                          alpha: 0.08,
                                        )
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isWalletSelected
                                        ? (wallet['color'] as Color)
                                        : const Color(0xFFE0E0E0),
                                    width: isWalletSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: (wallet['color'] as Color)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        wallet['icon'] as IconData,
                                        color: wallet['color'] as Color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                wallet['name'] as String,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.onSurface,
                                                    ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      (wallet['color'] as Color)
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  wallet['tag'] as String,
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            wallet['color']
                                                                as Color,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'Saldo: ${wallet['balance']}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isWalletSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked,
                                      color: isWalletSelected
                                          ? (wallet['color'] as Color)
                                          : AppColors.outline,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ===================================
                    // 4. OPSI CASH ON DELIVERY (COD)
                    // ===================================
                    _buildPaymentOptionTile(
                      title: 'Cash on Delivery (COD)',
                      subtitle: 'Bayar tunai secara langsung kepada kurir saat pesanan sampai',
                      badge: 'Bayar di Tempat 💵',
                      icon: Icons.payments_outlined,
                      iconColor: const Color(0xFFFB8C00),
                      isSelected:
                          _hasSelectedPayment &&
                          _selectedPaymentCategory == 'COD',
                      onTap: () {
                        setState(() {
                          _hasSelectedPayment = true;
                          _selectedPaymentCategory = 'COD';
                          _selectedPaymentTitle = 'Cash on Delivery (COD)';
                          _selectedPaymentSubtitle =
                              'Bayar tunai kepada kurir saat pesanan tiba';
                          _selectedPaymentIcon = Icons.payments_outlined;
                          _selectedPaymentColor = const Color(0xFFFB8C00);
                        });
                        _orderState.setPaymentMethod('Cash on Delivery (COD)');
                        Navigator.of(ctx).pop();
                        CapsuleToast.show(
                          context,
                          message: 'Metode dipilih: Cash on Delivery (COD)',
                          icon: Icons.payments_outlined,
                        );
                      },
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentOptionTile({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE8F5E9)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : AppColors.outline,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandablePaymentTile({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color iconColor,
    required bool isExpanded,
    required bool isSelected,
    required VoidCallback onHeaderTap,
    required Widget expandedContent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFF0FDF4)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : AppColors.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onHeaderTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: iconColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: expandedContent,
            ),
        ],
      ),
    );
  }

  void _showVoucherSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final vouchers = _orderState.vouchers;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.discount_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pilih Voucher Diskon',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_orderState.claimedVouchers.length} Tersedia',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih voucher untuk mendapatkan potongan harga pesanan Anda.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: vouchers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final voucher = vouchers[index];
                        final isSelected =
                            _orderState.selectedVoucher == voucher.code;

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            if (!voucher.isClaimed) {
                              _orderState.claimVoucher(voucher.code);
                            }
                            _orderState.applyVoucherModel(voucher);
                            Navigator.pop(ctx);
                            CouponAppliedOverlay.show(
                              context,
                              voucherCode: voucher.code,
                              discountPercent: voucher.discountPercent,
                              discountAmount: _orderState.discountAmount,
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE8F5E9)
                                  : AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Badge Diskon
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0F5A31),
                                        Color(0xFF1E824C),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${(voucher.discountPercent * 100).toInt()}%',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          'OFF',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.secondaryContainer,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors
                                                  .secondaryContainer
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              voucher.code,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.primary,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            voucher.expiryText,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: AppColors.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        voucher.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        voucher.description,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Aktif',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (voucher.isClaimed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Pakai',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.primary,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Klaim',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    color: Colors.white.withValues(alpha: 0.88),
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
            if (widget.showBackButton || widget.onBackToHome != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.0,
                      ),
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (widget.onBackToHome != null) {
                          widget.onBackToHome!();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
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
            if (widget.showBackButton || widget.onBackToHome != null)
              const SizedBox(width: 10),
            Image.asset(
              'assets/images/foto.png',
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/logo.png',
                height: 28,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.restaurant, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Order Checkout',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              CapsuleToast.show(
                context,
                message: 'Tautan keranjang disalin!',
                icon: Icons.link_rounded,
              );
            },
            icon: const Icon(
              Icons.share_outlined,
              color: AppColors.onSurfaceVariant,
              size: 22,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage('assets/images/avatar.png'),
              onBackgroundImageError: (exception, stackTrace) {},
              child: const Icon(
                Icons.person,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scroll) {
          if (scroll is ScrollUpdateNotification) {
            CapsuleToast.dismiss(fast: true);
          }
          return false;
        },
        child: Listener(
          onPointerMove: (_) => CapsuleToast.dismiss(fast: true),
          child: _orderState.cartItems.isEmpty
              ? _buildEmptyCart()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDeliverySegment(),
                      const SizedBox(height: 14),
                      if (_orderState.isDelivery) ...[
                        _buildAddressCard(),
                        const SizedBox(height: 14),
                        _buildDeliverySpeedSection(),
                      ],
                      const SizedBox(height: 14),
                      _buildStoreAndItemsSection(),
                      const SizedBox(height: 14),
                      _buildVoucherSection(),
                      const SizedBox(height: 14),
                      _buildPaymentMethodSection(),
                      const SizedBox(height: 14),
                      _buildSummaryBreakdown(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
        ),
      ),
      bottomNavigationBar: _orderState.cartItems.isEmpty
          ? null
          : _buildCheckoutBar(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                size: 48,
                color: AppColors.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keranjang Anda Kosong',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih hidangan lezat dari restoran favorit Anda dan nikmati pengiriman cepat langsung ke lokasi Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                }
              },
              icon: const Icon(Icons.restaurant_menu, size: 20),
              label: Text(
                'Eksplor Menu & Restoran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                elevation: 2,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _orderState.toggleDelivery(true),
              borderRadius: BorderRadius.circular(26),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _orderState.isDelivery
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: _orderState.isDelivery
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.moped,
                      size: 18,
                      color: _orderState.isDelivery
                          ? Colors.white
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Delivery',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _orderState.isDelivery
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _orderState.toggleDelivery(false),
              borderRadius: BorderRadius.circular(26),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_orderState.isDelivery
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: !_orderState.isDelivery
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront,
                      size: 18,
                      color: !_orderState.isDelivery
                          ? Colors.white
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Self pick-up',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: !_orderState.isDelivery
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
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
  }

  Widget _buildAddressCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Delivery Address',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _showAddressSelector,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Change',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.swap_horiz,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Map interaktif dengan batasan (mentok tidak bisa digeser lagi)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, mapConstraints) {
                        final mW = mapConstraints.maxWidth;
                        final mH = mapConstraints.maxHeight;
                        const baseW = 1024.0;
                        const baseH = 1024.0;
                        final minMapScale = (mW > 0 && mH > 0)
                            ? math.max(mW / baseW, mH / baseH)
                            : 0.8;

                        return InteractiveViewer(
                          transformationController: _checkoutMapController,
                          constrained: false,
                          panAxis: PanAxis.free,
                          boundaryMargin: EdgeInsets.zero,
                          minScale: minMapScale,
                          maxScale: 3.5,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: 1024,
                            height: 1024,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/images/peta.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => Image.asset(
                                          'assets/images/foodie_custom_map.jpg',
                                          fit: BoxFit.cover,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Subtle gradient overlay at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.38),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating Tombol Pusatkan ke Lokasi (Kanan Atas)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () =>
                          _centerCheckoutMap(_orderState.selectedAddressIndex),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Address Floating Capsule
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _orderState.deliveryAddress,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    color: AppColors.primary,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '15-20 m',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeliverySpeedModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isFast = _orderState.isFastDelivery;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.electric_moped_rounded,
                              color: Color(0xFFF57F17),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Pilih Pengantaran',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '2 Opsi Tersedia',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih kecepatan pengantaran sesuai kebutuhan Anda hari ini.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Opsi 1: PENGANTARAN CEPAT DENGAN ANIMASI LIGHTNING JSON
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _orderState.setFastDelivery(true);
                      Navigator.of(ctx).pop();
                      CapsuleToast.show(
                        context,
                        message:
                            'Pengantaran Cepat dipilih: Estimasi 15-20 menit ⚡',
                        icon: Icons.bolt_rounded,
                        iconColor: const Color(0xFFFFB300),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isFast
                            ? const Color(0xFFFFFDE7).withValues(alpha: 0.6)
                            : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFast
                              ? const Color(0xFFFFB300)
                              : AppColors.outlineVariant.withValues(alpha: 0.5),
                          width: isFast ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isFast
                                ? const Color(0xFFFFB300)
                                      .withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isFast
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isFast
                                ? const Color(0xFFF57F17)
                                : AppColors.outline,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Pengantaran Cepat',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isFast
                                              ? const Color(0xFFBF360C)
                                              : AppColors.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Animasi lightning json
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Lottie.asset(
                                        'assets/animations/lightning.json',
                                        fit: BoxFit.contain,
                                        repeat: true,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.bolt_rounded,
                                                  size: 20,
                                                  color: Color(0xFFFFB300),
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF57F17)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '15-20 min',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFE65100),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Prioritas tanpa transit, kurir langsung mengantar ke lokasi Anda',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$2.00',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isFast
                                      ? const Color(0xFFE65100)
                                      : AppColors.onSurface,
                                ),
                              ),
                              Text(
                                '\$3.50',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Opsi 2: PENGANTARAN HEMAT
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _orderState.setFastDelivery(false);
                      Navigator.of(ctx).pop();
                      CapsuleToast.show(
                        context,
                        message: 'Pengantaran Hemat dipilih: Ongkir GRATIS! 🍃',
                        icon: Icons.eco_rounded,
                        iconColor: AppColors.primary,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: !isFast
                            ? const Color(0xFFE8F5E9).withValues(alpha: 0.5)
                            : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !isFast
                              ? AppColors.primary
                              : AppColors.outlineVariant.withValues(alpha: 0.5),
                          width: !isFast ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: !isFast
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !isFast
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: !isFast
                                ? AppColors.primary
                                : AppColors.outline,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Pengantaran Hemat',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: !isFast
                                              ? AppColors.primary
                                              : AppColors.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '35-45 min',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Rute gabungan optimal dan ramah lingkungan',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'GRATIS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                              Text(
                                '\$2.00',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeliverySpeedSection() {
    final isFast = _orderState.isFastDelivery;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.electric_moped_rounded,
                        color: Color(0xFFF57F17),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Pilihan Pengantaran',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFast
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFast ? 'Express ⚡' : 'Paling Hemat 🍃',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isFast ? const Color(0xFFE65100) : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Opsi 1: PENGANTARAN CEPAT (Disamping tulisan pengantaran cepat ada animasi lightning json)
          InkWell(
            onTap: () {
              _orderState.setFastDelivery(true);
              CapsuleToast.show(
                context,
                message: 'Pengantaran Cepat dipilih: Estimasi 15-20 menit ⚡',
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFFFB300),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFast
                    ? const Color(0xFFFFFDE7).withValues(alpha: 0.6)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFast
                      ? const Color(0xFFFFB300)
                      : AppColors.outlineVariant.withValues(alpha: 0.6),
                  width: isFast ? 1.8 : 1.0,
                ),
                boxShadow: isFast
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFB300)
                              .withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isFast
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isFast ? const Color(0xFFF57F17) : AppColors.outline,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Pengantaran Cepat',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isFast
                                      ? const Color(0xFFBF360C)
                                      : AppColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Animasi Lottie lightning.json tepat di samping tulisan Pengantaran Cepat
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: Lottie.asset(
                                'assets/animations/lightning.json',
                                fit: BoxFit.contain,
                                repeat: true,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.bolt_rounded,
                                      size: 22,
                                      color: Color(0xFFFFB300),
                                    ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF57F17)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '15-20 min',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Prioritas tanpa transit, makanan tiba hangat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$2.00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isFast
                              ? const Color(0xFFE65100)
                              : AppColors.onSurface,
                        ),
                      ),
                      Text(
                        '\$3.50',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Opsi 2: PENGANTARAN HEMAT
          InkWell(
            onTap: () {
              _orderState.setFastDelivery(false);
              CapsuleToast.show(
                context,
                message: 'Pengantaran Hemat dipilih: Ongkir GRATIS! 🍃',
                icon: Icons.eco_rounded,
                iconColor: AppColors.primary,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !isFast
                    ? const Color(0xFFE8F5E9).withValues(alpha: 0.5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !isFast
                      ? AppColors.primary
                      : AppColors.outlineVariant.withValues(alpha: 0.6),
                  width: !isFast ? 1.8 : 1.0,
                ),
                boxShadow: !isFast
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    !isFast
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: !isFast ? AppColors.primary : AppColors.outline,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Pengantaran Hemat',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: !isFast
                                      ? AppColors.primary
                                      : AppColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '35-45 min',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Rute gabungan optimal & ramah lingkungan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'GRATIS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        '\$2.00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreAndItemsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fastfood,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "McDonald's",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: AppColors.primary,
                                size: 15,
                              ),
                            ],
                          ),
                          Text(
                            'Ampang Point Outlet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Fast Prep',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orderState.cartItems.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 20, thickness: 0.5),
            itemBuilder: (context, index) {
              final item = _orderState.cartItems[index];

              return Dismissible(
                key: Key('cart_item_${item.id}_${item.quantity}'),
                direction: DismissDirection
                    .endToStart, // Swipe ke arah kiri untuk hapus
                background: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hapus Menu',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_sweep_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                onDismissed: (direction) {
                  final deletedTitle = item.title;
                  _orderState.removeItem(item.id);
                  CapsuleToast.show(
                    context,
                    icon: Icons.delete_sweep_rounded,
                    iconColor: AppColors.error,
                    title: '$deletedTitle Dihapus',
                    subtitle: 'Menu telah dikeluarkan dari keranjang',
                    bottomMargin: 84.0,
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: Image.asset(
                          item.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: AppColors.surfaceContainerLow,
                                child: const Icon(
                                  Icons.restaurant,
                                  color: AppColors.outline,
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${item.title} × ${item.quantity}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '\$${item.totalPrice.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _buildCustomChip(item.size),
                              ...item.addons.map((a) => _buildCustomChip(a)),
                              if (item.side != null)
                                _buildCustomChip(item.side!),
                              if (item.drink != null)
                                _buildCustomChip(item.drink!),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => _orderState.removeItem(item.id),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline,
                                      size: 15,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Hapus',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _orderState.updateQuantity(
                                        item.id,
                                        -1,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.remove,
                                          size: 14,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '${item.quantity}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _orderState.updateQuantity(
                                        item.id,
                                        1,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.add,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildVoucherSection() {
    final curVoucher = _orderState.currentVoucher;
    final discountPercentInt = (_orderState.voucherDiscountPercent * 100)
        .toInt();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showVoucherSelectionModal,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.confirmation_number_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                curVoucher?.title ?? 'Voucher Promo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$discountPercentInt% Diskon Aktif (${_orderState.selectedVoucher})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ganti',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Hemat $discountPercentInt% untuk pesanan ini',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '-\$${_orderState.discountAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
    );
  }

  Widget _buildPaymentMethodSection() {
    IconData icon;
    Color iconColor;
    String title;
    String subtitle;
    String badgeText;

    if (!_hasSelectedPayment) {
      icon = Icons.payment_rounded;
      iconColor = AppColors.primaryContainer;
      title = 'Pilih Metode Pembayaran';
      subtitle = 'Ketuk untuk memilih QRIS, Kartu Debit, E-Wallet, atau COD';
      badgeText = 'Pilih';
    } else {
      icon = _selectedPaymentIcon;
      iconColor = _selectedPaymentColor;
      title = _selectedPaymentTitle;
      subtitle = _selectedPaymentSubtitle;
      badgeText = 'Ubah';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: !_hasSelectedPayment
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.outlineVariant.withValues(alpha: 0.5),
          width: !_hasSelectedPayment ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showPaymentMethodSelector,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.outline,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBreakdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Subtotal Pesanan',
            '\$${_orderState.subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          if (_orderState.isDelivery) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _orderState.isFastDelivery
                              ? 'Biaya Pengantaran Cepat ⚡'
                              : 'Biaya Pengantaran Hemat 🍃',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppColors.outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    if (_orderState.isFastDelivery) ...[
                      Text(
                        '\$3.50',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '\$2.00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ] else ...[
                      Text(
                        '\$2.00',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GRATIS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildSummaryRow(
              _orderState.isFastDelivery
                  ? 'Diskon Ongkir Express'
                  : 'Diskon Ongkir (Promo Foodie)',
              _orderState.isFastDelivery ? '-\$1.50' : '-\$2.00',
              valueColor: AppColors.primary,
            ),
          ] else ...[
            _buildSummaryRow(
              'Biaya Pengantaran (Self pick-up)',
              'GRATIS',
              valueColor: AppColors.primary,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Biaya Layanan & Penanganan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Text(
                    '\$0.50',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'GRATIS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_orderState.voucherDiscountPercent > 0) ...[
            const SizedBox(height: 6),
            _buildSummaryRow(
              'Diskon Voucher (${_orderState.selectedVoucher})',
              '-\$${_orderState.discountAmount.toStringAsFixed(2)}',
              valueColor: AppColors.primary,
              isBold: true,
            ),
          ],
          const Divider(height: 20, thickness: 0.8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'Sudah termasuk pajak restoran',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${_orderState.grandTotal.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bar ringkas pilihan pengantaran cepat / hemat saat ingin checkout
            if (_orderState.isDelivery) ...[
              InkWell(
                onTap: _showDeliverySpeedModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _orderState.isFastDelivery
                        ? const Color(0xFFFFF8E1)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _orderState.isFastDelivery
                          ? const Color(0xFFFFB300).withValues(alpha: 0.6)
                          : AppColors.primary.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (_orderState.isFastDelivery) ...[
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Lottie.asset(
                                  'assets/animations/lightning.json',
                                  fit: BoxFit.contain,
                                  repeat: true,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.bolt_rounded,
                                        size: 18,
                                        color: Color(0xFFFFB300),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Pengantaran Cepat',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE65100),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE65100)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '15-20 min',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE65100),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Icon(
                                Icons.eco_rounded,
                                size: 18,
                                color: Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Pengantaran Hemat',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '35-45 min',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _orderState.isFastDelivery ? '+\$2.00' : 'GRATIS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _orderState.isFastDelivery
                              ? const Color(0xFFE65100)
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ubah',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ElevatedButton(
              onPressed: () {
                if (!_hasSelectedPayment) {
                  CapsuleToast.show(
                    context,
                    message: 'Pilih metode pembayaran dahulu!',
                    icon: Icons.payment_rounded,
                  );
                  _showPaymentMethodSelector();
                  return;
                }
                _proceedToCheckout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                elevation: 3,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Place order',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$${_orderState.grandTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dengan klik place order, Anda menyetujui Ketentuan Layanan Foodie.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
