import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Replace with your actual product ID from App Store Connect / Play Console
  static const String productId = 'com.example.rearticleapp.fullaccess';

  bool _isPurchased = false;
  bool get isPurchased => _isPurchased;

  Future<void> initialize() async {
    // Check if purchases are available on this device
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      return;
    }

    // Load purchase status from local storage
    await _loadPurchaseStatus();

    // Listen to purchase updates
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: _onPurchaseDone,
      onError: _onPurchaseError,
    );

    // Check for pending purchases
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _loadPurchaseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPurchased = prefs.getBool('app_purchased') ?? false;
  }

  Future<void> _savePurchaseStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_purchased', status);
    _isPurchased = status;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Handle pending purchase
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle error
        _handleError(purchaseDetails.error!);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Verify and deliver the purchase
        _verifyPurchase(purchaseDetails);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In production, verify the purchase with your backend server
    // For now, we'll just save it locally
    await _savePurchaseStatus(true);
  }

  void _handleError(IAPError error) {
    debugPrint('Purchase error: ${error.message}');
  }

  void _onPurchaseDone() {
    _subscription?.cancel();
  }

  void _onPurchaseError(error) {
    debugPrint('Purchase stream error: $error');
  }

  Future<bool> buyProduct() async {
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({productId});

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Product not found: ${response.notFoundIDs}');
      return false;
    }

    if (response.productDetails.isEmpty) {
      debugPrint('No products available');
      return false;
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }
}