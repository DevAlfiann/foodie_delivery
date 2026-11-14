import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_state.dart';
import '../theme/app_colors.dart';
import '../widgets/capsule_toast.dart';
import 'cart_screen.dart';
import 'digital_receipt_screen.dart';
import 'food_detail_screen.dart';
import 'live_tracking_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _currentBottomNavIndex = 0;
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final OrderState _orderState = OrderState.instance;
  final Set<String> _bookmarkedDeals = {'milano_pizza', 'kfc_chicken'};

  late PageController _promoPageController;
  int _currentPromoIndex = 0;
  Timer? _promoAutoTimer;

  // Notifikasi Keranjang Melayang
  late AnimationController _cartNotifController;
  late Animation<Offset> _cartNotifSlideAnimation;
  late Animation<double> _cartNotifFadeAnimation;
  Timer? _cartNotifTimer;
  bool _isCartNotifVisible = false;

  // Controller Animasi Elastis Liquid Glass Nav Bar
  late AnimationController _liquidSpringController;
  late Animation<double> _liquidDragAnimation;
  double _liquidDragPosition = 0.0;
  bool _isLiquidDragging = false;
  double _liquidStretchFactor = 1.0;

  final List<Map<String, dynamic>> _promoBanners = [
    {
      'badge': '30% OFF',
      'title': 'Fast & Free Delivery!',
      'subtitle': 'Fresh gourmet cravings at your door in under 20 mins.',
      'image': 'assets/images/promo_food.png',
      'bgColor': AppColors.primaryContainer,
      'accentColor': AppColors.secondaryContainer,
      'badgeColor': const Color(0xFF0C7521),
      'btnText': 'Order Now',
    },
    {
      'badge': '40% OFF',
      'title': 'Smash Burger Fiesta!',
      'subtitle': 'Double wagyu cheese & crispy onion rings from Shake Shack.',
      'image': 'assets/images/burger_artisan.jpg',
      'bgColor': const Color(0xFF9A3412),
      'accentColor': const Color(0xFFFED7AA),
      'badgeColor': const Color(0xFF7C2D12),
      'btnText': 'Get Burger',
    },
    {
      'badge': 'BUY 1 GET 1',
      'title': 'Woodfire Pizza Night!',
      'subtitle': 'Authentic Neapolitan mozzarella & pepperoni stone-baked slice.',
      'image': 'assets/images/pizza_supreme.jpg',
      'bgColor': const Color(0xFF991B1B),
      'accentColor': const Color(0xFFFECACA),
      'badgeColor': const Color(0xFF7F1D1D),
      'btnText': 'Claim Pizza',
    },
    {
      'badge': 'FREE DRINK',
      'title': 'Crispy Korean Chicken!',
      'subtitle': 'Sweet spicy glazed drumsticks with crunchy sesame coating.',
      'image': 'assets/images/korean_chicken.jpg',
      'bgColor': const Color(0xFF854D0E),
      'accentColor': const Color(0xFFFEF08A),
      'badgeColor': const Color(0xFF713F12),
      'btnText': 'Order Chicken',
    },
  ];

  @override
  void initState() {
    super.initState();
    _orderState.addListener(_onOrderStateChange);
    _promoPageController = PageController(viewportFraction: 0.94);
    _startPromoTimer();

    // Animasi notifikasi keranjang meluncur dari bawah
    _cartNotifController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _cartNotifSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cartNotifController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _cartNotifFadeAnimation = CurvedAnimation(
      parent: _cartNotifController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // Setup Liquid Nav Bar Controller
    _liquidDragPosition = _currentBottomNavIndex.toDouble();
    _liquidSpringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _liquidSpringController.addListener(() {
      setState(() {
        _liquidDragPosition = _liquidDragAnimation.value;
      });
    });
  }

  void _animateLiquidToTab(double target) {
    _liquidDragAnimation = Tween<double>(
      begin: _liquidDragPosition,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _liquidSpringController,
        curve: Curves.elasticOut,
      ),
    );
    _liquidSpringController.forward(from: 0.0);
  }

  void _triggerCartNotification() {
    _cartNotifTimer?.cancel();
    if (mounted) {
      setState(() {
        _isCartNotifVisible = true;
      });
      _cartNotifController.forward(from: 0.0);

      _cartNotifTimer = Timer(const Duration(seconds: 5), () {
        _dismissCartNotification();
      });
    }
  }

  void _dismissCartNotification() {
    if (!_isCartNotifVisible) return;
    _cartNotifTimer?.cancel();
    if (_cartNotifController.value > 0) {
      _cartNotifController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isCartNotifVisible = false;
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _isCartNotifVisible = false;
        });
      }
    }
  }

  void _startPromoTimer() {
    _promoAutoTimer?.cancel();
    _promoAutoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_promoPageController.hasClients) return;
      final next = (_currentPromoIndex + 1) % _promoBanners.length;
      _promoPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _cartNotifTimer?.cancel();
    _cartNotifController.dispose();
    _liquidSpringController.dispose();
    _promoAutoTimer?.cancel();
    _promoPageController.dispose();
    _searchController.dispose();
    _orderState.removeListener(_onOrderStateChange);
    super.dispose();
  }

  void _onOrderStateChange() {
    if (mounted) setState(() {});
  }

  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.restaurant_menu, 'isEmoji': false},
    {'name': 'Burger', 'icon': '🍔', 'isEmoji': true},
    {'name': 'Pizza', 'icon': '🍕', 'isEmoji': true},
    {'name': 'Sushi', 'icon': '🍣', 'isEmoji': true},
    {'name': 'Chicken', 'icon': '🍗', 'isEmoji': true},
    {'name': 'Noodles', 'icon': '🍜', 'isEmoji': true},
    {'name': 'Drinks', 'icon': '🥤', 'isEmoji': true},
    {'name': 'Dessert', 'icon': '🍰', 'isEmoji': true},
  ];

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
                    'Pilih Alamat Antar (Demo)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '3 Alamat & Kurir',
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
              ...List.generate(OrderState.demoAddressOptions.length, (idx) {
                final addr = OrderState.demoAddressOptions[idx];
                final isSel = _orderState.selectedAddressIndex == idx;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    _orderState.setAddressIndex(idx);
                    Navigator.of(ctx).pop();
                    CapsuleToast.show(
                      context,
                      message: 'Alamat: ${addr.title} • Driver: ${addr.driverName}',
                      icon: Icons.location_on_rounded,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFE8F5E9) : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary : AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            idx == 0 ? Icons.home_rounded : (idx == 1 ? Icons.business_rounded : Icons.apartment_rounded),
                            color: isSel ? Colors.white : AppColors.onSurfaceVariant,
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
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
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
                          isSel ? Icons.check_circle : Icons.radio_button_unchecked,
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

  void _addToCart(String itemName, {double? price, String? restaurant, String? imagePath}) {
    final lower = itemName.toLowerCase();
    final isPizza = lower.contains('pizza');
    final isKfc = lower.contains('chicken') || lower.contains('wing');
    final isSushi = lower.contains('sushi') || lower.contains('bento');
    final isRamen = lower.contains('ramen') || lower.contains('noodle');
    final isDrink = lower.contains('tea') || lower.contains('boba') || lower.contains('soda');
    final isDessert = lower.contains('waffle') || lower.contains('cake') || lower.contains('crepe');

    final defaultPrice = isPizza
        ? 14.50
        : (isSushi
            ? 11.90
            : (isRamen
                ? 10.50
                : (isKfc ? 5.99 : (isDessert ? 4.80 : (isDrink ? 3.50 : 4.49)))));
    final defaultResto = isPizza
        ? "Milano Pizza Outlet"
        : (isSushi
            ? "Tokyo Bento Express"
            : (isRamen
                ? "Hakata Ramen House"
                : (isKfc
                    ? "KFC Jalan Ampang"
                    : (isDessert
                        ? "Belgian Waffle Cafe"
                        : (isDrink ? "Tiger Sugar & Tea Co." : "McDonald's Express")))));
    final defaultImage = isPizza
        ? 'assets/images/pizza_milano.png'
        : (isSushi
            ? 'assets/images/sushi_bento.png'
            : (isRamen
                ? 'assets/images/ramen_noodles.png'
                : (isDessert
                    ? 'assets/images/dessert_waffle.png'
                    : (isDrink
                        ? 'assets/images/boba_drink.png'
                        : (isKfc ? 'assets/images/kfc_chicken.png' : 'assets/images/mcchicken_hero.png')))));

    final cartItem = CartItem(
      id: 'cart_${DateTime.now().millisecondsSinceEpoch}',
      title: itemName,
      restaurant: restaurant ?? defaultResto,
      price: price ?? defaultPrice,
      quantity: 1,
      imagePath: imagePath ?? defaultImage,
    );

    _orderState.addToCart(cartItem);
    _triggerCartNotification();
  }

  Widget _buildCurrentTab() {
    switch (_currentBottomNavIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildSavedView();
      case 2:
        return CartScreen(
          showBackButton: true,
          onBackToHome: () {
            setState(() {
              _currentBottomNavIndex = 0;
            });
            _animateLiquidToTab(0);
          },
        );
      case 3:
        return const LiveTrackingScreen(showBackButton: false);
      case 4:
        return _buildProfileView();
      default:
        return _buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification) {
            _dismissCartNotification();
          }
          return false;
        },
        child: Listener(
          onPointerMove: (_) {
            _dismissCartNotification();
          },
          child: Stack(
            children: [
              SafeArea(
                top: _currentBottomNavIndex != 0,
                bottom: false,
                child: _buildCurrentTab(),
              ),

              // Notifikasi Keranjang Melayang di atas Tab Bar
              if (_isCartNotifVisible && _currentBottomNavIndex != 2)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 104,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: SlideTransition(
                          position: _cartNotifSlideAnimation,
                          child: FadeTransition(
                            opacity: _cartNotifFadeAnimation,
                            child: _buildFloatingCartNotification(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // iOS Liquid Glass Dynamic Floating Navigation Bar
              if (_currentBottomNavIndex != 2)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: _buildIosLiquidGlassNavBar(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final topPadding = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _HomeGreenHeaderDelegate(
            topPadding: topPadding,
            topAppBar: _buildAppBar(),
            addressSelect: _buildAddressSelect(),
            searchBar: _buildSearchBar(),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              RepaintBoundary(child: _buildPromoBannerCarousel()),
              RepaintBoundary(child: _buildVoucherClaimSection()),
              RepaintBoundary(child: _buildCategoriesSection()),
              RepaintBoundary(child: _buildHotDealsSection()),
              RepaintBoundary(child: _buildPopularNearYouSection()),
              RepaintBoundary(child: _buildQuickBiteGridSection()),
              RepaintBoundary(child: _buildTrustGuaranteeBadge()),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoucherClaimSection() {
    final vouchers = _orderState.vouchers;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Klaim Voucher Diskon',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Klaim & hemat saat checkout pesanan!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_orderState.claimedVouchers.length} Terklaim',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 106,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: vouchers.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final voucher = vouchers[index];
                final isClaimed = voucher.isClaimed;

                return Container(
                  width: 270,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isClaimed ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant,
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
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isClaimed
                                ? [const Color(0xFF0F5A31), const Color(0xFF1E824C)]
                                : [const Color(0xFF1E293B), const Color(0xFF334155)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(voucher.discountPercent * 100).toInt()}%',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                'DISKON',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.secondaryContainer,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  voucher.code,
                                  style: GoogleFonts.sourceCodePro(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                voucher.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                voucher.description,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    voucher.expiryText,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      color: AppColors.outline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (isClaimed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check, size: 12, color: AppColors.primary),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Terklaim',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        _orderState.claimVoucher(voucher.code);
                                        setState(() {});
                                        CapsuleToast.show(
                                          context,
                                          icon: Icons.confirmation_number_rounded,
                                          title: 'Voucher ${voucher.code} Berhasil Diklaim!',
                                          subtitle: 'Diskon ${(voucher.discountPercent * 100).toInt()}% siap digunakan saat checkout',
                                          actionLabel: 'PAKAI',
                                          bottomMargin: 104.0,
                                          onAction: () {
                                            _orderState.applyVoucherModel(voucher);
                                            setState(() => _currentBottomNavIndex = 2);
                                            _animateLiquidToTab(2);
                                          },
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Klaim',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCartNotification() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5A31), Color(0xFF146C3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F5A31).withValues(alpha: 0.40),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_orderState.totalItemCount}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_orderState.totalItemCount} Menu di Keranjang',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Total: \$${_orderState.grandTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.secondaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _dismissCartNotification();
                  setState(() {
                    _currentBottomNavIndex = 2;
                  });
                  _animateLiquidToTab(2);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.primary,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cek Out',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/foto.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/logo.png',
                  width: 44,
                  height: 44,
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
          InkWell(
            onTap: () {
              setState(() {
                _currentBottomNavIndex = 4;
              });
              _animateLiquidToTab(4);
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/avatar.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSelect() {
    final addr = _orderState.currentAddressOption;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _showAddressPickerModal,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DELIVER TO (KLIK UNTUK GANTI)',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${addr.title}: ${addr.fullAddress}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more,
                        color: Colors.white70,
                        size: 17,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                addr.estimatedTime,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
          children: [
            const Icon(
              Icons.search,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari burger, pizza, ramen, ayam...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: AppColors.outline,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: AppColors.onSurfaceVariant,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.mic,
                  color: AppColors.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildPromoBannerCarousel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: SizedBox(
            height: 186,
            child: PageView.builder(
              controller: _promoPageController,
              itemCount: _promoBanners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPromoIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final banner = _promoBanners[index];
                return AnimatedBuilder(
                  animation: _promoPageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_promoPageController.position.haveDimensions) {
                      value = _promoPageController.page! - index;
                      value = (1 - (value.abs() * 0.08)).clamp(0.0, 1.0);
                    }
                    return Center(
                      child: SizedBox(
                        height: Curves.easeOut.transform(value) * 186,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: banner['bgColor'] as Color,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (banner['bgColor'] as Color).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: banner['accentColor'] as Color,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      color: banner['badgeColor'] as Color,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      banner['badge'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: banner['badgeColor'] as Color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                banner['title'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                banner['subtitle'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  final title = banner['title'] as String;
                                  if (title.contains('Burger')) {
                                    _addToCart(
                                      'Artisan Smashed Wagyu',
                                      price: 7.90,
                                      restaurant: 'Artisan Burger Lab',
                                      imagePath: 'assets/images/burger_artisan.jpg',
                                    );
                                  } else if (title.contains('Pizza')) {
                                    _addToCart(
                                      'Supreme Pepperoni Delight',
                                      price: 13.90,
                                      restaurant: "Domino's Artisan",
                                      imagePath: 'assets/images/pizza_supreme.jpg',
                                    );
                                  } else if (title.contains('Chicken')) {
                                    _addToCart(
                                      'Korean Sweet Spicy Chicken',
                                      price: 8.50,
                                      restaurant: 'KyoChon 1991',
                                      imagePath: 'assets/images/korean_chicken.jpg',
                                    );
                                  } else {
                                    _addToCart(
                                      'McChicken Deluxe',
                                      price: 4.49,
                                      restaurant: "McDonald's Express",
                                      imagePath: 'assets/images/mcchicken_hero.png',
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: banner['bgColor'] as Color,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      banner['btnText'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward, size: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 102,
                          height: 102,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              banner['image'] as String,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.white24,
                                child: const Icon(Icons.fastfood, color: Colors.white, size: 40),
                              ),
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
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_promoBanners.length, (idx) {
            final isSel = _currentPromoIndex == idx;
            return GestureDetector(
              onTap: () {
                _promoPageController.animateToPage(
                  idx,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSel ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSel ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'See All (14)',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _categories[index];
              final isSelected = _selectedCategoryIndex == index;

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = index;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (item['isEmoji'])
                        Text(
                          item['icon'] as String,
                          style: const TextStyle(fontSize: 16),
                        )
                      else
                        Icon(
                          item['icon'] as IconData,
                          color: isSelected ? Colors.white : AppColors.onSurface,
                          size: 18,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        item['name'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? Colors.white : AppColors.onSurface,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
    );
  }

  Widget _buildHotDealsSection() {
    final isBookmarked = _bookmarkedDeals.contains('milano_pizza');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hot Deals of the Day',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ends in 03:24:18',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FoodDetailScreen(
                      title: 'Milano Truffle Crust Pizza',
                      basePrice: 14.50,
                      imagePath: 'assets/images/pizza_milano.png',
                      description:
                          'Wood-fired perfection with fresh wild mushrooms, bubbling melted mozzarella, and fragrant basil leaves on stone baking crust.',
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        height: 170,
                        width: double.infinity,
                        child: Image.asset(
                          'assets/images/pizza_milano.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.surfaceContainerHigh,
                            child: const Icon(Icons.local_pizza, size: 50, color: AppColors.outline),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.65),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '30% OFF - Code: FOOD30',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'FREESHIP',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isBookmarked) {
                                _bookmarkedDeals.remove('milano_pizza');
                              } else {
                                _bookmarkedDeals.add('milano_pizza');
                              }
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              color: isBookmarked ? AppColors.primary : AppColors.onSurface,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Milano Truffle Crust Pizza',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Wood-fired perfection with wild mushrooms',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '\$14.50 ',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '\$21.00',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.outline,
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '4.9',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  ' (1.4k+)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.outline,
                                    fontSize: 12,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('•', style: TextStyle(color: AppColors.outline)),
                                ),
                                const Icon(Icons.schedule, color: AppColors.outline, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '20-25 min',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _addToCart('Milano Truffle Pizza'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                'Claim',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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

  Widget _buildPopularNearYouSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Popular Near You',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'View Map',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRestaurantItem(
            name: 'KFC - Jalan Ampang',
            subtitle: 'Crispy Tenders, Wings & Biscuits',
            rating: '4.8',
            deliveryTime: '15-20 min',
            badgeText: 'FREE',
            badgeColor: const Color(0xFFE8F5E9),
            badgeTextColor: AppColors.primary,
            extraInfo: 'Free delivery',
            imagePath: 'assets/images/kfc_chicken.png',
          ),
          const SizedBox(height: 12),
          _buildRestaurantItem(
            name: "McDonald's - Bukit Bintang",
            subtitle: 'Big Macs, Shakes & Golden Fries',
            rating: '4.9',
            deliveryTime: '10-15 min',
            badgeText: '⚡ FAST',
            badgeColor: Colors.white,
            badgeTextColor: AppColors.onSurface,
            extraInfo: '0.8 km away',
            imagePath: 'assets/images/mcd_burger.png',
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantItem({
    required String name,
    required String subtitle,
    required String rating,
    required String deliveryTime,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required String extraInfo,
    required String imagePath,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FoodDetailScreen(
                title: name.contains('KFC') ? 'KFC Chicken Meal' : 'McChicken',
                basePrice: 4.49,
                imagePath: imagePath,
                description: subtitle,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.surfaceContainerLow,
                          child: const Icon(Icons.fastfood, color: AppColors.outline),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          color: badgeTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: AppColors.primary, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                rating,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.moped, color: AppColors.primary, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          deliveryTime,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('•', style: TextStyle(color: AppColors.outline)),
                        ),
                        Expanded(
                          child: Text(
                            extraInfo,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildQuickBiteGridSection() {
    final List<Map<String, dynamic>> allQuickProducts = [
      {
        'title': 'McChicken Deluxe',
        'restaurant': "McDonald's Express",
        'desc': 'Crispy golden chicken patty with lettuce & mayo',
        'price': '\$4.49',
        'rawPrice': 4.49,
        'badge': 'Top Pick 🔥',
        'image': 'assets/images/mcchicken_hero.png',
        'category': 'Burger',
      },
      {
        'title': 'Double Cheese Burger',
        'restaurant': 'Burger King Plaza',
        'desc': '100% flame-grilled Angus beef with double melted cheddar',
        'price': '\$5.80',
        'rawPrice': 5.80,
        'badge': 'Best Seller',
        'image': 'assets/images/mcd_burger.png',
        'category': 'Burger',
      },
      {
        'title': 'Artisan Smashed Wagyu',
        'restaurant': 'Artisan Burger Lab',
        'desc': 'Double smashed wagyu patties, crispy bacon & caramelized onions',
        'price': '\$7.90',
        'rawPrice': 7.90,
        'badge': 'Chef Choice ⭐',
        'image': 'assets/images/burger_artisan.jpg',
        'category': 'Burger',
      },
      {
        'title': 'Milano Truffle Crust Pizza',
        'restaurant': 'Milano Pizza Outlet',
        'desc': 'Wild mushrooms, mozzarella & black truffle oil',
        'price': '\$14.50',
        'rawPrice': 14.50,
        'badge': 'Chef Choice',
        'image': 'assets/images/pizza_milano.png',
        'category': 'Pizza',
      },
      {
        'title': 'Supreme Pepperoni Delight',
        'restaurant': "Domino's Artisan",
        'desc': 'Italian pepperoni, sausage, peppers & mozzarella pull',
        'price': '\$13.90',
        'rawPrice': 13.90,
        'badge': 'Hot & Cheesy 🍕',
        'image': 'assets/images/pizza_supreme.jpg',
        'category': 'Pizza',
      },
      {
        'title': 'Tokyo Bento Salmon Box',
        'restaurant': 'Tokyo Bento Express',
        'desc': 'Fresh salmon nigiri, maki roll & seaweed wakame salad',
        'price': '\$11.90',
        'rawPrice': 11.90,
        'badge': 'Top Rated ⭐',
        'image': 'assets/images/sushi_bento.png',
        'category': 'Sushi',
      },
      {
        'title': 'KFC Crispy Spicy Wings',
        'restaurant': 'KFC Jalan Ampang',
        'desc': '6 pcs ultra crunchy spicy buffalo wings with garlic dip',
        'price': '\$5.99',
        'rawPrice': 5.99,
        'badge': 'Crispy 🍗',
        'image': 'assets/images/kfc_chicken.png',
        'category': 'Chicken',
      },
      {
        'title': 'Korean Sweet Spicy Chicken',
        'restaurant': 'KyoChon 1991',
        'desc': 'Crunchy fried chicken drumsticks glazed in sweet chili & sesame',
        'price': '\$8.50',
        'rawPrice': 8.50,
        'badge': 'Korean Glaze 🔥',
        'image': 'assets/images/korean_chicken.jpg',
        'category': 'Chicken',
      },
      {
        'title': 'Hakata Tonkotsu Chashu Ramen',
        'restaurant': 'Ippudo Ramen House',
        'desc': '12-hour rich pork broth, tender chashu & ajitama egg',
        'price': '\$10.50',
        'rawPrice': 10.50,
        'badge': 'Hot Soup 🍜',
        'image': 'assets/images/ramen_noodles.png',
        'category': 'Noodles',
      },
      {
        'title': 'Brown Sugar Tiger Boba Milk',
        'restaurant': 'Tiger Sugar Boba Co.',
        'desc': 'Rich fresh milk with chewy brown sugar pearls & torched cream',
        'price': '\$3.80',
        'rawPrice': 3.80,
        'badge': 'Must Try 🧋',
        'image': 'assets/images/boba_drink.png',
        'category': 'Drinks',
      },
      {
        'title': 'Belgian Warm Choco Waffle',
        'restaurant': 'Wafflecious Cafe',
        'desc': 'Golden crisp waffle with fresh berries & melted dark chocolate',
        'price': '\$4.80',
        'rawPrice': 4.80,
        'badge': 'Sweet 🍰',
        'image': 'assets/images/dessert_waffle.png',
        'category': 'Dessert',
      },
    ];

    final currentCat = _categories[_selectedCategoryIndex]['name'] as String;

    var result = currentCat == 'All'
        ? allQuickProducts
        : allQuickProducts.where((p) => (p['category'] as String).toLowerCase() == currentCat.toLowerCase()).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((p) {
        final title = (p['title'] as String).toLowerCase();
        final resto = (p['restaurant'] as String? ?? '').toLowerCase();
        final desc = (p['desc'] as String? ?? '').toLowerCase();
        final cat = (p['category'] as String? ?? '').toLowerCase();
        return title.contains(q) || resto.contains(q) || desc.contains(q) || cat.contains(q);
      }).toList();
    }

    final displayList = result;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
                      'Menu & Restoran Pilihan',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Kategori: $currentCat • ${displayList.length} menu ditemukan',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedCategoryIndex != 0 || _searchQuery.isNotEmpty)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = 0;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Reset Filter',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (displayList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada menu "$_searchQuery" di kategori $currentCat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Coba kata kunci lain atau klik tombol reset di bawah.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategoryIndex = 0;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    ),
                    child: const Text('Tampilkan Semua Menu'),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.63,
              ),
              itemBuilder: (context, idx) {
                final p = displayList[idx];
                return _buildGridProductCard(
                  title: p['title'] as String,
                  restaurant: p['restaurant'] as String? ?? 'Foodie Resto',
                  description: p['desc'] as String,
                  price: p['price'] as String,
                  rawPrice: (p['rawPrice'] as num).toDouble(),
                  badgeText: p['badge'] as String,
                  imagePath: p['image'] as String,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGridProductCard({
    required String title,
    required String restaurant,
    required String description,
    required String price,
    required double rawPrice,
    required String badgeText,
    required String imagePath,
  }) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FoodDetailScreen(
                  title: title,
                  basePrice: rawPrice,
                  imagePath: imagePath,
                  description: description,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.surfaceContainerLow,
                            child: const Icon(Icons.fastfood, color: AppColors.outline),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        restaurant,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    InkWell(
                      onTap: () => _addToCart(
                        title,
                        price: rawPrice,
                        restaurant: restaurant,
                        imagePath: imagePath,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustGuaranteeBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guaranteed On-Time or Free Voucher',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Contactless delivery and live thermal tracking on every order.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.outline,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 10. iOS Liquid Glass Dynamic Floating Navigation Bar (Draggable + Elastic + Viscosity)
  Widget _buildIosLiquidGlassNavBar() {
    const navItems = [
      {'sel': Icons.home_rounded, 'un': Icons.home_outlined, 'tip': 'Beranda'},
      {'sel': Icons.search_rounded, 'un': Icons.search_rounded, 'tip': 'Cari & Favorit'},
      {'sel': Icons.shopping_bag_rounded, 'un': Icons.shopping_bag_outlined, 'tip': 'Keranjang'},
      {'sel': Icons.moped_rounded, 'un': Icons.moped_outlined, 'tip': 'Lacak Antar'},
      {'sel': Icons.person_rounded, 'un': Icons.person_outline_rounded, 'tip': 'Profil'},
    ];

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          const tabCount = 5;
          final tabWidth = totalWidth / tabCount;
          final pillWidth = tabWidth * 0.74;
          const pillHeight = 44.0;

          final pillLeft = (_liquidDragPosition * tabWidth) +
              (tabWidth - (pillWidth * _liquidStretchFactor)) / 2;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, -1),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.26),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.38),
                      width: 1.2,
                    ),
                  ),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final delta = details.primaryDelta ?? 0.0;
                      setState(() {
                        _isLiquidDragging = true;
                        _liquidDragPosition = (_liquidDragPosition + (delta / tabWidth))
                            .clamp(0.0, (tabCount - 1).toDouble());
                        _liquidStretchFactor = (1.0 + (delta.abs() / 14.0)).clamp(1.0, 1.45);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      final targetIndex = _liquidDragPosition.round().clamp(0, tabCount - 1);
                      setState(() {
                        _isLiquidDragging = false;
                        _liquidStretchFactor = 1.0;
                        _currentBottomNavIndex = targetIndex;
                      });
                      HapticFeedback.mediumImpact();
                      _animateLiquidToTab(targetIndex.toDouble());
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Tetesan Kaca Cair (Liquid Bubble Capsule)
                        Positioned(
                          left: pillLeft,
                          child: Transform.scale(
                            scaleX: _liquidStretchFactor,
                            child: Container(
                              width: pillWidth,
                              height: pillHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: _isLiquidDragging ? 0.58 : 0.46),
                                    Colors.white.withValues(alpha: _isLiquidDragging ? 0.22 : 0.16),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.30),
                                    blurRadius: 14,
                                    spreadRadius: -1,
                                    offset: const Offset(0, 2),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  height: 12,
                                  margin: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.60),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Baris Ikon Interaktif
                        Row(
                          children: List.generate(tabCount, (index) {
                            final item = navItems[index];
                            final distance = (_liquidDragPosition - index).abs();
                            final scale = (1.18 - (distance * 0.22)).clamp(0.92, 1.18);
                            final isSelected = _currentBottomNavIndex == index;

                            int? badgeCount;
                            bool isPulseDot = false;
                            if (index == 2) {
                              badgeCount = _orderState.totalItemCount;
                            } else if (index == 3 && _orderState.hasActiveOrder) {
                              badgeCount = 1;
                              isPulseDot = true;
                            }

                            return Expanded(
                              child: Tooltip(
                                message: item['tip'] as String,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _currentBottomNavIndex = index;
                                      });
                                      _animateLiquidToTab(index.toDouble());
                                    },
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    child: Center(
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          Transform.scale(
                                            scale: scale,
                                            child: Icon(
                                              isSelected
                                                  ? (item['sel'] as IconData)
                                                  : (item['un'] as IconData),
                                              size: 24,
                                              color: Color.lerp(
                                                Colors.white.withValues(alpha: 0.58),
                                                Colors.white,
                                                (1.0 - distance).clamp(0.0, 1.0),
                                              ),
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withValues(
                                                    alpha: isSelected ? 0.25 : 0.12,
                                                  ),
                                                  blurRadius: isSelected ? 4 : 2,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (badgeCount != null && badgeCount > 0)
                                            Positioned(
                                              top: -6,
                                              right: -8,
                                              child: Container(
                                                padding: isPulseDot
                                                    ? const EdgeInsets.all(4)
                                                    : const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? AppColors.secondaryContainer
                                                      : AppColors.error,
                                                  shape: isPulseDot ? BoxShape.circle : BoxShape.rectangle,
                                                  borderRadius: isPulseDot ? null : BorderRadius.circular(10),
                                                  border: Border.all(color: Colors.white, width: 1.5),
                                                ),
                                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                                child: isPulseDot
                                                    ? null
                                                    : Center(
                                                        child: Text(
                                                          '$badgeCount',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            color: isSelected ? AppColors.primary : Colors.white,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w800,
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
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedView() {
    final allSavedItems = [
      {
        'title': 'Artisan Smashed Wagyu',
        'restaurant': 'Artisan Burger Lab',
        'price': 7.90,
        'rating': '4.9',
        'imagePath': 'assets/images/burger_artisan.jpg',
        'deliveryTime': '15-20 min',
      },
      {
        'title': 'Milano Truffle Crust Pizza',
        'restaurant': 'Milano Pizza Outlet',
        'price': 14.50,
        'rating': '4.9',
        'imagePath': 'assets/images/pizza_milano.png',
        'deliveryTime': '20-25 min',
      },
      {
        'title': 'Korean Sweet Spicy Chicken',
        'restaurant': 'KyoChon 1991',
        'price': 8.50,
        'rating': '4.9',
        'imagePath': 'assets/images/korean_chicken.jpg',
        'deliveryTime': '15-20 min',
      },
      {
        'title': 'Supreme Pepperoni Delight',
        'restaurant': "Domino's Artisan",
        'price': 13.90,
        'rating': '4.8',
        'imagePath': 'assets/images/pizza_supreme.jpg',
        'deliveryTime': '20-25 min',
      },
      {
        'title': 'Hakata Tonkotsu Chashu Ramen',
        'restaurant': 'Ippudo Ramen House',
        'price': 10.50,
        'rating': '4.9',
        'imagePath': 'assets/images/ramen_noodles.png',
        'deliveryTime': '15-20 min',
      },
      {
        'title': 'Brown Sugar Tiger Boba Milk',
        'restaurant': 'Tiger Sugar Boba Co.',
        'price': 3.80,
        'rating': '4.8',
        'imagePath': 'assets/images/boba_drink.png',
        'deliveryTime': '10-15 min',
      },
      {
        'title': 'KFC Crispy Chicken Combo',
        'restaurant': 'KFC - Jalan Ampang',
        'price': 5.99,
        'rating': '4.8',
        'imagePath': 'assets/images/kfc_chicken.png',
        'deliveryTime': '15-20 min',
      },
      {
        'title': 'McChicken Deluxe Burger',
        'restaurant': "McDonald's Express",
        'price': 4.49,
        'rating': '4.9',
        'imagePath': 'assets/images/mcchicken_hero.png',
        'deliveryTime': '10-15 min',
      },
      {
        'title': 'Belgian Warm Choco Waffle',
        'restaurant': 'Wafflecious Cafe',
        'price': 4.80,
        'rating': '4.8',
        'imagePath': 'assets/images/dessert_waffle.png',
        'deliveryTime': '10-15 min',
      },
    ];

    final filteredItems = allSavedItems.where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final title = (item['title'] as String).toLowerCase();
      final restaurant = (item['restaurant'] as String).toLowerCase();
      return title.contains(q) || restaurant.contains(q);
    }).toList();

    return Column(
      children: [
        // iOS Liquid Glass Top Navigation Bar
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.90),
                    Colors.white.withValues(alpha: 0.74),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.85),
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cari & Favorit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryContainer.withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          '${filteredItems.length} Menu',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // iOS Liquid Glass Search Capsule
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Cari menu atau restoran favorit...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.outline,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                            child: const Icon(Icons.clear, size: 18, color: AppColors.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSavedItemCard(
                  title: item['title'] as String,
                  restaurant: item['restaurant'] as String,
                  price: item['price'] as double,
                  rating: item['rating'] as String,
                  imagePath: item['imagePath'] as String,
                  deliveryTime: item['deliveryTime'] as String,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSavedItemCard({
    required String title,
    required String restaurant,
    required double price,
    required String rating,
    required String imagePath,
    required String deliveryTime,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FoodDetailScreen(
                  title: title,
                  basePrice: price,
                  imagePath: imagePath,
                  description: 'Menu favorit pilihan lezat dari $restaurant siap diantar.',
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.asset(imagePath, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        restaurant,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '\$${price.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            rating,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $deliveryTime',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _addToCart(title),
                  icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFE8F5E9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    final currentAddress = _orderState.currentAddressOption;

    return Column(
      children: [
        // iOS Liquid Glass Top Navigation Bar
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.90),
                    Colors.white.withValues(alpha: 0.74),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.85),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Akun & Pengaturan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryContainer.withValues(alpha: 0.25),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
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
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        AppColors.primary.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, Color(0xFF10B981)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const CircleAvatar(
                                  radius: 32,
                                  backgroundImage: AssetImage('assets/images/avatar.png'),
                                ),
                              ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Pengguna Anonim',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🛡️ Anonim',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'anonim-user#8821 • Sesi Disamarkan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.lock_outline, size: 13, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                'Data Pribadi Tidak Disimpan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAnonStatusItem(Icons.security, 'Enkripsi', 'Aktif'),
                      Container(width: 1, height: 24, color: AppColors.outline.withValues(alpha: 0.2)),
                      _buildAnonStatusItem(Icons.visibility_off_outlined, 'Penyamaran', '100%'),
                      Container(width: 1, height: 24, color: AppColors.outline.withValues(alpha: 0.2)),
                      _buildAnonStatusItem(Icons.wallet, 'Saldo Tamu', 'Rp 250.000'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildProfileMenuSection('Privasi & Keamanan Data', [
            _buildProfileTile(
              Icons.privacy_tip_outlined,
              'Mode Anonim (Incognito)',
              'Aktif • Pengiriman rahasia tanpa nama asli',
              () {
                CapsuleToast.show(
                  context,
                  message: 'Mode Anonim Aktif: Kontak & nama Anda disamarkan.',
                  icon: Icons.shield_rounded,
                );
              },
            ),
            _buildProfileTile(
              Icons.delete_sweep_outlined,
              'Bersihkan Cache & Riwayat Sesi',
              'Hapus jejak penelusuran lokal',
              () {
                CapsuleToast.show(
                  context,
                  message: 'Jejak cache dan riwayat berhasil dibersihkan!',
                  icon: Icons.cleaning_services_rounded,
                );
              },
            ),
            _buildProfileTile(
              Icons.person_add_alt_1_outlined,
              'Tautkan Akun / Daftar Resmi',
              'Simpan pesanan secara permanen jika diinginkan',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ]),
          const SizedBox(height: 14),
          _buildProfileMenuSection('Pesanan & Transaksi', [
            _buildProfileTile(
              Icons.moped,
              'Lacak Pengiriman Realtime',
              'Sedang Diantar (#FD-5096) • Animasi OTW',
              () {
                setState(() {
                  _currentBottomNavIndex = 3;
                });
                _animateLiquidToTab(3);
              },
            ),
            _buildProfileTile(
              Icons.receipt_long,
              'Struk Pembayaran Digital',
              'Lihat struk pesanan & QR (#FD-5096)',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DigitalReceiptScreen(
                      orderId: '#FD-5096',
                      totalAmount: 19.08,
                    ),
                  ),
                );
              },
            ),
            _buildProfileTile(
              Icons.shopping_bag_outlined,
              'Keranjang Belanja',
              '${_orderState.totalItemCount} menu siap di-checkout',
              () {
                setState(() {
                  _currentBottomNavIndex = 2;
                });
                _animateLiquidToTab(2);
              },
            ),
          ]),
          const SizedBox(height: 14),
          _buildProfileMenuSection('Pengaturan Pengiriman & Metode', [
            _buildProfileTile(
              Icons.location_on_outlined,
              'Alamat Aktif',
              '${currentAddress.title} (${currentAddress.fullAddress})',
              () {
                _showAddressPickerModal();
              },
            ),
            _buildProfileTile(
              Icons.qr_code_2,
              'Metode Pembayaran Cepat',
              'QRIS, Kartu Debit/Kredit, E-Wallet',
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DigitalReceiptScreen(
                      orderId: '#FD-5096',
                      totalAmount: 19.08,
                    ),
                  ),
                );
              },
            ),
            _buildProfileTile(
              Icons.headset_mic_outlined,
              'Bantuan & CS Foodie 24/7',
              'Chat bantuan instan tanpa login',
              () {
                CapsuleToast.show(
                  context,
                  message: 'Menghubungkan ke Customer Support Foodie...',
                  icon: Icons.headset_mic_rounded,
                );
              },
            ),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              OrderState.instance.isLoggedIn = false;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.refresh, size: 18, color: AppColors.error),
            label: Text(
              'Reset Sesi Tamu / Keluar',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
          const SizedBox(height: 130),
        ],
      ),
    ),
  ),
],
);
  }

  Widget _buildAnonStatusItem(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMenuSection(String header, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              header,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
        onTap: onTap,
      ),
    );
  }
}

class _HomeGreenHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final Widget topAppBar;
  final Widget addressSelect;
  final Widget searchBar;

  _HomeGreenHeaderDelegate({
    required this.topPadding,
    required this.topAppBar,
    required this.addressSelect,
    required this.searchBar,
  });

  @override
  double get maxExtent => topPadding + 176.0;

  @override
  double get minExtent => topPadding + 120.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = ((shrinkOffset) / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(38),
        bottomRight: Radius.circular(38),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F5A31).withValues(alpha: 0.95),
                const Color(0xFF1B6B3E).withValues(alpha: 0.88),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(38),
              bottomRight: Radius.circular(38),
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.32),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F5A31).withValues(alpha: 0.18 + 0.12 * progress),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -24,
                right: -24,
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
                bottom: -15,
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
              Positioned(
                top: topPadding + 4,
                left: 0,
                right: 0,
                height: 48,
                child: topAppBar,
              ),
              Positioned(
                top: topPadding + 52,
                left: 0,
                right: 0,
                height: (40.0 * (1.0 - progress)).clamp(0.0, 40.0),
                child: IgnorePointer(
                  ignoring: progress > 0.4,
                  child: Opacity(
                    opacity: (1.0 - progress * 1.8).clamp(0.0, 1.0),
                    child: addressSelect,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                height: 48,
                child: searchBar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeGreenHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.topAppBar != topAppBar ||
        oldDelegate.addressSelect != addressSelect ||
        oldDelegate.searchBar != searchBar;
  }
}