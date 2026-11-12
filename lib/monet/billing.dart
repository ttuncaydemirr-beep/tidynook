// Google Play Billing for Tidy Nook (ported from Arrowtile's services/billing_service.dart), two
// NON-consumable products:
//   remove_ads      no interstitials (rewarded ads stay available as an optional choice; there is no banner)
//   supporter_pack  everything in remove_ads + the 3rd style of every piece + the puppy
//
//  - At start (and on restore) Play is asked what the player owns; the result is pushed through the
//    [Billing.onEntitlements] callback (wire it to Progress.setEntitlements). Progress caches it, so
//    offline starts keep the entitlements.
//  - PURCHASED: entitlement granted, the purchase is acknowledged (completePurchase). Play refunds
//    purchases that are not acknowledged within 3 days.
//  - PENDING (e.g. cash payment at a shop): NOTHING is granted and nothing is acknowledged; the UI
//    says "Your purchase is pending". When it completes it arrives on the purchase stream (or at the
//    next start / restore) and is granted then.
//  - Restore that Play ANSWERS replaces the entitlements (a refund removes them); a failed query
//    (offline) changes nothing.
//  - No server verification (a single-player game without a server).
// Everything is a no-op on the web, in tests and off Android ([MonetEnv.pluginsEnabled]); nothing throws.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show PurchaseStateWrapper;
import 'package:in_app_purchase_android/in_app_purchase_android.dart' show GooglePlayPurchaseDetails;

import 'env.dart';

/// What happened to a purchase, for UI messages.
enum PurchaseEventKind {
  /// Bought now (or a pending payment completed): show "Thank you for your support!".
  success,

  /// Waiting for payment: show "Your purchase is pending.".
  pending,

  /// Did not go through: show "The purchase did not go through.".
  failed,

  /// The player closed the Play sheet: show nothing.
  cancelled,

  /// A restore finished (whatever was found): show "Purchases restored.".
  restored,
}

@immutable
class PurchaseEvent {
  const PurchaseEvent(this.kind, this.productId);
  final PurchaseEventKind kind;

  /// The product, or '' for a restore.
  final String productId;

  @override
  String toString() => 'PurchaseEvent($kind, $productId)';
}

/// The entitlements that follow from the owned products (pure, unit-tested).
({bool adsRemoved, bool supporter}) entitlementsFor(Set<String> owned) {
  final supporter = owned.contains(Billing.supporterId);
  return (adsRemoved: supporter || owned.contains(Billing.removeAdsId), supporter: supporter);
}

/// Signature of Progress.setEntitlements, so a tear-off can be passed directly.
typedef EntitlementSink = void Function({required bool adsRemoved, required bool supporter});

class Billing {
  Billing({
    required this.onEntitlements,
    bool adsRemoved = false,
    bool supporter = false,
    bool? enabled,
  }) : _enabled = enabled ?? MonetEnv.pluginsEnabled {
    if (supporter) {
      _owned.add(supporterId);
    } else if (adsRemoved) {
      _owned.add(removeAdsId);
    }
  }

  static const String removeAdsId = 'remove_ads';
  static const String supporterId = 'supporter_pack';
  static const Set<String> productIds = <String>{removeAdsId, supporterId};

  /// Receives every entitlement change (wire to Progress.setEntitlements).
  final EntitlementSink onEntitlements;

