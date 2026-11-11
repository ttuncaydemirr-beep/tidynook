// Google Play in-app review, asked ONCE: when the player returns to the house after completing
// level 6, never right after a full-screen ad. Play itself decides whether the sheet really appears
// (quota), so the game never shows its own "rate us" text and never knows the result.
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../monet/env.dart';

/// Levels the player must have completed before the review is asked.
const int kReviewAfterLevels = 6;

/// No review prompt within this long after an interstitial or rewarded ad.
const int kReviewAdGapMs = 60 * 1000;

/// Pure rule (unit-tested).
bool shouldAskReview({
  required bool alreadyAsked,
  required int completedLevels,
  required int lastFullScreenAdMs,
  required int nowMs,
}) {
  if (alreadyAsked || completedLevels < kReviewAfterLevels) {
    return false;
  }
  if (lastFullScreenAdMs > 0 && nowMs >= lastFullScreenAdMs && nowMs - lastFullScreenAdMs < kReviewAdGapMs) {
    return false;
  }
  return true;
}

class ReviewPrompt {
  ReviewPrompt({bool? enabled}) : _enabled = enabled ?? MonetEnv.pluginsEnabled;

  final bool _enabled;
  bool _busy = false;

  /// Call when the player arrives back on the house screen (after the interstitial, if any).
  /// [markAsked] is called before Play is asked, so it can never be asked twice
  /// (wire it to Progress: reviewAsked = true and save). Returns true if Play was asked. Never throws.
  Future<bool> maybeAsk({
    required bool alreadyAsked,
    required int completedLevels,
    required int lastFullScreenAdMs,
    required VoidCallback markAsked,
    int? nowMs,
  }) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (_busy ||
        !shouldAskReview(
          alreadyAsked: alreadyAsked,
          completedLevels: completedLevels,
          lastFullScreenAdMs: lastFullScreenAdMs,
          nowMs: now,
        )) {
      return false;
    }
    if (!_enabled) {
      return false;
    }
    _busy = true;
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) {
        return false; // try again on a later visit
      }
      try {
        markAsked();
      } catch (_) {}
      await review.requestReview();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Review: $e');
      }
      return false;
    } finally {
      _busy = false;
    }
  }
}
