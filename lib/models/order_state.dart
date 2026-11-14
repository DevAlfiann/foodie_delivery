import 'package:flutter/foundation.dart';

class FoodItem {
  final String id;
  final String title;
  final String restaurant;
  final double basePrice;
  final String imagePath;
  final String description;
  final double rating;
  final String deliveryTime;
  final String category;

  const FoodItem({
    required this.id,
    required this.title,
    required this.restaurant,
    required this.basePrice,
    required this.imagePath,
    required this.description,
    this.rating = 4.8,
    this.deliveryTime = '15-20 min',
    this.category = 'Burger',
  });
}

class CartItem {
  final String id;
  final String title;
  final String restaurant;
  final double price;
  int quantity;
  final String imagePath;
  final String size;
  final List<String> addons;
  final String? side;
  final String? drink;
  final String? notes;

  CartItem({
    required this.id,
    required this.title,
    required this.restaurant,
    required this.price,
    this.quantity = 1,
    required this.imagePath,
    this.size = 'Regular',
    this.addons = const [],
    this.side,
    this.drink,
    this.notes,
  });

  double get totalPrice => price * quantity;
}

class VoucherModel {
  final String code;
  final String title;
  final String description;
  final double discountPercent;
  final double minOrder;
  final String expiryText;
  final String badgeText;
  bool isClaimed;

  VoucherModel({
    required this.code,
    required this.title,
    required this.description,
    required this.discountPercent,
    this.minOrder = 0.0,
    required this.expiryText,
    required this.badgeText,
    this.isClaimed = false,
  });
}

class DeliveryAddressOption {
  final String id;
  final String title;
  final String fullAddress;
  final String driverName;
  final String driverPlate;
  final String driverPhone;
  final String driverRating;
  final String driverVehicle;
  final String restaurantName;
  final String distance;
  final String estimatedTime;
  final double originX;
  final double originY;
  final double destX;
  final double destY;

  const DeliveryAddressOption({
    required this.id,
    required this.title,
    required this.fullAddress,
    required this.driverName,
    required this.driverPlate,
    required this.driverPhone,
    this.driverRating = '4.95',
    this.driverVehicle = 'Honda Vario 160 • Merah',
    required this.restaurantName,
    required this.distance,
    required this.estimatedTime,
    required this.originX,
    required this.originY,
    required this.destX,
    required this.destY,
  });
}

class OrderState extends ChangeNotifier {
  static final OrderState instance = OrderState._internal();
  OrderState._internal();

  static const List<DeliveryAddressOption> demoAddressOptions = [
    DeliveryAddressOption(
      id: 'addr_home',
      title: 'Home (Rumah)',
      fullAddress: 'Jl. Riverbank Residence Blok B No. 12',
      driverName: 'Pak Bambang Suherman',
      driverPlate: 'B 4521 TKL',
      driverPhone: '+62 812-9876-5432',
      driverRating: '4.96 (1.8k order)',
      driverVehicle: 'Honda Vario 160 • Merah Glossy',
      restaurantName: 'Toko Burger Central',
      distance: '2.1 km',
      estimatedTime: '12-15 min',
      originX: 0.5512,
      originY: 0.4658,
      destX: 0.2547,
      destY: 0.3331,
    ),
    DeliveryAddressOption(
      id: 'addr_office',
      title: 'Kantor (Sudirman)',
      fullAddress: 'Gedung Sahid Sudirman Center Lt. 24, Jakpus',
      driverName: 'Pak Dimas Prasetyo',
      driverPlate: 'B 3892 SGZ',
      driverPhone: '+62 813-8821-4455',
      driverRating: '4.92 (940 order)',
      driverVehicle: 'Yamaha NMAX 155 • Hitam Doff',
      restaurantName: 'Pizzeria Milano',
      distance: '2.8 km',
      estimatedTime: '10-14 min',
      originX: 0.8431,
      originY: 0.6404,
      destX: 0.4675,
      destY: 0.2171,
    ),
    DeliveryAddressOption(
      id: 'addr_apartment',
      title: 'Apartemen (Menteng)',
      fullAddress: 'Menteng Park Tower Diamond Lt. 15, Jakpus',
      driverName: 'Pak Joko Susanto',
      driverPlate: 'B 6710 KBC',
      driverPhone: '+62 856-7788-9900',
      driverRating: '4.98 (2.3k order)',
      driverVehicle: 'Honda PCX Electric • Putih Mutiara',
      restaurantName: 'Sushi Bar Tokyo',
      distance: '1.9 km',
      estimatedTime: '8-12 min',
      originX: 0.5728,
      originY: 0.7795,
      destX: 0.5140,
      destY: 0.3119,
    ),
  ];

