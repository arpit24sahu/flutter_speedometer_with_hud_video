import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  // Replace with your RevenueCat API keys
  static final String _apiKeyAndroid = dotenv.get("REVENUECAT_API_KEY_ANDROID");
  // static const String _apiKeyIOS = 'YOUR_IOS_API_KEY';

  // Replace with your actual product ID and entitlement ID
  static const String _premiumProductId = 'turbogauge_premium_lifetime';
  static const String _premiumEntitlementId = 'pro';

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  final _premiumStatusController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  Future<void> initialize() async {
    try {
      // Configure RevenueCat with the appropriate API key
      final apiKey = _apiKeyAndroid;
      // final apiKey = defaultTargetPlatform == TargetPlatform.iOS
      //     ? _apiKeyIOS
      //     : _apiKeyAndroid;

      await Purchases.setLogLevel(LogLevel.debug); // Remove in production

      await Purchases.configure(PurchasesConfiguration(apiKey));

      // Add listener for customer info changes
      Purchases.addCustomerInfoUpdateListener(_customerInfoListener);

      // Check initial status
      await _updatePremiumStatus();
    } catch (e) {
      print('Failed to initialize RevenueCat: $e');
      // Still broadcast as non-premium if initialization fails
      _premiumStatusController.add(false);
    }
  }

  void _customerInfoListener(CustomerInfo customerInfo) {
    final newPremiumStatus = customerInfo.entitlements.active.containsKey(_premiumEntitlementId);
    if (newPremiumStatus != _isPremium) {
      _isPremium = newPremiumStatus;
      _premiumStatusController.add(_isPremium);
    }
  }

  Future<void> _updatePremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _isPremium = customerInfo.entitlements.active.containsKey(_premiumEntitlementId);
      _premiumStatusController.add(_isPremium);
    } catch (e) {
      print('Failed to get customer info: $e');
      _premiumStatusController.add(false);
    }
  }

  Future<bool> purchasePremium() async {
    try {
      final offerings = await Purchases.getOfferings();

      if (offerings.current == null) {
        print('No offerings available');
        return false;
      }

      // Find the package with our product ID
      final package = offerings.current?.availablePackages.firstWhere(
            (p) => p.storeProduct.identifier == _premiumProductId,
        orElse: () => offerings.current!.availablePackages.first, // Fallback to first package
      );

      if (package == null) {
        print('No packages available');
        return false;
      }

      // Make the purchase
      final purchaserInfo = await Purchases.purchasePackage(package);
      final isPremium = purchaserInfo.entitlements.active.containsKey(_premiumEntitlementId);

      return isPremium;
    } catch (e) {
      print('Purchase failed: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final purchaserInfo = await Purchases.restorePurchases();
      return purchaserInfo.entitlements.active.containsKey(_premiumEntitlementId);
    } catch (e) {
      print('Restore purchases failed: $e');
      return false;
    }
  }

  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_customerInfoListener);
    _premiumStatusController.close();
  }
}
