import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../domain/monetization_models.dart';
import '../../domain/subscription_state.dart';
import '../../services/subscription_service.dart';

class RevenueCatSubscriptionService implements SubscriptionService {
  RevenueCatSubscriptionService({required this.apiKey});

  final String apiKey;
  static const entitlementId = 'pantrypilot_premium';
  static const monthlyProductId = 'pantrypilot_premium_monthly';
  static const yearlyProductId = 'pantrypilot_premium_yearly';

  final _controller = StreamController<SubscriptionState>.broadcast();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured || apiKey.isEmpty) return;
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _controller.add(_fromCustomerInfo(customerInfo));
    });
    _configured = true;
  }

  @override
  Future<SubscriptionState> fetchCurrent() async {
    await _ensureConfigured();
    if (apiKey.isEmpty) return SubscriptionState.free();
    try {
      final customer = await Purchases.getCustomerInfo();
      return _fromCustomerInfo(customer);
    } catch (_) {
      return SubscriptionState.free();
    }
  }

  @override
  Future<List<PremiumProduct>> loadOfferings() async {
    await _ensureConfigured();
    if (apiKey.isEmpty) {
      throw const PurchaseFailure(PurchaseFailureReason.serviceUnavailable, message: 'RevenueCat API key missing.');
    }
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) return const [];

    final products = <PremiumProduct>[];
    for (final package in current.availablePackages) {
      final mapped = _mapPackage(package);
      if (mapped != null) {
        products.add(mapped);
      }
    }
    return products;
  }

  PremiumProduct? _mapPackage(Package package) {
    final id = package.storeProduct.identifier;
    if (id != monthlyProductId && id != yearlyProductId) return null;
    return PremiumProduct(
      plan: id == monthlyProductId ? PremiumPlanProduct.monthly : PremiumPlanProduct.yearly,
      productId: id,
      displayName: package.storeProduct.title,
      priceLabel: package.storeProduct.priceString,
      description: package.storeProduct.description,
    );
  }

  @override
  Future<void> startPremiumCheckout(PremiumPlanProduct plan) async {
    await _ensureConfigured();
    final products = await loadOfferings();
    PremiumProduct? selected;
    for (final product in products) {
      if (product.plan == plan) {
        selected = product;
        break;
      }
    }
    if (selected == null) {
      throw const PurchaseFailure(PurchaseFailureReason.serviceUnavailable, message: 'Selected plan is unavailable.');
    }

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      final package = current?.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == selected.productId,
        orElse: () => throw const PurchaseFailure(PurchaseFailureReason.serviceUnavailable, message: 'Offer package missing.'),
      );
      if (package == null) {
        throw const PurchaseFailure(PurchaseFailureReason.serviceUnavailable, message: 'Offer package missing.');
      }
      await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      if (e.code.contains('purchaseCancelledError')) {
        throw const PurchaseFailure(PurchaseFailureReason.cancelled);
      }
      throw PurchaseFailure(PurchaseFailureReason.unknown, message: e.message);
    }
  }

  @override
  Future<void> restorePurchases() async {
    await _ensureConfigured();
    if (apiKey.isEmpty) return;
    final restored = await Purchases.restorePurchases();
    _controller.add(_fromCustomerInfo(restored));
  }

  @override
  Stream<SubscriptionState> watchSubscription() async* {
    yield await fetchCurrent();
    yield* _controller.stream;
  }

  SubscriptionState _fromCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.all[entitlementId];
    if (entitlement == null || !entitlement.isActive) {
      return SubscriptionState.free().copyWith(lastUpdated: DateTime.now());
    }
    return SubscriptionState(
      plan: SubscriptionPlan.premium,
      billingState: BillingState.active,
      productId: entitlement.productIdentifier,
      renewalDate: entitlement.expirationDate == null ? null : DateTime.tryParse(entitlement.expirationDate!),
      lastUpdated: DateTime.now(),
    );
  }

  void dispose() {
    _controller.close();
  }
}
