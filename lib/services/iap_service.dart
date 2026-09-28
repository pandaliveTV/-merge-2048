import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'storage_service.dart';

/// "Remove Ads" non-consumable purchase.
/// Create a managed (one-time) product with this id in Google Play Console.
class IapService extends ChangeNotifier {
  static const removeAdsId = 'remove_ads';

  final StorageService storage;
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;

  IapService(this.storage);

  Future<void> init() async {
    try {
      if (!await _iap.isAvailable()) return;
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      final res = await _iap.queryProductDetails({removeAdsId});
      if (res.productDetails.isNotEmpty) {
        product = res.productDetails.first;
        notifyListeners();
      }
    } catch (_) {
      // Billing unavailable (emulator without Play Store, etc.).
    }
  }

  Future<bool> buyRemoveAds() async {
    final p = product;
    if (p == null) return false;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: p),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  void _onPurchases(List<PurchaseDetails> list) {
    for (final p in list) {
      if (p.productID == removeAdsId &&
          (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored)) {
        storage.setAdsRemoved(true);
      }
      if (p.pendingCompletePurchase) _iap.completePurchase(p);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
