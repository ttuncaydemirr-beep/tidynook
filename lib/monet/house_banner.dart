// Adaptive anchored banner for the bottom of the HOUSE screen only (ported from Arrowtile's ui/ad_banner.dart).
//
//  - Takes NO space until an ad has loaded (SizedBox.shrink), and none when ads are removed, the SDK is
//    not ready (consent), on the web, in tests, or when [visible] is false. No reserved empty gap.
//  - Once loaded it is a full-width strip as tall as the ad; put it as the LAST child of the house
//    screen's Column (inside SafeArea), with the house content in an Expanded above it.
//  - Disappears at once after a purchase (Ads.entitlementsChanged / a rebuild with adsRemoved).
//  - A failed load is retried after 60 s while the screen stays open; a width change reloads it.
//  - The platform view is attached only after the route's transition has finished (Arrowtile 1.1.5).
//  - When covered by another route (TickerMode off) the ad is released, so only one AdView lives at a time.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads.dart';
import 'ads_config.dart';
import 'env.dart';

/// A loaded banner: the widget to draw, its size and how to release it.
class BannerHandle {
  const BannerHandle(this.view, this.size, this.dispose);
  final Widget view;
  final Size size;
  final VoidCallback dispose;
}

/// Loads one banner for [width] logical pixels; calls exactly one of [onLoaded] / [onFailed].
typedef BannerLoader = void Function(
  int width, {
  required void Function(BannerHandle h) onLoaded,
  required void Function(int code, String message) onFailed,
});

/// The real AdMob loader.
void googleBannerLoader(
  int width, {
  required void Function(BannerHandle h) onLoaded,
  required void Function(int code, String message) onFailed,
}) {
  unawaited(() async {
    AnchoredAdaptiveBannerAdSize? size;
    try {
      size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      // ignore: deprecated_member_use
      size ??= await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    } catch (e) {
      onFailed(-2, 'adaptive size exception: $e');
      return;
    }
    if (size == null) {
      onFailed(-3, 'adaptive size null (width=$width)');
      return;
    }
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: AdsConfig.bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad a) {
          onLoaded(BannerHandle(
            AdWidget(ad: ad),
            Size(ad.size.width.toDouble(), ad.size.height.toDouble()),
            () => a.dispose(),
          ));
        },
        onAdFailedToLoad: (Ad a, LoadAdError error) {
          a.dispose();
          onFailed(error.code, error.message);
        },
      ),
    );
    try {
      await ad.load();
    } catch (e) {
      try {
        ad.dispose();
      } catch (_) {}
      onFailed(-4, 'load exception: $e');
    }
  }());
}

class HouseBanner extends StatefulWidget {
  const HouseBanner({super.key, required this.ads, this.visible = true, this.label});

  /// null = no ads at all (the widget is always empty).
  final Ads? ads;

  /// false hides the banner (e.g. while a sheet covers the house screen).
  final bool visible;

  /// Optional small text drawn above a loaded banner (e.g. the translated "Advertisement").
  final String? label;

  /// Tests: a fake loader instead of AdMob.
  @visibleForTesting
  static BannerLoader? debugLoader;

  /// Tests: pretend the platform supports banners.
  @visibleForTesting
  static bool debugForceEnabled = false;

  @visibleForTesting
  static Duration retryAfter = const Duration(seconds: 60);

  @override
  State<HouseBanner> createState() => _HouseBannerState();
}

class _HouseBannerState extends State<HouseBanner> {
  Animation<double>? _routeAnim;
  BannerHandle? _ad;
  bool _loading = false;
  int _gen = 0;
  int _width = 0;
  Timer? _retry;

  bool get _platformOk => HouseBanner.debugForceEnabled || (MonetEnv.pluginsEnabled && !kIsWeb);

  bool get _settled => _routeAnim == null || _routeAnim!.status == AnimationStatus.completed;

  @override
  void initState() {
    super.initState();
    widget.ads?.addListener(_onAds);
  }

  @override
  void didUpdateWidget(HouseBanner old) {
    super.didUpdateWidget(old);
    if (!identical(old.ads, widget.ads)) {
      old.ads?.removeListener(_onAds);
      widget.ads?.addListener(_onAds);
      _drop();
    }
  }

  void _onAds() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onRouteStatus(AnimationStatus st) {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final a = ModalRoute.of(context)?.animation;
    if (!identical(a, _routeAnim)) {
      _routeAnim?.removeStatusListener(_onRouteStatus);
      _routeAnim = a;
      a?.addStatusListener(_onRouteStatus);
    }
  }

  bool _want() {
    final ads = widget.ads;
    if (ads == null || !widget.visible || !_platformOk) {
      return false;
    }
    try {
      return ads.bannerAllowed || (HouseBanner.debugForceEnabled && !ads.state.adsRemoved);
    } catch (_) {
      return false;
    }
  }

  void _drop() {
    _gen++;
    _retry?.cancel();
    _retry = null;
    try {
      _ad?.dispose();
    } catch (_) {}
    _ad = null;
    _loading = false;
  }

  void _scheduleRetry(Duration d) {
    _retry?.cancel();
    _retry = Timer(d, () {
      _retry = null;
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _load(int width) {
    if (_loading || _ad != null) {
      return;
    }
    if (width <= 0) {
      _scheduleRetry(const Duration(milliseconds: 500));
      return;
    }
    _loading = true;
    _width = width;
    final gen = ++_gen;
    final loader = HouseBanner.debugLoader ?? googleBannerLoader;
    var settled = false;
    try {
      loader(width, onLoaded: (BannerHandle h) {
        if (settled) {
          return;
        }
        settled = true;
        if (!mounted || gen != _gen) {
          h.dispose();
          return;
        }
        setState(() {
          _ad = h;
          _loading = false;
        });
      }, onFailed: (int code, String msg) {
        if (settled) {
          return;
        }
        settled = true;
        if (kDebugMode) {
          debugPrint('Ads: banner failed ($code): $msg');
        }
        if (!mounted || gen != _gen) {
          return;
        }
        setState(() {
          _ad = null;
          _loading = false;
        });
        _scheduleRetry(HouseBanner.retryAfter);
      });
    } catch (_) {
      settled = true;
      _loading = false;
      _scheduleRetry(HouseBanner.retryAfter);
    }
  }

  @override
  void dispose() {
    widget.ads?.removeListener(_onAds);
    _routeAnim?.removeStatusListener(_onRouteStatus);
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final want = TickerMode.of(context) && _want();
    if (!want) {
      if (_ad != null || _loading || _retry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          if (!(TickerMode.of(context) && _want())) {
            setState(_drop);
          }
        });
      }
      return const SizedBox.shrink();
    }
    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints bc) {
      final w = bc.maxWidth.isFinite ? bc.maxWidth.floor() : MediaQuery.sizeOf(ctx).width.floor();
      if (_ad == null && !_loading && _retry == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _want()) {
            _load(w);
          }
        });
      } else if (_ad != null && (_width - w).abs() > 8) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(_drop);
          }
        });
      }
      final ad = _ad;
      if (ad == null) {
        return const SizedBox.shrink();
      }
      final strip = SizedBox(
        key: const ValueKey<String>('house-banner'),
        width: double.infinity,
        height: ad.size.height,
        child: _settled ? Center(child: SizedBox(width: ad.size.width, height: ad.size.height, child: ad.view)) : null,
      );
      final label = widget.label;
      if (label == null || label.isEmpty) {
        return strip;
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0x99000000))),
          ),
          strip,
        ],
      );
    });
  }
}
