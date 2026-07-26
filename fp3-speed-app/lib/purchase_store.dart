import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseStore extends ChangeNotifier {
  PurchaseStore._(this._prefs);

  static const String fullUnlockProductId = 'jp.allsunday.fp3speed.fullunlock';
  static const String _premiumKey = 'fp3_premium_unlocked_v1';

  final SharedPreferencesAsync _prefs;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Timer? _restoreTimeout;
  ProductDetails? fullUnlockProduct;

  bool isPremium = false;
  bool storeAvailable = false;
  bool isLoading = true;
  bool purchasePending = false;
  bool isRestoring = false;
  String? errorMessage;
  String? statusMessage;

  String get priceLabel => fullUnlockProduct?.price ?? '価格を取得中';

  static Future<PurchaseStore> load() async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    final PurchaseStore store = PurchaseStore._(prefs);
    store.isPremium = await prefs.getBool(_premiumKey) ?? false;
    unawaited(store._initialize());
    return store;
  }

  Future<void> _initialize() async {
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _restoreTimeout?.cancel();
        errorMessage = '購入情報を受信できませんでした。';
        purchasePending = false;
        isRestoring = false;
        notifyListeners();
      },
    );

    try {
      storeAvailable = await _iap.isAvailable();
      if (storeAvailable) {
        final ProductDetailsResponse response = await _iap.queryProductDetails(
          const <String>{fullUnlockProductId},
        );
        if (response.error != null) {
          errorMessage = response.error!.message;
        }
        if (response.productDetails.isNotEmpty) {
          fullUnlockProduct = response.productDetails.first;
        } else if (response.notFoundIDs.contains(fullUnlockProductId)) {
          errorMessage = 'App Storeの商品設定が未完了です。';
        }
      } else {
        errorMessage = 'App Storeに接続できません。';
      }
    } catch (_) {
      errorMessage = '購入商品の読み込みに失敗しました。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> buyFullUnlock() async {
    if (isPremium || purchasePending) return;
    final ProductDetails? product = fullUnlockProduct;
    if (!storeAvailable || product == null) {
      errorMessage = '購入商品を読み込めません。時間を置いて再度お試しください。';
      notifyListeners();
      return;
    }

    errorMessage = null;
    statusMessage = null;
    purchasePending = true;
    notifyListeners();

    try {
      final PurchaseParam param = PurchaseParam(productDetails: product);
      final bool started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        purchasePending = false;
        errorMessage = '購入画面を開始できませんでした。';
        notifyListeners();
      }
    } catch (_) {
      purchasePending = false;
      errorMessage = '購入処理を開始できませんでした。';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (purchasePending || isRestoring) return;
    errorMessage = null;
    statusMessage = null;
    isRestoring = true;
    _restoreTimeout?.cancel();
    notifyListeners();
    try {
      await _iap.restorePurchases();
      _restoreTimeout = Timer(const Duration(seconds: 5), () {
        if (!isRestoring) return;
        isRestoring = false;
        statusMessage = isPremium
            ? '購入済みの全問題パックを確認しました。'
            : '復元対象が見つかりませんでした。';
        notifyListeners();
      });
    } catch (_) {
      _restoreTimeout?.cancel();
      errorMessage = '購入の復元に失敗しました。';
      isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    bool changed = false;

    for (final PurchaseDetails purchase in purchases) {
      if (purchase.productID != fullUnlockProductId) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        purchasePending = true;
        changed = true;
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final bool valid = _verifyPurchase(purchase);
        if (valid) {
          await _setPremium(true);
          errorMessage = null;
          statusMessage = purchase.status == PurchaseStatus.restored
              ? '購入済みの全問題パックを復元しました。'
              : '全600問を解放しました。';
        } else {
          errorMessage = '購入情報を確認できませんでした。';
        }
        purchasePending = false;
        isRestoring = false;
        _restoreTimeout?.cancel();
        changed = true;
      } else if (purchase.status == PurchaseStatus.error) {
        _restoreTimeout?.cancel();
        errorMessage = purchase.error?.message ?? '購入に失敗しました。';
        purchasePending = false;
        isRestoring = false;
        changed = true;
      } else if (purchase.status == PurchaseStatus.canceled) {
        _restoreTimeout?.cancel();
        purchasePending = false;
        isRestoring = false;
        statusMessage = '購入はキャンセルされました。';
        changed = true;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    if (isRestoring && purchases.isNotEmpty) {
      isRestoring = false;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // 初期版は外部サーバーを持たないため、StoreKit/Playが返した購入データを
  // 端末側で確認する。公開前にSandboxで改ざん・復元ケースを重点検証する。
  bool _verifyPurchase(PurchaseDetails purchase) {
    if (purchase.productID != fullUnlockProductId) return false;
    final PurchaseVerificationData data = purchase.verificationData;
    return data.localVerificationData.isNotEmpty ||
        data.serverVerificationData.isNotEmpty;
  }

  Future<void> _setPremium(bool value) async {
    isPremium = value;
    await _prefs.setBool(_premiumKey, value);
  }

  @override
  void dispose() {
    _restoreTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
