import 'package:speedometer/features/badges/badge_manager.dart';

import '../../../di/injection_container.dart';
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
    bool isPremium = await _purchaseService.purchasePremium();
    if(isPremium) getIt<BadgeManager>().purchasePremium();
    return isPremium;
  }

  Future<bool> restorePurchases() async {
    bool isPremium = await _purchaseService.restorePurchases();
    if(isPremium) getIt<BadgeManager>().purchasePremium();
    return isPremium;
  }
}
