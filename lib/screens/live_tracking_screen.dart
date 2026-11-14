import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/order_state.dart';
import '../theme/app_colors.dart';
import '../widgets/capsule_toast.dart';
import 'home_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String orderId;
  final bool showBackButton;

  const LiveTrackingScreen({
    super.key,
    this.orderId = '#FD-5096',
    this.showBackButton = true,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  final OrderState _orderState = OrderState.instance;

  // Real-time step index:
  // 0: Confirmed (Diterima) -> 2.0s
  // 1: Preparing (Dimasak)   -> 2.0s
  // 2: Pick Up (Diambil)     -> 2.0s
  // 3: On The Way (OTW)      -> 4.0s
  // 4: Arrived (Sampai)      -> Total 10.0s
  int _currentStep = 0;
  bool _isAutoPlaying = false;
  Timer? _autoPlayTimer;
  Timer? _searchDriverTimer;

  // State pencarian driver animasi awal
  bool _isSearchingDriver = true;
  bool _isUserInteracting = false;
  Timer? _interactionDebounceTimer;

  // Scooter movement animation along road network route (17.0 seconds for detailed winding scenic journey)
  late AnimationController _scooterController;
  late Animation<double> _scooterAnimation;

  // 2D Courier Motorcycle Vibration & Wheel Rotation Animations (pelan & smooth)
  late AnimationController _motorBounceController;
  late AnimationController _wheelRotationController;

  // Map interactive transformation & smooth gliding zoom controller
  late TransformationController _mapTransformationController;
  late AnimationController _mapZoomAnimationController;
  Animation<Matrix4>? _mapZoomAnimation;
  int _lastAnimatedAddressIndex = -1;
  Size _cachedViewportSize = const Size(390, 440);
  bool _hasInitializedMapTransform = false;

  @override
  void initState() {
    super.initState();
    _orderState.addListener(_onStateChange);

    // Map zoom & pan transformation controller
    _mapTransformationController = TransformationController();
    _mapZoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _mapZoomAnimationController.addListener(() {
      if (_mapZoomAnimation != null) {
        _mapTransformationController.value = _mapZoomAnimation!.value;
      }
    });

    // Posisikan kamera map ke lokasi awal
    _lastAnimatedAddressIndex = _orderState.selectedAddressIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animateCameraToLocation(
          _orderState.selectedAddressIndex,
          immediate: true,
        );
      }
    });

    // Perjalanan OTW motor kurir dibuat santai & realistis (17.0 detik) agar rute jalanan detail dinikmati
    _scooterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 17000),
    );

    _scooterAnimation = CurvedAnimation(
      parent: _scooterController,
      curve: Curves.easeInOutSine,
    );

    // Otomatis geser kamera mengikuti posisi driver saat OTW
    _scooterController.addListener(() {
      if (_currentStep == 3 && !_isUserInteracting && mounted) {
        _trackCameraToCurrentProgress();
      }
    });

    // Animasi suspensi motor kurir 2D pelan & smooth (750ms per siklus, tidak terlalu cepat)
    _motorBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    // Animasi putaran roda motor kurir 2D
    _wheelRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat();

    // Hanya auto-progress jika memang ada pesanan aktif
    if (_orderState.hasActiveOrder) {
      _currentStep = _orderState.orderStepIndex;
      _isSearchingDriver = _currentStep == 0;

      if (_isSearchingDriver) {
        _startSearchingDriverAnimation();
      } else {
        _initAutoProgression();
      }
    } else {
      _isSearchingDriver = false;
    }
  }

  void _startSearchingDriverAnimation() {
    if (!_orderState.hasActiveOrder) return;
    _searchDriverTimer?.cancel();
    _searchDriverTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() {
        _isSearchingDriver = false;
      });

      final addr = _orderState.currentAddressOption;
      CapsuleToast.show(
        context,
        icon: Icons.two_wheeler_rounded,
        title: 'Driver Ditemukan! 🛵',
        subtitle:
            '${addr.driverName} (${addr.driverVehicle}) siap mengambil pesanan',
        duration: const Duration(seconds: 5),
      );

      _initAutoProgression();
    });
  }

  void _initAutoProgression() {
    if (!_orderState.hasActiveOrder) return;
    if (_orderState.orderStepIndex < 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startAutoPlayProgression(fromStep: _currentStep);
      });
    }
  }

  @override
  void dispose() {
    _searchDriverTimer?.cancel();
    _autoPlayTimer?.cancel();
    _interactionDebounceTimer?.cancel();
    _scooterController.dispose();
    _motorBounceController.dispose();
    _wheelRotationController.dispose();
    _mapZoomAnimationController.dispose();
    _mapTransformationController.dispose();
    _orderState.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    if (_lastAnimatedAddressIndex != _orderState.selectedAddressIndex) {
      _lastAnimatedAddressIndex = _orderState.selectedAddressIndex;
      _isUserInteracting = false;
      _animateCameraToLocation(_orderState.selectedAddressIndex);
    }
    setState(() {});
  }

  Matrix4 _clampMatrix(Matrix4 matrix, double viewW, double viewH) {
    const baseW = 2048.0;
    const baseH = 2048.0;
    if (viewW <= 0 || viewH <= 0) return matrix;

    final minScale = math.max(viewW / baseW, viewH / baseH);
    const maxScale = 5.0;

    final currentScale = matrix.getMaxScaleOnAxis();
    final scale = currentScale.clamp(minScale, maxScale);
    final tx = matrix.storage[12];
    final ty = matrix.storage[13];

    final minTx = viewW - (baseW * scale);
    const maxTx = 0.0;
    final clampedTx = minTx <= maxTx ? tx.clamp(minTx, maxTx) : minTx / 2;

    final minTy = viewH - (baseH * scale);
    const maxTy = 0.0;
    final clampedTy = minTy <= maxTy ? ty.clamp(minTy, maxTy) : minTy / 2;

    return Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(clampedTx, clampedTy, 0.0);
  }

  // Otomatis menggeser kamera fokus ke arah driver & bergerak mulus menuju tujuan
  void _trackCameraToCurrentProgress() {
    final viewW = _cachedViewportSize.width;
    final viewH = _cachedViewportSize.height;
    if (viewW <= 0 || viewH <= 0) return;

    const baseMapSize = Size(2048, 2048);
    final waypoints = _getRouteWaypoints(
      baseMapSize,
      _orderState.selectedAddressIndex,
    );
    final routePath = _buildSmoothRoutePath(waypoints);
    final transform = _getScooterTransform(routePath, _scooterAnimation.value);
    final driverPos = transform.$1;

    final minScale = math.max(
      viewW / baseMapSize.width,
      viewH / baseMapSize.height,
    );
    // Zoom secukupnya: proporsional & nyaman dilihat, tidak terlalu dekat
    final scale = minScale * 1.35;

    final targetCenterX = viewW * 0.5;
    final targetCenterY = viewH * 0.36;

    final tx = targetCenterX - (driverPos.dx * scale);
    final ty = targetCenterY - (driverPos.dy * scale);

    final minTx = viewW - (baseMapSize.width * scale);
    const maxTx = 0.0;
    final clampedTx = minTx <= maxTx ? tx.clamp(minTx, maxTx) : minTx / 2;

    final minTy = viewH - (baseMapSize.height * scale);
    const maxTy = 0.0;
    final clampedTy = minTy <= maxTy ? ty.clamp(minTy, maxTy) : minTy / 2;

    _mapTransformationController.value = Matrix4.diagonal3Values(
      scale,
      scale,
      1.0,
    )..setTranslationRaw(clampedTx, clampedTy, 0.0);
  }

  Matrix4 _computeTargetMatrix({
    required int addressIndex,
    required double viewW,
    required double viewH,
  }) {
    const baseW = 2048.0;
    const baseH = 2048.0;

    // Scale secukupnya (tidak terlalu zoom, sekitar 1.35x dari cover screen)
    final fillScale = viewW / baseW;
    final fillScaleH = viewH / baseH;
    final minScale = math.max(fillScale, fillScaleH);
    final scale = minScale * 1.35;

    double fx, fy;
    if (_currentStep < 3) {
      // Fokus pada restoran asal saat pesanan diproses
      switch (addressIndex) {
        case 1: // Pizzeria (origin untuk Kantor)
          fx = 0.8445;
          fy = 0.5918;
          break;
        case 2: // Sushi Bar Selatan (origin untuk Apartemen)
          fx = 0.5845;
          fy = 0.8093;
          break;
        case 0: // Toko Burger (origin untuk Rumah)
        default:
          fx = 0.5464;
          fy = 0.4802;
          break;
      }
    } else if (_currentStep >= 4) {
      // Fokus pada lokasi tujuan saat pesanan telah sampai
      switch (addressIndex) {
        case 1: // Kantor
          fx = 0.5083;
          fy = 0.1294;
          break;
        case 2: // Apartemen
          fx = 0.5278;
          fy = 0.3967;
          break;
        case 0: // Rumah
        default:
          fx = 0.2690;
          fy = 0.4104;
          break;
      }
    } else {
      // Sedang OTW: fokus pada posisi motor kurir saat ini
      const baseMapSize = Size(baseW, baseH);
      final waypoints = _getRouteWaypoints(baseMapSize, addressIndex);
      final routePath = _buildSmoothRoutePath(waypoints);
      final transform = _getScooterTransform(
        routePath,
        _scooterAnimation.value,
      );
      fx = transform.$1.dx / baseW;
      fy = transform.$1.dy / baseH;
    }

    // Pusatkan ke area atas map yang terbuka di atas status card bottom sheet
    final targetCenterY = viewH * 0.36;
    final tx = (viewW / 2) - (fx * baseW * scale);
    final ty = targetCenterY - (fy * baseH * scale);

    // Kunci translasi agar tepi map selalu mentok dan tidak keluar batas layar
    final minTx = viewW - (baseW * scale);
    const maxTx = 0.0;
    final clampedTx = minTx <= maxTx ? tx.clamp(minTx, maxTx) : minTx / 2;

    final minTy = viewH - (baseH * scale);
    const maxTy = 0.0;
    final clampedTy = minTy <= maxTy ? ty.clamp(minTy, maxTy) : minTy / 2;

    return Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(clampedTx, clampedTy, 0.0);
  }

  void _animateCameraToLocation(
    int addressIndex, {
    bool immediate = false,
    Size? size,
  }) {
    _isUserInteracting = false;
    _interactionDebounceTimer?.cancel();

    final viewW = size?.width ?? _cachedViewportSize.width;
    final viewH = size?.height ?? _cachedViewportSize.height;
    if (viewW <= 0 || viewH <= 0) return;

    final target = _computeTargetMatrix(
      addressIndex: addressIndex,
      viewW: viewW,
      viewH: viewH,
    );

    if (immediate) {
      _mapTransformationController.value = target;
      return;
    }

    _mapZoomAnimation =
        Matrix4Tween(
          begin: _mapTransformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _mapZoomAnimationController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _mapZoomAnimationController.forward(from: 0.0);
  }

  void _zoomMap(double factor) {
    _isUserInteracting = true;
    _interactionDebounceTimer?.cancel();
    _interactionDebounceTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
        });
      }
    });

    final current = _mapTransformationController.value;
    final viewW = _cachedViewportSize.width;
    final viewH = _cachedViewportSize.height;
    if (viewW <= 0 || viewH <= 0) return;

    final center = Offset(viewW / 2, viewH / 2);
    final currentScale = current.getMaxScaleOnAxis();
    final minScale = math.max(viewW / 2048.0, viewH / 2048.0);
    const maxScale = 5.0;
    final targetScale = (currentScale * factor).clamp(minScale, maxScale);
    final effectiveFactor = targetScale / currentScale;

    final zoomMatrix =
        Matrix4.diagonal3Values(effectiveFactor, effectiveFactor, 1.0)
          ..setTranslationRaw(
            center.dx * (1.0 - effectiveFactor),
            center.dy * (1.0 - effectiveFactor),
            0.0,
          );
    final rawTarget = zoomMatrix * current;
    final clampedTarget = _clampMatrix(rawTarget, viewW, viewH);

    _mapZoomAnimation = Matrix4Tween(begin: current, end: clampedTarget)
        .animate(
          CurvedAnimation(
            parent: _mapZoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _mapZoomAnimationController.forward(from: 0.0);
  }

  void _startOtwAnimation() {
    _scooterController.reset();
    _scooterController.forward();
  }

  void _setStep(int step) {
    if (!mounted) return;
    setState(() {
      _currentStep = step;
      _orderState.setOrderStep(step);
    });

    if (step == 3) {
      _startOtwAnimation();
    } else if (step == 4) {
      _scooterController.value = 1.0;
      // Hanya tampilkan modal otomatis jika sedang di halaman tracking mandiri (showBackButton)
      if (widget.showBackButton) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showArrivedModal();
        });
      }
    } else {
      _scooterController.value = 0.0;
    }
  }

  /// Otomatis melangkah dari Diterima hingga Sampai dengan total durasi ~10 detik
  void _startAutoPlayProgression({int fromStep = 0}) {
    _autoPlayTimer?.cancel();
    _isAutoPlaying = true;
    _setStep(fromStep);

    void scheduleNext(int current) {
      if (!mounted || !_isAutoPlaying) return;

      int durationMs;
      if (current == 0) {
        durationMs = 3000; // Step 0 -> Step 1 (3.0 detik)
      } else if (current == 1) {
        durationMs = 3000; // Step 1 -> Step 2 (3.0 detik)
      } else if (current == 2) {
        durationMs = 3000; // Step 2 -> Step 3 (3.0 detik)
      } else if (current == 3) {
        durationMs =
            9000; // Step 3 OTW -> Step 4 Sampai (9.0 detik santai dan jelas)
      } else {
        _isAutoPlaying = false;
        return;
      }

      _autoPlayTimer = Timer(Duration(milliseconds: durationMs), () {
        if (!mounted || !_isAutoPlaying) return;
        final next = current + 1;
        _setStep(next);
        if (next < 4) {
          scheduleNext(next);
        } else {
          _isAutoPlaying = false;
        }
      });
    }

    scheduleNext(fromStep);
  }

  void _showAddressPickerModal() {
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
                    'Pilih Alamat Tujuan Demo',
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
                      'Rute & Driver Berbeda',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih salah satu alamat untuk melihat kurir, kendaraan, dan rute peta yang berbeda secara real-time.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(OrderState.demoAddressOptions.length, (idx) {
                final addr = OrderState.demoAddressOptions[idx];
                final isSel = _orderState.selectedAddressIndex == idx;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    _orderState.setAddressIndex(idx);
                    Navigator.of(ctx).pop();
                    _startAutoPlayProgression(fromStep: 0);
                    CapsuleToast.show(
                      context,
                      message:
                          'Rute & Kurir dialihkan ke: ${addr.title} (${addr.driverName})',
                      icon: Icons.alt_route_rounded,
                      duration: const Duration(seconds: 5),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFFE8F5E9)
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel
                            ? AppColors.primary
                            : AppColors.outlineVariant.withValues(alpha: 0.5),
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.primary
                                : AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            idx == 0
                                ? Icons.home_rounded
                                : (idx == 1
                                      ? Icons.business_rounded
                                      : Icons.apartment_rounded),
                            color: isSel
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
                                  if (isSel)
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
                                        'Aktif',
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
                                'Resto: ${addr.restaurantName} • Driver: ${addr.driverName} (${addr.driverVehicle})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSel
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSel ? AppColors.primary : AppColors.outline,
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

  // ==========================================
  // FITUR CHATTING DENGAN DRIVER
  // ==========================================
  void _showDriverChat() {
    final driver = _orderState.currentAddressOption;
    final textController = TextEditingController();
    final scrollController = ScrollController();

    final List<Map<String, dynamic>> messages = [
      {
        'isMe': false,
        'text':
            'Halo kak! Pesanan sedang disiapkan di ${driver.restaurantName} ya. Mohon ditunggu 🙏',
        'time': '10:14',
      },
      {
        'isMe': false,
        'text':
            'Saya sudah mengambil pesanan dan sekarang sedang menuju ke ${driver.title} (${driver.distance}) 🛵',
        'time': '10:16',
      },
    ];

    final quickChips = [
      'Tolong jangan dibunyikan bel ya',
      'Taruh di depan pagar/pintu',
      'Saya sudah tunggu di depan',
      'Hati-hati di jalan ya Pak 🙏',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void sendMessage(String text) {
              if (text.trim().isEmpty) return;
              final now = DateTime.now();
              final timeStr =
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

              setModalState(() {
                messages.add({
                  'isMe': true,
                  'text': text.trim(),
                  'time': timeStr,
                });
              });

              textController.clear();
              Future.delayed(const Duration(milliseconds: 100), () {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              });

              // Balasan otomatis cerdas dari driver
              Future.delayed(const Duration(milliseconds: 1200), () {
                if (!ctx.mounted) return;
                setModalState(() {
                  messages.add({
                    'isMe': false,
                    'text': 'Siap kak, terima kasih banyak atas informasinya! Segera saya antarkan dengan aman 👍🛵',
                    'time':
                        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  });
                });

                Future.delayed(const Duration(milliseconds: 100), () {
                  if (scrollController.hasClients) {
                    scrollController.animateTo(
                      scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                });
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // Header Bar Drag Handle
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Driver Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              const CircleAvatar(
                                radius: 22,
                                backgroundImage: AssetImage(
                                  'assets/images/rider.png',
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      driver.driverName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Online',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${driver.driverVehicle} • Plat ${driver.driverPlate}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20, thickness: 0.8),

                    // Chat Messages List
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, idx) {
                          final msg = messages[idx];
                          final isMe = msg['isMe'] as bool;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primaryContainer
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['text'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: isMe
                                          ? Colors.white
                                          : AppColors.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msg['time'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9.5,
                                          color: isMe
                                              ? Colors.white.withValues(
                                                  alpha: 0.75,
                                                )
                                              : AppColors.outline,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.done_all,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Quick Chips Suggestions
                    Container(
                      height: 36,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: quickChips.length,
                        itemBuilder: (context, idx) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(
                                quickChips[idx],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: const Color(0xFFF1F8F2),
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onPressed: () => sendMessage(quickChips[idx]),
                            ),
                          );
                        },
                      ),
                    ),

                    // Input Field & Send Button
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: textController,
                                decoration: const InputDecoration(
                                  hintText: 'Tulis pesan ke driver...',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                ),
                                onSubmitted: sendMessage,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () => sendMessage(textController.text),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // FITUR MEMBERIKAN ULASAN PADA DRIVER DAN RESTO
  // ==========================================
  void _showArrivedModal() {
    _showRatingAndReviewModal();
  }

  void _showRatingAndReviewModal() {
    final driver = _orderState.currentAddressOption;
    int driverRating = 5;
    int restoRating = 5;
    final Set<String> driverTags = {'Pengantaran Cepat ⚡', 'Ramah & Sopan 😊'};
    final Set<String> restoTags = {'Rasa Juara 😋', 'Porsi Pas 🍱'};

    final driverAvailableTags = [
      'Pengantaran Cepat ⚡',
      'Ramah & Sopan 😊',
      'Makanan Aman & Hangat 🍲',
      'Patuhi Rute 🗺️',
    ];

    final restoAvailableTags = [
      'Rasa Juara 😋',
      'Porsi Pas 🍱',
      'Kemasan Rapi 📦',
      'Masih Panas & Segar ♨️',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Beri Ulasan Pesanan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.8),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. ULASAN DRIVER
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 20,
                                      backgroundImage: AssetImage(
                                        'assets/images/rider.png',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Driver: ${driver.driverName}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                          Text(
                                            '${driver.driverVehicle} • ${driver.driverPlate}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Bagaimana pelayanan pengantaran kurir?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Bintang Driver
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (idx) {
                                    final starVal = idx + 1;
                                    return IconButton(
                                      onPressed: () {
                                        setModalState(() {
                                          driverRating = starVal;
                                        });
                                      },
                                      icon: Icon(
                                        starVal <= driverRating
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: Colors.amber,
                                        size: 34,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),

                                // Chips Apresiasi Driver
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.center,
                                  children: driverAvailableTags.map((tag) {
                                    final isSelected = driverTags.contains(tag);
                                    return FilterChip(
                                      label: Text(
                                        tag,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFFE8F5E9),
                                      checkmarkColor: AppColors.primary,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          if (selected) {
                                            driverTags.add(tag);
                                          } else {
                                            driverTags.remove(tag);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 2. ULASAN RESTORAN & MAKANAN
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE8F5E9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.restaurant,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Restoran: ${driver.restaurantName}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                          Text(
                                            'McChicken Deluxe Burger Meal',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Bagaimana kualitas dan rasa hidangan?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Bintang Resto
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (idx) {
                                    final starVal = idx + 1;
                                    return IconButton(
                                      onPressed: () {
                                        setModalState(() {
                                          restoRating = starVal;
                                        });
                                      },
                                      icon: Icon(
                                        starVal <= restoRating
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: Colors.amber,
                                        size: 34,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),

                                // Chips Apresiasi Resto
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.center,
                                  children: restoAvailableTags.map((tag) {
                                    final isSelected = restoTags.contains(tag);
                                    return FilterChip(
                                      label: Text(
                                        tag,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFFE8F5E9),
                                      checkmarkColor: AppColors.primary,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          if (selected) {
                                            restoTags.add(tag);
                                          } else {
                                            restoTags.remove(tag);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Submit Button
                  Container(
                    padding: const EdgeInsets.all(16),
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
                      onPressed: () {
                        Navigator.of(context).pop(); // Tutup modal ulasan
                        _orderState.completeOrder();

                        CapsuleToast.show(
                          context,
                          message: 'Ulasan berhasil dikirim! Terima kasih atas penilaian Anda ⭐',
                          icon: Icons.star_rounded,
                          duration: const Duration(seconds: 5),
                        );

                        // Balik ke halaman menu (HomeScreen)
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: Text(
                        'Kirim Ulasan & Penilaian',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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

  @override
  Widget build(BuildContext context) {
    if (!_orderState.hasActiveOrder) {
      return _buildEmptyOrderView();
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Map interaktif di latar belakang (bebas digeser & di-zoom tanpa terhalang)
          Positioned.fill(child: _buildInteractiveMapArea()),

          // 2. Konten detail yang menutupi map saat ditarik/di-scroll ke atas (DraggableScrollableSheet)
          DraggableScrollableSheet(
            initialChildSize: 0.44,
            minChildSize: 0.30,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: const [0.30, 0.44, 0.88],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 12),
                    // Pull Handle
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildStatusProgressCard(),
                    const SizedBox(height: 14),
                    _buildDriverProfileCard(),
                    const SizedBox(height: 14),
                    _buildOrderItemsCard(),
                    const SizedBox(height: 18),
                    _buildFinishButton(),
                    SizedBox(height: widget.showBackButton ? 40 : 130),
                  ],
                ),
              );
            },
          ),

          // 3. Kode Orderan Saja di Tengah Atas Bentuk Kapsul Glasses
          _buildTopGlassesCapsuleBar(topPadding),
        ],
      ),
    );
  }

  Widget _buildTopGlassesCapsuleBar(double topPadding) {
    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tombol Kembali Glassmorphic (jika showBackButton)
          if (widget.showBackButton)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.20),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.65),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 44),

          // Kode Orderan Saja di Tengah Atas Bentuk Kapsul Glasses
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.58),
                      Colors.white.withValues(alpha: 0.22),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.70),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: -1,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentStep >= 4
                            ? AppColors.primary
                            : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_currentStep >= 4
                                        ? AppColors.primary
                                        : const Color(0xFFF59E0B))
                                    .withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _orderState.activeOrderId.isNotEmpty
                          ? _orderState.activeOrderId
                          : widget.orderId,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tombol Alihkan Alamat / Rute Glassmorphic
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: InkWell(
                onTap: _showAddressPickerModal,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.20),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.alt_route_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrderView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            if (widget.showBackButton)
              Positioned(
                top: 14,
                left: 16,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.moped_rounded,
                          size: 54,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Oopps, belum ada makanan yang di pesan',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Yuk pilih menu favoritmu di beranda dan lakukan pemesanan untuk melacak posisi kurir secara real-time di sini.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (widget.showBackButton) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                      label: Text(
                        'Pesan Makanan Sekarang',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
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
    );
  }

  // ==========================================
  // REALISTIC STREET ROUTE WAYPOINTS & GEOMETRY
  // Rute detail jalanan berkelok (muter-muter) mengikuti grafis jalan di peta.jpg
  // ==========================================
  List<Offset> _getRouteWaypoints(Size size, int addressIndex) {
    final w = size.width;
    final h = size.height;

    switch (addressIndex) {
      case 1: // Kantor (Sudirman) from Pizzeria — keluar timur, susuri ring road luar, lewati jembatan utara, masuk kawasan gedung perkantoran
        return [
          Offset(w * 0.8445, h * 0.5918), // 1  Pizzeria (origin timur)
          Offset(w * 0.8250, h * 0.5750), // 2  keluar Pizzeria ke jalan utama
          Offset(w * 0.8050, h * 0.5500), // 3  jalan raya timur arah barat laut
          Offset(w * 0.7850, h * 0.5180), // 4  melintas simpang timur
          Offset(w * 0.7620, h * 0.4780), // 5  masuk ring road timur
          Offset(w * 0.7420, h * 0.4350), // 6  menyusuri jalur cepat ring road
          Offset(w * 0.7280, h * 0.3880), // 7  melewati kawasan komersial timur
          Offset(w * 0.7100, h * 0.3420), // 8  melengkung ke arah barat laut
          Offset(w * 0.6800, h * 0.3050), // 9  tikungan besar ring road utara
          Offset(
            w * 0.6450,
            h * 0.2800,
          ), // 10 melintasi kawasan industri kuning
          Offset(w * 0.6050, h * 0.2680), // 11 jalan lingkar utara
          Offset(w * 0.5680, h * 0.2720), // 12 mendekati bundaran pusat utara
          Offset(w * 0.5450, h * 0.2600), // 13 keluar bundaran arah utara
          Offset(w * 0.5360, h * 0.2300), // 14 naik jalan layang jembatan
          Offset(
            w * 0.5280,
            h * 0.1950,
          ), // 15 menyeberang jalan layang sungai utara
          Offset(
            w * 0.5200,
            h * 0.1600,
          ), // 16 masuk kawasan perkantoran Sudirman
          Offset(w * 0.5120, h * 0.1420), // 17 bundaran plaza gedung Kantor
          Offset(
            w * 0.5083,
            h * 0.1294,
          ), // 18 Kantor Sudirman (destinasi utara)
        ];
      case 2: // Apartemen (Menteng) from Sushi Bar Selatan — lewati jalan pemukiman selatan, danau tengah, shopping street, dan high-rise towers
        return [
          Offset(w * 0.5845, h * 0.8093), // 1  Sushi Bar Selatan (origin)
          Offset(w * 0.5680, h * 0.7850), // 2  keluar Sushi Bar ke barat laut
          Offset(w * 0.5480, h * 0.7650), // 3  memutar blok perumahan selatan
          Offset(w * 0.5250, h * 0.7720), // 4  tikungan barat pemukiman
          Offset(w * 0.5100, h * 0.7450), // 5  jalan utama selatan ke utara
          Offset(w * 0.5180, h * 0.7100), // 6  lurus ke utara
          Offset(
            w * 0.5400,
            h * 0.6750,
          ), // 7  masuk jalan melengkung danau tengah
          Offset(
            w * 0.5650,
            h * 0.6550,
          ), // 8  melewati taman & Sushi Bar Tengah
          Offset(w * 0.5876, h * 0.6494), // 9  melintas depan Sushi Bar Tengah
          Offset(w * 0.5750, h * 0.6120), // 10 menuju boulevard tengah
          Offset(
            w * 0.5520,
            h * 0.5750,
          ), // 11 naik ke jalan komersial pertokoan
          Offset(w * 0.5350, h * 0.5350), // 12 melewati pusat kota
          Offset(w * 0.525, h * 0.4950), // 13 lurus sepanjang avenue tengah
          Offset(
            w * 0.5220,
            h * 0.4550,
          ), // 14 mendekati gedung-gedung pencakar langit
          Offset(w * 0.5180, h * 0.4220), // 15 masuk jalan arteri Apartemen
          Offset(w * 0.5230, h * 0.4080), // 16 putaran lobi Apartemen
          Offset(w * 0.5278, h * 0.3967), // 17 Apartemen Menteng (destinasi)
        ];
      case 0: // Home (Rumah) from Toko Burger — rute detail panjang berkelok melewati boulevard selatan, ring road, tepi sungai, jembatan, taman barat
      default:
        return [
          Offset(w * 0.5464, h * 0.4802), // 1  Toko Burger (origin)
          Offset(w * 0.5450, h * 0.5050), // 2  jalan keluar ke selatan
          Offset(w * 0.5360, h * 0.5320), // 3  mengikuti boulevard selatan
          Offset(w * 0.5240, h * 0.5600), // 4  melewati persimpangan komersial
          Offset(w * 0.5060, h * 0.5850), // 5  belok serong barat daya
          Offset(w * 0.4850, h * 0.6120), // 6  mendekati jalur lingkar selatan
          Offset(
            w * 0.4580,
            h * 0.6300,
          ), // 7  masuk ke jalur lingkar (ring road)
          Offset(w * 0.4300, h * 0.6360), // 8  menyusuri bundaran lingkar bawah
          Offset(
            w * 0.4020,
            h * 0.6250,
          ), // 9  berbelok melengkung ke barat laut
          Offset(w * 0.3800, h * 0.5980), // 10 melewati kawasan taman barat
          Offset(
            w * 0.3640,
            h * 0.5650,
          ), // 11 melintasi persimpangan tepian sungai
          Offset(
            w * 0.3550,
            h * 0.5300,
          ), // 12 jalan tepi sungai (riverbank avenue)
          Offset(w * 0.3500, h * 0.4900), // 13 lurus ke utara di tepi sungai
          Offset(w * 0.3540, h * 0.4500), // 14 mendekati jembatan sungai besar
          Offset(w * 0.3600, h * 0.4200), // 15 tikungan masuk ke jembatan
          Offset(w * 0.3700, h * 0.4020), // 16 masuk jembatan
          Offset(
            w * 0.3950,
            h * 0.3980,
          ), // 17 menyeberang jembatan sungai ke arah barat
          Offset(w * 0.4180, h * 0.4050), // 18 ujung barat jembatan
          Offset(w * 0.4400, h * 0.4000), // 19 turun jembatan
          Offset(
            w * 0.4480,
            h * 0.3750,
          ), // 20 berputar ke jalan lingkar pemukiman
          Offset(
            w * 0.4300,
            h * 0.3450,
          ), // 21 mengelilingi blok perumahan hijau
          Offset(w * 0.3950, h * 0.3350), // 22 jalan lingkar barat laut
          Offset(w * 0.3550, h * 0.3450), // 23 melintas jalan taman asri
          Offset(w * 0.3200, h * 0.3600), // 24 masuk koridor perumahan barat
          Offset(
            w * 0.2920,
            h * 0.3820,
          ), // 25 belok ke jalan utama lingkungan Rumah
          Offset(w * 0.2780, h * 0.3980), // 26 gang masuk komplek
          Offset(w * 0.2690, h * 0.4104), // 27 Tiba di Rumah (destinasi)!
        ];
    }
  }

  Path _buildSmoothRoutePath(
    List<Offset> points, {
    double cornerRadius = 18.0,
  }) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points[0].dx, points[0].dy);
      return path;
    }
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length - 1; i++) {
      final pPrev = points[i - 1];
      final pCurr = points[i];
      final pNext = points[i + 1];

      final v1 = pPrev - pCurr;
      final v2 = pNext - pCurr;
      final d1 = v1.distance;
      final d2 = v2.distance;
      if (d1 == 0 || d2 == 0) continue;
      final r = math.min(cornerRadius, math.min(d1 / 2, d2 / 2));

      final pStart = pCurr + (v1 / d1) * r;
      final pEnd = pCurr + (v2 / d2) * r;

      path.lineTo(pStart.dx, pStart.dy);
      path.quadraticBezierTo(pCurr.dx, pCurr.dy, pEnd.dx, pEnd.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  double _lastValidHeadingAngle = 0.0;

  (Offset, double) _getScooterTransform(Path path, double t) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return (Offset.zero, _lastValidHeadingAngle);
    final metric = metrics.first;
    if (metric.length <= 0) return (Offset.zero, _lastValidHeadingAngle);

    final clampedDistance = (metric.length * t).clamp(0.0, metric.length);
    final tangent = metric.getTangentForOffset(clampedDistance);
    if (tangent == null) return (Offset.zero, _lastValidHeadingAngle);

    // Sampel look-ahead (+4.0px dan -4.0px) untuk menentukan vektor arah maju pasti
    final sampleAhead = (clampedDistance + 4.0).clamp(0.0, metric.length);
    final sampleBehind = (clampedDistance - 4.0).clamp(0.0, metric.length);

    final posAhead =
        metric.getTangentForOffset(sampleAhead)?.position ?? tangent.position;
    final posBehind =
        metric.getTangentForOffset(sampleBehind)?.position ?? tangent.position;

    final forwardVector = posAhead - posBehind;
    if (forwardVector.distance > 0.02) {
      _lastValidHeadingAngle = math.atan2(forwardVector.dy, forwardVector.dx);
    }

    return (tangent.position, _lastValidHeadingAngle);
  }

  // ==========================================
  // INTERACTIVE ACCURATE MAP WITH DYNAMIC ROUTE
  // ==========================================
  Widget _buildInteractiveMapArea() {
    final addressIndex = _orderState.selectedAddressIndex;
    const baseMapSize = Size(2048, 2048);
    final waypoints = _getRouteWaypoints(baseMapSize, addressIndex);
    final routePath = _buildSmoothRoutePath(waypoints);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight > 0 ? constraints.maxHeight : 440.0;

        // Auto-center kamera pada frame pertama setelah viewport diukur
        if (viewW > 0 &&
            viewH > 0 &&
            (!_hasInitializedMapTransform ||
                _cachedViewportSize != Size(viewW, viewH))) {
          _cachedViewportSize = Size(viewW, viewH);
          if (!_hasInitializedMapTransform) {
            _hasInitializedMapTransform = true;
            _mapTransformationController.value = _computeTargetMatrix(
              addressIndex: addressIndex,
              viewW: viewW,
              viewH: viewH,
            );
          } else if (!_isUserInteracting) {
            // Menjaga map selalu berada di dalam batasan saat layar berubah ukuran
            _mapTransformationController.value = _clampMatrix(
              _mapTransformationController.value,
              viewW,
              viewH,
            );
          }
        }

        final double minMapScale = (viewW > 0 && viewH > 0)
            ? math.max(viewW / baseMapSize.width, viewH / baseMapSize.height)
            : 1.0;

        return Stack(
          children: [
            // Map interaktif dengan batasan ketat (jika sudah mentok tidak bisa digeser lagi)
            InteractiveViewer(
              transformationController: _mapTransformationController,
              constrained: false,
              panAxis: PanAxis.free,
              boundaryMargin: EdgeInsets.zero,
              minScale: minMapScale,
              maxScale: 5.0,
              clipBehavior: Clip.hardEdge,
              onInteractionStart: (_) {
                _isUserInteracting = true;
                _interactionDebounceTimer?.cancel();
              },
              onInteractionEnd: (_) {
                _interactionDebounceTimer?.cancel();
                _interactionDebounceTimer = Timer(
                  const Duration(milliseconds: 3200),
                  () {
                    if (mounted) {
                      setState(() {
                        _isUserInteracting = false;
                      });
                    }
                  },
                );
              },
              child: SizedBox(
                width: 2048,
                height: 2048,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Peta Baru HD Square (assets/images/peta.jpg)
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/peta.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(
                              'assets/images/foodie_custom_map.jpg',
                              fit: BoxFit.cover,
                            ),
                      ),
                    ),

                    // Dynamic Custom Road Network Route
                    AnimatedBuilder(
                      animation: _scooterAnimation,
                      builder: (context, child) {
                        double progress = 0.0;
                        if (_currentStep < 3) {
                          progress = 0.0;
                        } else if (_currentStep == 3) {
                          progress = _scooterAnimation.value;
                        } else {
                          progress = 1.0;
                        }

                        return CustomPaint(
                          size: baseMapSize,
                          painter: _DynamicRoutePathPainter(
                            path: routePath,
                            progress: progress,
                          ),
                        );
                      },
                    ),

                    // Animasi 2D Kurir Naik Motor melintas di atas aspal jalan
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _scooterAnimation,
                        _motorBounceController,
                        _wheelRotationController,
                      ]),
                      builder: (context, child) {
                        double t = 0.0;
                        if (_currentStep < 3) {
                          t = 0.0;
                        } else if (_currentStep == 3) {
                          t = _scooterAnimation.value;
                        } else {
                          t = 1.0;
                        }

                        final transform = _getScooterTransform(routePath, t);
                        final pos = transform.$1;
                        final angle = transform.$2;
                        final bool isMoving = _currentStep == 3;

                        return Positioned(
                          left: pos.dx - 32,
                          top: pos.dy - 34,
                          child: _build2DCourierMotorcycle(
                            angle: angle,
                            isMoving: isMoving,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Subtle ambient gradient overlay
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 120,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating Controls: Zoom In, Zoom Out, & Pusatkan Rute (Kanan Atas)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _zoomMap(1.25),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(
                              Icons.add_rounded,
                              color: AppColors.onSurface,
                              size: 20,
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 1,
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        InkWell(
                          onTap: () => _zoomMap(0.8),
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(
                              Icons.remove_rounded,
                              color: AppColors.onSurface,
                              size: 20,
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 1,
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        InkWell(
                          onTap: () => _animateCameraToLocation(
                            _orderState.selectedAddressIndex,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(22),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(
                              Icons.my_location_rounded,
                              color: AppColors.primary,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _build2DCourierMotorcycle({
    required double angle,
    required bool isMoving,
  }) {
    // Menghadap kiri jika cos(angle) < 0
    final bool isFacingLeft = math.cos(angle) < 0;
    // Kemiringan motor halus (tilt) mengikuti tanjakan/turunan jalan
    final double tiltAngle = (math.sin(angle) * (isFacingLeft ? -0.22 : 0.22))
        .clamp(-0.25, 0.25);

    // Animasi lompatan suspensi motor kurir (pelan, santai & smooth)
    final double hopBounce = isMoving
        ? -(math.sin(_motorBounceController.value * math.pi).abs() * 3.0)
        : -(math.sin(_motorBounceController.value * math.pi).abs() * 0.8);

    // Sedikit ayunan pitch/tilt halus saat suspensi motor melompat pelan
    final double hopTilt = isMoving
        ? (math.sin(_motorBounceController.value * math.pi * 2) *
              0.02 *
              (isFacingLeft ? -1.0 : 1.0))
        : 0.0;
    final double dynamicTilt = tiltAngle + hopTilt;

    // Bayangan aspal merespons ayunan suspensi secara halus
    final double shadowScale = isMoving
        ? (1.0 - (hopBounce.abs() / 24.0)).clamp(0.75, 1.0)
        : 1.0;
    final double shadowOpacity = isMoving
        ? (0.26 - (hopBounce.abs() / 50.0)).clamp(0.15, 0.26)
        : 0.24;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 2. Bayangan Motor di Aspal (Ground Shadow) yang merespons lompatan
        Positioned(
          bottom: 12,
          child: Transform.scale(
            scaleX: shadowScale,
            scaleY: shadowScale * 0.9,
            child: Container(
              width: 44,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: shadowOpacity),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        // 3. Karakter 2D Kurir Naik Motor dengan lompatan melompat-lompat dan orientasi hadap
        Transform.translate(
          offset: Offset(0, hopBounce),
          child: Transform.scale(
            scaleX: isFacingLeft ? -1.0 : 1.0,
            child: Transform.rotate(
              angle: dynamicTilt,
              child: CustomPaint(
                size: const Size(64, 48),
                painter: _Courier2DMotorcyclePainter(
                  wheelAngle: _wheelRotationController.value * 2 * math.pi,
                  isMoving: isMoving,
                  bounceProgress: _motorBounceController.value,
                ),
              ),
            ),
          ),
        ),

        // 4. Badge Status Kurir Melayang yang ikut melompat selaras dengan motor
        Positioned(
          bottom: -4 + hopBounce * 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.two_wheeler_rounded,
                  color: Colors.white,
                  size: 9.5,
                ),
                const SizedBox(width: 3),
                Text(
                  isMoving
                      ? 'Kurir OTW ⚡'
                      : (_currentStep >= 4 ? 'Sampai 🎉' : 'Kurir Siap'),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PROGRESS STEP CARD
  // ==========================================
  Widget _buildStatusProgressCard() {
    final addr = _orderState.currentAddressOption;
    final hasActive = _orderState.hasActiveOrder;

    String statusTitle;
    String statusSubtitle;
    String eta;
    IconData statusIcon;

    if (!hasActive) {
      statusTitle = 'Motor Siaga (Standby)';
      statusSubtitle = 'Tidak ada orderan aktif. Motor kurir diam di pangkalan menunggu transaksi pesanan baru Anda.';
      eta = 'Motor Diam (Siaga)';
      statusIcon = Icons.two_wheeler_outlined;
    } else if (_isSearchingDriver) {
      statusTitle = 'Mencari Driver Terdekat...';
      statusSubtitle =
          'Sistem sedang mencocokkan kurir terdekat dengan restoran ${addr.restaurantName}.';
      eta = 'Mencari...';
      statusIcon = Icons.radar_rounded;
    } else {
      switch (_currentStep) {
        case 0:
          statusTitle = 'Driver Menuju Resto';
          statusSubtitle =
              '${addr.driverName} sedang menuju ${addr.restaurantName} untuk mengambil pesananmu.';
          eta = '25 - 30 Menit';
          statusIcon = Icons.two_wheeler_rounded;
          break;
        case 1:
          statusTitle = 'Sedang Dimasak';
          statusSubtitle =
              'Koki sedang meracik hidangan segar dengan standar higienis.';
          eta = '20 - 25 Menit';
          statusIcon = Icons.kitchen;
          break;
        case 2:
          statusTitle = 'Driver Mengambil';
          statusSubtitle =
              '${addr.driverName} sudah sampai di resto & mengambil pesanan.';
          eta = '15 - 20 Menit';
          statusIcon = Icons.storefront;
          break;
        case 3:
          statusTitle = 'Sedang Diantar (OTW)';
          statusSubtitle =
              '${addr.driverName} melaju menuju ${addr.title} (${addr.distance}).';
          eta = addr.estimatedTime;
          statusIcon = Icons.moped;
          break;
        case 4:
        default:
          statusTitle = 'Pesanan Telah Tiba! 🎉';
          statusSubtitle =
              'Driver sudah berada di lokasi tujuanmu (${addr.fullAddress}).';
          eta = 'Tiba Sekarang';
          statusIcon = Icons.check_circle;
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perkiraan Waktu Tiba',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      eta,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: AppColors.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      statusTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusSubtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // 4-step Horizontal Progress Track
          Row(
            children: [
              _buildStepNode(0, 'Diterima', Icons.receipt),
              _buildStepLine(0),
              _buildStepNode(1, 'Dimasak', Icons.kitchen),
              _buildStepLine(1),
              _buildStepNode(2, 'Diambil', Icons.shopping_bag),
              _buildStepLine(2),
              _buildStepNode(3, 'Diantar', Icons.moped),
              _buildStepLine(3),
              _buildStepNode(4, 'Sampai', Icons.home),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String label, IconData icon) {
    final isDone = index < _currentStep;
    final isActive = index == _currentStep;

    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDone || isActive
                ? AppColors.primaryContainer
                : AppColors.surfaceContainerHigh,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isDone ? Icons.check : icon,
            color: isDone || isActive ? Colors.white : AppColors.outline,
            size: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int leftIndex) {
    final isDone = leftIndex < _currentStep;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 12),
        color: isDone
            ? AppColors.primaryContainer
            : AppColors.surfaceContainerHigh,
      ),
    );
  }

  // ==========================================
  // DRIVER PROFILE CARD (DYNAMIC PER ADDRESS)
  // ==========================================
  Widget _buildDriverProfileCard() {
    final driver = _orderState.currentAddressOption;

    if (_isSearchingDriver) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mencari Driver Terdekat...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mencocokkan kurir di radius restoran...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Image.asset(
                      'assets/images/rider.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/rider (2).png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(
                              'assets/images/tracking_asset_3.jpg',
                              fit: BoxFit.cover,
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
                      Text(
                        driver.driverName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${driver.driverVehicle} • ${driver.driverPlate}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            driver.driverRating,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _showDriverChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F5E9),
                  foregroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: () {
                  CapsuleToast.show(
                    context,
                    message:
                        'Menghubungi Driver ${driver.driverName} (${driver.driverPhone})...',
                    icon: Icons.phone_forwarded_rounded,
                  );
                },
                icon: const Icon(Icons.call, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ORDER ITEMS CARD
  // ==========================================
  Widget _buildOrderItemsCard() {
    final driver = _orderState.currentAddressOption;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
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
                child: Text(
                  'Pesanan dari ${driver.restaurantName}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '1 Menu',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Image.asset(
                    'assets/images/mcchicken_hero.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1x McChicken Deluxe Burger',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Regular • Extra Cheese • Fries • Iced Tea',
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
              Text(
                '\$${_orderState.subtotal > 0 ? _orderState.subtotal.toStringAsFixed(2) : '16.09'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 10),

          // Detail Rincian Biaya & Diskon
          _buildTrackingPriceRow(
            'Subtotal Pesanan',
            '\$${_orderState.subtotal > 0 ? _orderState.subtotal.toStringAsFixed(2) : '16.09'}',
          ),
          const SizedBox(height: 5),
          _buildTrackingPriceRow(
            'Biaya Pengantaran (Ongkir)',
            '\$2.00 (Gratis Promo)',
            valueColor: AppColors.primary,
          ),
          const SizedBox(height: 5),
          _buildTrackingPriceRow(
            'Diskon Ongkir (Promo Foodie)',
            '-\$2.00',
            valueColor: AppColors.primary,
          ),
          const SizedBox(height: 5),
          _buildTrackingPriceRow(
            'Biaya Layanan & Penanganan',
            '\$0.50 (Gratis Promo)',
            valueColor: AppColors.primary,
          ),
          const SizedBox(height: 5),
          _buildTrackingPriceRow(
            'Diskon Biaya Layanan',
            '-\$0.50',
            valueColor: AppColors.primary,
          ),

          if (_orderState.voucherDiscountPercent > 0) ...[
            const SizedBox(height: 5),
            _buildTrackingPriceRow(
              'Diskon Voucher (${_orderState.selectedVoucher})',
              '-\$${_orderState.discountAmount.toStringAsFixed(2)}',
              valueColor: AppColors.primary,
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Pembayaran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '\$${_orderState.grandTotal > 0 ? _orderState.grandTotal.toStringAsFixed(2) : '11.26'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
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

  Widget _buildTrackingPriceRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildFinishButton() {
    // Sembunyikan konfirmasi diterima jika pesanan belum sampai di lokasi (_currentStep < 4)
    if (_currentStep < 4) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.moped_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pesanan Sedang Diproses',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tombol konfirmasi penerimaan akan aktif setelah pesanan tiba di lokasimu.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _showRatingAndReviewModal,
      icon: const Icon(Icons.check_circle_rounded, size: 20),
      label: Text(
        'Konfirmasi & Beri Ulasan',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        elevation: 3,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    );
  }
}

// ==========================================
// DYNAMIC ROUTE PAINTER (ROAD NETWORK PATH)
// ==========================================
class _DynamicRoutePathPainter extends CustomPainter {
  final Path path;
  final double progress;

  _DynamicRoutePathPainter({required this.path, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Road shadow/casing for elevation & contrast on map
    final casingPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, casingPaint);

    // 2. Light planned road route outline
    final glowPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    final bgRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, bgRoadPaint);

    // 3. Traveled active green road segment
    if (progress > 0) {
      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.first;
        final extractLen = (metric.length * progress).clamp(0.0, metric.length);
        if (extractLen > 0) {
          final traveledPath = metric.extractPath(0.0, extractLen);

          final activePaint = Paint()
            ..color = const Color(0xFF0D631B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

          canvas.drawPath(traveledPath, activePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicRoutePathPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.path != path;
  }
}

/// Custom Painter Ilustrasi & Animasi 2D Kurir Naik Motor yang Hidup
class _Courier2DMotorcyclePainter extends CustomPainter {
  final double wheelAngle;
  final bool isMoving;
  final double bounceProgress;

  _Courier2DMotorcyclePainter({
    required this.wheelAngle,
    required this.isMoving,
    required this.bounceProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ukuran kanvas kurir motor 2D: 64 x 48
    // Efek suspensi getar vertikal naik-turun halus
    final double bounceY = isMoving
        ? math.sin(bounceProgress * math.pi * 2) * 1.6
        : math.sin(bounceProgress * math.pi * 2) * 0.5;

    // 1. Sorotan Lampu Depan (Headlight Beam Glow)
    final headlightPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x80FFF59D), Colors.transparent],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(50, 16 + bounceY, 26, 20));
    final beamPath = Path()
      ..moveTo(49, 22 + bounceY)
      ..lineTo(74, 13 + bounceY)
      ..lineTo(74, 33 + bounceY)
      ..close();
    canvas.drawPath(beamPath, headlightPaint);

    // 2. Partikel Asap Knalpot saat motor melaju OTW
    if (isMoving) {
      final smokePaint1 = Paint()..color = Colors.black.withValues(alpha: 0.22);
      final smokePaint2 = Paint()..color = Colors.black.withValues(alpha: 0.12);
      canvas.drawCircle(
        Offset(4 - (bounceProgress * 5), 37 + bounceY),
        2.5 + (bounceProgress * 1.5),
        smokePaint1,
      );
      canvas.drawCircle(
        Offset(-2 - (bounceProgress * 7), 35 + bounceY),
        2.0 + (bounceProgress * 1.2),
        smokePaint2,
      );
    }

    // 3. Knalpot Motor (Chrome Exhaust Pipe)
    final exhaustPaint = Paint()..color = const Color(0xFF78909C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 34 + bounceY, 18, 5.0),
        const Radius.circular(2.5),
      ),
      exhaustPaint,
    );
    canvas.drawCircle(
      Offset(9.5, 36.5 + bounceY),
      2.3,
      Paint()..color = const Color(0xFF37474F),
    );

    // 4. Dua Roda Motor 2D (Ban Karet + Velg + Jari-jari Berputar)
    void drawWheel(double cx, double cy) {
      // Ban Luar Karet Hitam
      canvas.drawCircle(
        Offset(cx, cy),
        9.0,
        Paint()..color = const Color(0xFF212121),
      );
      // Ring Ban Dalam
      canvas.drawCircle(
        Offset(cx, cy),
        7.6,
        Paint()..color = const Color(0xFF323232),
      );
      // Velg Alloy Perak
      canvas.drawCircle(
        Offset(cx, cy),
        5.8,
        Paint()..color = const Color(0xFFE0E0E0),
      );
      // Jari-jari velg yang berputar dinamis
      final spokePaint = Paint()
        ..color = const Color(0xFF757575)
        ..strokeWidth = 1.3;
      for (int i = 0; i < 4; i++) {
        final double a = wheelAngle + (i * math.pi / 2);
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + math.cos(a) * 5.4, cy + math.sin(a) * 5.4),
          spokePaint,
        );
      }
      // Hub tengah velg
      canvas.drawCircle(
        Offset(cx, cy),
        2.2,
        Paint()..color = const Color(0xFF212121),
      );
    }

    // Roda Belakang & Roda Depan
    drawWheel(15, 37);
    drawWheel(49, 37);

    // 5. Bodi Motor Matic (Scooter Chassis)
    final chassisPaint = Paint()..color = const Color(0xFF263238);
    // Dek pijakan kaki bawah
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, 32 + bounceY, 17, 4.5),
        const Radius.circular(2),
      ),
      chassisPaint,
    );

    // Bodi Utama (Foodie Brand Orange / Green)
    final bodyPaint = Paint()..color = const Color(0xFFFF7A00);
    final bodyPath = Path()
      ..moveTo(12, 28 + bounceY)
      ..lineTo(25, 27 + bounceY)
      ..lineTo(30, 32 + bounceY)
      ..lineTo(41, 32 + bounceY)
      ..lineTo(48, 20 + bounceY) // Moncong stang kemudi
      ..lineTo(52, 24 + bounceY) // Lampu depan
      ..lineTo(46, 35 + bounceY) // Spatbor depan
      ..lineTo(16, 35 + bounceY) // Bawah bodi
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // List Aksen Garis Putih Sporty pada bodi
    final stripePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(17, 29 + bounceY),
      Offset(25, 28.5 + bounceY),
      stripePaint,
    );

    // Lampu Depan LED
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(50, 22 + bounceY, 3.2, 4.2),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFFFFF59D),
    );

    // Lampu Belakang (Stop Lamp Merah)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10.5, 27 + bounceY, 2.5, 4.0),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFFF1744),
    );

    // Jok Motor Hitam
    final seatPaint = Paint()..color = const Color(0xFF1E272C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(21, 24 + bounceY, 16, 4.5),
        const Radius.circular(2),
      ),
      seatPaint,
    );

    // Stang & Spion Motor
    final handlebarPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 2.2;
    canvas.drawLine(
      Offset(43, 20 + bounceY),
      Offset(45, 14 + bounceY),
      handlebarPaint,
    );
    // Grip stang
    canvas.drawCircle(
      Offset(44.5, 14 + bounceY),
      2.3,
      Paint()..color = const Color(0xFF212121),
    );
    // Batang dan Kaca Spion
    canvas.drawLine(
      Offset(44.5, 14 + bounceY),
      Offset(43, 9.5 + bounceY),
      Paint()
        ..color = const Color(0xFF455A64)
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(
      Offset(43, 9 + bounceY),
      2.0,
      Paint()..color = const Color(0xFF90A4AE),
    );

    // 6. Thermal Delivery Box (Tas Makanan Foodie) di Jok Belakang
    final boxPaint = Paint()
      ..color = const Color(0xFF0F9D58); // Hijau Khas Foodie Box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 13 + bounceY, 15, 15),
        const Radius.circular(3.5),
      ),
      boxPaint,
    );
    // Strip reflektif putih di tas
    canvas.drawRect(
      Rect.fromLTWH(8, 20 + bounceY, 15, 2.8),
      Paint()..color = Colors.white70,
    );
    // Ikon logo Foodie Delivery di tas
    canvas.drawCircle(
      Offset(15.5, 16.5 + bounceY),
      2.4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(15.5, 16.5 + bounceY),
      1.3,
      Paint()..color = const Color(0xFF0F9D58),
    );

    // 7. Karakter 2D Kurir (Kaki, Jaket, Tangan, Helm Full-Face)
    // Kaki kurir di atas dek motor
    final legPaint = Paint()
      ..color = const Color(0xFF1E272C)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(29, 23 + bounceY),
      Offset(31, 29 + bounceY),
      legPaint,
    );
    canvas.drawLine(
      Offset(31, 29 + bounceY),
      Offset(37, 30 + bounceY),
      legPaint,
    );

    // Jaket Rider Kurir
    final jacketPaint = Paint()..color = const Color(0xFF1B5E20);
    final bodyCourierPath = Path()
      ..moveTo(25, 23 + bounceY)
      ..lineTo(35, 23 + bounceY)
      ..lineTo(39, 13 + bounceY)
      ..lineTo(29, 12 + bounceY)
      ..close();
    canvas.drawPath(bodyCourierPath, jacketPaint);

    // Strip reflektif di jaket
    canvas.drawLine(
      Offset(28, 17 + bounceY),
      Offset(37, 18 + bounceY),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.6,
    );

    // Lengan kurir memegang stang
    final armPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(35, 15 + bounceY),
      Offset(44, 14 + bounceY),
      armPaint,
    );

    // Kepala & Helm Full-Face Kurir
    final helmetPaint = Paint()
      ..color = const Color(0xFFFF7A00); // Helm oranye cerah
    canvas.drawCircle(Offset(35, 8 + bounceY), 7.0, helmetPaint);

    // Kaca Helm (Visor) Hitam Mengkilap
    final visorPaint = Paint()..color = const Color(0xFF1A1A1A);
    final visorPath = Path()
      ..moveTo(35, 6 + bounceY)
      ..lineTo(41.5, 6.5 + bounceY)
      ..lineTo(41, 10 + bounceY)
      ..lineTo(35, 9.5 + bounceY)
      ..close();
    canvas.drawPath(visorPath, visorPaint);

    // Kilau pantulan cahaya di visor kaca helm
    canvas.drawLine(
      Offset(37, 7 + bounceY),
      Offset(40.5, 7.5 + bounceY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(covariant _Courier2DMotorcyclePainter oldDelegate) {
    return oldDelegate.wheelAngle != wheelAngle ||
        oldDelegate.bounceProgress != bounceProgress ||
        oldDelegate.isMoving != isMoving;
  }
}
