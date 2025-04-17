import '../service/purchase_service.dart';

class PurchaseRepository {
  final PurchaseService _purchaseService;

  PurchaseRepository(this._purchaseService);

  bool get isPremium => _purchaseService.isPremium;
  Stream<bool> get premiumStatusStream => _purchaseService.premiumStatusStream;

  Future<void> initialize() async {
    await _purchaseService.initialize();
  }

  Future<bool> purchasePremium() async {
    return await _purchaseService.purchasePremium();
  }

  Future<bool> restorePurchases() async {
    return await _purchaseService.restorePurchases();
  }
}