  final bool _enabled;
  InAppPurchase? _iap; // touched only when enabled (no platform channel in tests / on the web)
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};
  final Set<String> _owned = <String>{};
  final StreamController<PurchaseEvent> _events = StreamController<PurchaseEvent>.broadcast();
  Completer<bool?>? _restore;
  final Set<String> _buying = <String>{};
  bool _available = false;
  bool _disposed = false;
  bool _initStarted = false;

  /// Play Billing answered isAvailable() with true.
  bool get available => _available;

  bool owns(String id) => _owned.contains(id) || (id == removeAdsId && _owned.contains(supporterId));
  bool get adsRemoved => entitlementsFor(_owned).adsRemoved;
  bool get supporter => entitlementsFor(_owned).supporter;

  /// Purchase results and restores, for UI messages (snack bars).
  Stream<PurchaseEvent> get events => _events.stream;

  /// Localized price from Play ("₺59,99", "\$2.99"), null if unknown (offline / product not set up).
  String? priceOf(String id) => _products[id]?.price;

  /// Raw price and currency (analytics).
  double? rawPriceOf(String id) => _products[id]?.rawPrice;
  String? currencyOf(String id) => _products[id]?.currencyCode;

  static void _log(String m) {
    if (kDebugMode) {
      debugPrint('Billing: $m');
    }
  }

  /// Listens to the purchase stream, loads the prices and asks Play what is owned. Never throws.
  Future<void> init() async {
    if (!_enabled || _initStarted || _disposed) {
      return;
    }
    _initStarted = true;
    try {
      final iap = InAppPurchase.instance;
      _iap = iap;
      _sub = iap.purchaseStream.listen(
        (List<PurchaseDetails> list) => unawaited(_onPurchases(list)),
        onError: (Object e) => _log('purchase stream: $e'),
      );
      _available = await iap.isAvailable();
      if (_available) {
        unawaited(_queryProducts());
        unawaited(_restoreQuiet());
      }
    } catch (e) {
      _log('init: $e');
      _available = false;
    }
  }

  Future<void> _queryProducts() async {
    final iap = _iap;
    if (iap == null) {
      return;
    }
    try {
      final r = await iap.queryProductDetails(productIds);
      for (final p in r.productDetails) {
        _products[p.id] = p;
      }
      if (r.notFoundIDs.isNotEmpty) {
        _log('not found in Play Console (active?): ${r.notFoundIDs}');
      }
    } catch (e) {
      _log('queryProductDetails: $e');
    }
  }

  /// Starts the Play purchase sheet. The result arrives on [events]. Never throws.
  Future<void> buy(String id) async {
    if (!productIds.contains(id)) {
      return;
    }
    final iap = _iap;
    if (!_enabled || iap == null || !_available) {
      _emit(PurchaseEventKind.failed, id);
      return;
    }
    if (owns(id)) {
      _emit(PurchaseEventKind.success, id);
      return;
    }
    var pd = _products[id];
    if (pd == null) {
      await _queryProducts();
      pd = _products[id];
    }
    if (pd == null) {
      _emit(PurchaseEventKind.failed, id);
      return;
    }
    _buying.add(id);
    try {
      final started = await iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: pd));
      if (!started) {
        _buying.remove(id);
        // usually ITEM_ALREADY_OWNED: ask Play again
        final owned = await _restoreQuiet();
        _emit(owned == true && owns(id) ? PurchaseEventKind.success : PurchaseEventKind.failed, id);
      }
    } catch (e) {
      _log('buyNonConsumable: $e');
      _buying.remove(id);
      // ITEM_ALREADY_OWNED is also reported as an exception by some plugin versions
      final owned = await _restoreQuiet();
      _emit(owned == true && owns(id) ? PurchaseEventKind.success : PurchaseEventKind.failed, id);
    }
  }

  /// Settings > Restore purchases. Emits [PurchaseEventKind.restored] when Play answered,
  /// [PurchaseEventKind.failed] when it could not be asked (offline). Never throws.
  Future<void> restore() async {
    final r = await _restoreQuiet();
    _emit(r == null ? PurchaseEventKind.failed : PurchaseEventKind.restored, '');
  }

  /// Asks Play what is owned. true/false = some product is owned / nothing, null = query failed.
  Future<bool?> _restoreQuiet() async {
    final iap = _iap;
    if (!_enabled || iap == null || !_available || _disposed) {
      return null;
    }
    final old = _restore;
    if (old != null && !old.isCompleted) {
      return old.future;
    }
    final c = Completer<bool?>();
    _restore = c;
    try {
      await iap.restorePurchases();
    } catch (e) {
      _log('restorePurchases: $e');
      if (identical(_restore, c)) {
        _restore = null;
      }
      if (!c.isCompleted) {
        c.complete(null);
      }
      return c.future;
    }
    return c.future.timeout(const Duration(seconds: 20), onTimeout: () {
      if (identical(_restore, c)) {
        _restore = null;
      }
      return null;
    });
  }

  /// Android reports pending purchases as "restored" too; read the real state.
  static bool _reallyPurchased(PurchaseDetails p) {
    if (p is GooglePlayPurchaseDetails) {
      return p.billingClientPurchase.purchaseState == PurchaseStateWrapper.purchased;
    }
    return p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    if (_disposed) {
      return;
    }
    final iap = _iap;
    final bought = <String>{};
    final pending = <String>{};
    final failed = <String>{};
    final cancelled = <String>{};
    var sawRestored = false;
    for (final p in list) {
      final id = p.productID;
      if (!productIds.contains(id)) {
        if (p.pendingCompletePurchase && iap != null) {
          try {
            await iap.completePurchase(p);
          } catch (_) {}
        }
        continue;
      }
      if (p.status == PurchaseStatus.restored) {
        sawRestored = true;
      }
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_reallyPurchased(p)) {
            bought.add(id);
            if (p.pendingCompletePurchase && iap != null) {
              try {
                await iap.completePurchase(p); // acknowledge
              } catch (e) {
                _log('completePurchase: $e');
              }
            }
          } else {
            pending.add(id);
          }
        case PurchaseStatus.pending:
          pending.add(id);
        case PurchaseStatus.canceled:
          cancelled.add(id);
        case PurchaseStatus.error:
          failed.add(id);
      }
    }

    final rc = _restore;
    final isRestoreAnswer = rc != null && !rc.isCompleted && (list.isEmpty || sawRestored);
    if (isRestoreAnswer) {
      // Play's full answer: replace what we know (a refunded product goes away).
      _setOwned(bought);
    } else if (bought.isNotEmpty) {
      _setOwned(<String>{..._owned, ...bought});
    }

    for (final id in bought) {
      if (_buying.remove(id) || !isRestoreAnswer) {
        _emit(PurchaseEventKind.success, id);
      }
    }
    for (final id in pending) {
      if (_buying.remove(id) || !isRestoreAnswer) {
        _emit(PurchaseEventKind.pending, id);
      }
    }
    for (final id in cancelled) {
      _buying.remove(id);
      _emit(PurchaseEventKind.cancelled, id);
    }
    for (final id in failed) {
      _buying.remove(id);
      _emit(PurchaseEventKind.failed, id);
    }

    if (isRestoreAnswer && rc != null) {
      _restore = null;
      rc.complete(bought.isNotEmpty);
    }
  }

  void _setOwned(Set<String> next) {
    final before = entitlementsFor(_owned);
    _owned
      ..clear()
      ..addAll(next);
    final after = entitlementsFor(_owned);
    if (before != after) {
      try {
        onEntitlements(adsRemoved: after.adsRemoved, supporter: after.supporter);
      } catch (e) {
        _log('onEntitlements: $e');
      }
    }
  }

  void _emit(PurchaseEventKind kind, String id) {
    if (_disposed || _events.isClosed) {
      return;
    }
    _events.add(PurchaseEvent(kind, id));
  }

  /// Test hook: feed purchase updates as if they came from Play.
  @visibleForTesting
  Future<void> debugHandle(List<PurchaseDetails> list, {bool asRestoreAnswer = false}) async {
    if (asRestoreAnswer) {
      _restore = Completer<bool?>();
    }
    await _onPurchases(list);
  }

  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    _sub = null;
    unawaited(_events.close());
  }
}