  final List<CartItem> _cartItems = [];
  final Set<String> _bookmarkedIds = {'milano_pizza', 'kfc_combo'};

  final List<VoucherModel> _vouchers = [
    VoucherModel(
      code: 'SUPER50',
      title: 'Diskon 50% Pengguna Baru',
      description: 'Potongan 50% pesanan makanan hari ini',
      discountPercent: 0.50,
      minOrder: 0.0,
      expiryText: 'Berakhir 2 hari lagi',
      badgeText: '50% OFF',
      isClaimed: false,
    ),
    VoucherModel(
      code: 'FOODIE30',
      title: 'Diskon 30% Pesta Kuliner',
      description: 'Potongan 30% semua menu favorit resto',
      discountPercent: 0.30,
      minOrder: 10.0,
      expiryText: 'Berakhir 5 hari lagi',
      badgeText: '30% OFF',
      isClaimed: false,
    ),
    VoucherModel(
      code: 'HEMAT20',
      title: 'Diskon 20% Gajian Hemat',
      description: 'Hemat 20% untuk semua menu pilihan',
      discountPercent: 0.20,
      minOrder: 5.0,
      expiryText: 'Berakhir besok',
      badgeText: '20% OFF',
      isClaimed: false,
    ),
    VoucherModel(
      code: 'FOODIE15',
      title: 'Diskon 15% Member Foodie',
      description: 'Potongan 15% pesanan pertama',
      discountPercent: 0.15,
      minOrder: 0.0,
      expiryText: 'Aktif selamanya',
      badgeText: '15% OFF',
      isClaimed: true,
    ),
  ];

  String _selectedVoucher = 'FOODIE15';
  double _voucherDiscountPercent = 0.15;
  int _selectedAddressIndex = 0;
  bool _isDelivery = true; // true = delivery, false = pickup
  bool _isFastDelivery = true; // true = Pengantaran Cepat, false = Pengantaran Hemat
  String _paymentMethod = 'QRIS';

  // Active Live Order (false initially until user places an order)
  bool _hasActiveOrder = false;
  String _activeOrderId = '#FD-5096';
  int _orderStepIndex = 0; // 0: Diterima, 1: Dimasak, 2: Diantar, 3: Sampai
  bool _isLoggedIn = false;

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  Set<String> get bookmarkedIds => _bookmarkedIds;
  List<VoucherModel> get vouchers => _vouchers;
  List<VoucherModel> get claimedVouchers => _vouchers.where((v) => v.isClaimed).toList();
  VoucherModel? get currentVoucher {
    final idx = _vouchers.indexWhere((v) => v.code == _selectedVoucher);
    return idx >= 0 ? _vouchers[idx] : null;
  }
  String get selectedVoucher => _selectedVoucher;
  double get voucherDiscountPercent => _voucherDiscountPercent;
  DeliveryAddressOption get currentAddressOption => demoAddressOptions[_selectedAddressIndex];
  String get deliveryAddress => currentAddressOption.fullAddress;
  int get selectedAddressIndex => _selectedAddressIndex;
  bool get isDelivery => _isDelivery;
  bool get isFastDelivery => _isFastDelivery;
  String get paymentMethod => _paymentMethod;
  bool get hasActiveOrder => _hasActiveOrder;
  String get activeOrderId => _activeOrderId;
  int get orderStepIndex => _orderStepIndex;
  bool get isLoggedIn => _isLoggedIn;
  set isLoggedIn(bool value) {
    if (_isLoggedIn != value) {
      _isLoggedIn = value;
      notifyListeners();
    }
  }

