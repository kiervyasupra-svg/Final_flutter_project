import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/store_repository.dart';

class StoreController extends ChangeNotifier {
  final StoreRepository _repo = StoreRepository();

  List<ProductModel> _products = [];
  final Map<ProductModel, int> _cart = {};
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<List<ProductModel>>? _productsSubscription;

  List<ProductModel> get products => _products;
  Map<ProductModel, int> get cart => _cart;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get cartTotal => _cart.entries
      .fold(0.0, (sum, entry) => sum + (entry.key.price * entry.value));

  int get cartCount => _cart.values.fold(0, (sum, qty) => sum + qty);

  StoreController() {
    _listenProducts();
  }

  void _listenProducts() {
    _productsSubscription = _repo.getProducts().listen(
      (productList) {
        _products = productList;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = 'Unable to load store items.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }

  void addToCart(ProductModel product) {
    if (product.availableStock <= 0) return;
    final quantity = _cart[product];
    if (quantity != null) {
      if (quantity < product.availableStock) {
        _cart[product] = quantity + 1;
      }
    } else {
      _cart[product] = 1;
    }
    notifyListeners();
  }

  void removeFromCart(ProductModel product) {
    final quantity = _cart[product];
    if (quantity != null) {
      if (quantity > 1) {
        _cart[product] = quantity - 1;
      } else {
        _cart.remove(product);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<bool> checkoutWithWallet({
    required String userId,
    required double currentBalance,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repo.placeOrder(
        userId: userId,
        customerName: '',
        customerEmail: '',
        items: Map.from(_cart),
        paymentMethod: 'wallet',
      );
      clearCart();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> redeemWithPoints({
    required String userId,
    required int currentPoints,
    required ProductModel product,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repo.placeOrder(
        userId: userId,
        customerName: '',
        customerEmail: '',
        items: {product: 1},
        paymentMethod: 'points',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> placeOrder({
    required String userId,
    required String customerName,
    required String customerEmail,
    required Map<ProductModel, int> items,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final orderId = await _repo.placeOrder(
        userId: userId,
        customerName: customerName,
        customerEmail: customerEmail,
        items: items,
        paymentMethod: paymentMethod,
      );
      return orderId;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestTopUp({
    required String userId,
    required double amount,
    required File imageFile,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repo.submitTopUpRequest(
        userId: userId,
        amount: amount,
        imageFile: imageFile,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