  void setFastDelivery(bool fast) {
    if (_isFastDelivery != fast) {
      _isFastDelivery = fast;
      notifyListeners();
    }
  }

  void _initDefaultCart() {
    _cartItems.add(
      CartItem(
        id: 'cart_1',
        title: 'McChicken Deluxe Burger',
        restaurant: "McDonald's Ampang Point",
        price: 22.45,
        quantity: 1,
        imagePath: 'assets/images/mcchicken_hero.png',
        size: 'Regular',
        addons: ['Extra Cheese'],
        side: 'French Fries',
        drink: 'Iced Lemon Tea',
      ),
    );
  }

  int get totalItemCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee => _isDelivery ? (_isFastDelivery ? 2.00 : 0.0) : 0.0;
  double get originalDeliveryFee => _isDelivery ? (_isFastDelivery ? 3.50 : 2.00) : 0.0;

  double get discountAmount => subtotal * _voucherDiscountPercent;

  double get grandTotal {
    final t = subtotal - discountAmount + deliveryFee;
    return t > 0 ? t : 0.0;
  }

  void addToCart(CartItem item) {
    final existingIndex = _cartItems.indexWhere((i) => i.title == item.title && i.size == item.size);
    if (existingIndex >= 0) {
      _cartItems[existingIndex].quantity += item.quantity;
    } else {
      _cartItems.add(item);
    }
    notifyListeners();
  }

  void updateQuantity(String id, int delta) {
    final index = _cartItems.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final newQty = _cartItems[index].quantity + delta;
      if (newQty <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index].quantity = newQty;
      }
      notifyListeners();
    }
  }

  void removeItem(String id) {
    _cartItems.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  void addSampleItems() {
    _cartItems.clear();
    _initDefaultCart();
    _cartItems.add(
      CartItem(
        id: 'cart_2',
        title: 'Milano Truffle Crust Pizza',
        restaurant: "Milano Pizza Outlet",
        price: 14.50,
        quantity: 1,
        imagePath: 'assets/images/pizza_milano.png',
        size: 'Large',
        addons: ['Extra Cheese'],
      ),
    );
    notifyListeners();
  }

  void toggleDelivery(bool isDelivery) {
    _isDelivery = isDelivery;
    notifyListeners();
  }

  void setAddressIndex(int index) {
    if (index >= 0 && index < demoAddressOptions.length) {
      _selectedAddressIndex = index;
      notifyListeners();
    }
  }

  void setAddress(String address) {
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  bool claimVoucher(String code) {
    final idx = _vouchers.indexWhere((v) => v.code == code);
    if (idx >= 0 && !_vouchers[idx].isClaimed) {
      _vouchers[idx].isClaimed = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void applyVoucher(String code, double percent) {
    _selectedVoucher = code;
    _voucherDiscountPercent = percent;
    notifyListeners();
  }

  void applyVoucherModel(VoucherModel voucher) {
    _selectedVoucher = voucher.code;
    _voucherDiscountPercent = voucher.discountPercent;
    notifyListeners();
  }

  void toggleBookmark(String id) {
    if (_bookmarkedIds.contains(id)) {
      _bookmarkedIds.remove(id);
    } else {
      _bookmarkedIds.add(id);
    }
    notifyListeners();
  }

  void placeNewOrder() {
    _hasActiveOrder = true;
    _activeOrderId = '#FD-${1000 + DateTime.now().millisecond}';
    _orderStepIndex = 0; // Mulai dari 0 (Diterima / Confirmed)
    notifyListeners();
  }

  void setOrderStep(int step) {
    if (_orderStepIndex != step) {
      _orderStepIndex = step;
      notifyListeners();
    }
  }

  void advanceOrderStep() {
    if (_orderStepIndex < 3) {
      _orderStepIndex++;
      notifyListeners();
    }
  }

  void resetOrder() {
    _hasActiveOrder = false;
    _orderStepIndex = 0;
    notifyListeners();
  }

  void completeOrder() {
    _hasActiveOrder = false;
    _orderStepIndex = 4;
    notifyListeners();
  }
}
