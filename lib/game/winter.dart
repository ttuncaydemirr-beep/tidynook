// The winter event (1.2): every year from 1 December to 15 January (local
// date), 7 handmade winter boxes reachable from a card on the house screen,
// snow on the house while the event runs, and a snowman for the garden when
// all 7 boxes of a season are done (kept forever). Exported by content.dart.
//
// Pure Dart: no widgets, no clock of its own (callers pass the local date).

import 'art.dart';
import 'content.dart';

/// Number of winter event boxes per season.
const int winterLevelCount = 7;

/// First and last day of the event window (inclusive), as month/day.
const int winterStartMonth = 12;
const int winterStartDay = 1;
const int winterEndMonth = 1;
const int winterEndDay = 15;

/// True while the winter event runs: local date 1 December .. 15 January
/// (both inclusive), every year, across the year change.
bool winterActive(DateTime now) {
  if (now.month == winterStartMonth) {
    return now.day >= winterStartDay;
  }
  if (now.month == winterEndMonth) {
    return now.day <= winterEndDay;
  }
  return false;
}

/// "Snow on the house": the UI passes this to houseSvg(snow: ...).
bool snowOnHouse(DateTime now) => winterActive(now);

/// The season a date belongs to, named after the December it starts in:
/// 2026-12-20 and 2027-01-10 are both season 2026. Outside the window it is
/// the season that ended last.
int winterSeasonOf(DateTime now) {
  return now.month == 12 ? now.year : now.year - 1;
}

/// Days left in the event including today (1 on 15 January), 0 outside it.
int winterDaysLeft(DateTime now) {
  if (!winterActive(now)) {
    return 0;
  }
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(winterSeasonOf(now) + 1, winterEndMonth, winterEndDay);
  // calendar days, not 24 h steps, so DST cannot shift the count
  var n = 0;
  var d = today;
  while (!d.isAfter(end)) {
    n++;
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return n;
}

/// The 7 winter boxes (handmade, gentle: 9 to 12 items, no drawers, no
/// mystery). Names: winterLevelName0..6.
final List<Level> winterLevels = _buildWinter();

List<Level> _buildWinter() {
  final r = Prim.rect;
  return <Level>[
    Level(
      outer: '#9FC3E6',
      inner: '#3D5F8C',
      dividers: [r(42, 200, 276, 6, 3, '#314D74')],
      slots: [Slot('mitten', 76.5, 135), Slot('beanie', 126, 138), Slot('mitten', 184.5, 135), Slot('beanie', 234, 138), Slot('mitten', 292.5, 135), Slot('scarf', 85.6, 265.5), Slot('scarf', 139.2, 265.5), Slot('beanie', 206.8, 269), Slot('scarf', 274.4, 265.5)],
    ), // 0 Mitten Basket
    Level(
      outer: '#D96C6C',
      inner: '#7A2E3A',
      dividers: [r(42, 200, 276, 6, 3, '#64242F')],
      slots: [Slot('ornament-rose', 76.7, 136.8), Slot('ornament-sky', 128.3, 136.8), Slot('ornament-sun', 180, 136.8), Slot('ornament-rose', 231.7, 136.8), Slot('ornament-sky', 283.3, 136.8), Slot('bell', 76.7, 270), Slot('ornament-sun', 128.3, 267.8), Slot('bell', 180, 270), Slot('ornament-rose', 231.7, 267.8), Slot('bell', 283.3, 270)],
    ), // 1 Ornament Box
    Level(
      outer: '#B8865B',
      inner: '#5A3A22',
      dividers: [r(42, 200, 276, 6, 3, '#472D1A')],
      slots: [Slot('gingerbread', 72.8, 135.5), Slot('cookie-star', 126.4, 138.3), Slot('gingerbread', 180, 135.5), Slot('cookie-star', 233.6, 138.3), Slot('gingerbread', 287.2, 135.5), Slot('candycane', 60.8, 264), Slot('cookie-star', 126.4, 269.3), Slot('candycane', 168, 264), Slot('cookie-star', 233.6, 269.3), Slot('candycane', 275.2, 264)],
    ), // 2 Cookie Tin
    Level(
      outer: '#E5A3A3',
      inner: '#6E3B3B',
      dividers: [r(42, 200, 276, 6, 3, '#5A2F2F')],
      slots: [Slot('cocoa', 72.3, 135.5), Slot('candycane', 116.7, 133), Slot('cocoa', 175, 135.5), Slot('candycane', 219.3, 133), Slot('cocoa', 277.7, 135.5), Slot('cookie-star', 75.9, 269.3), Slot('gingerbread', 130.9, 266.5), Slot('bell', 180, 270), Slot('gingerbread', 229.1, 266.5), Slot('cookie-star', 284.1, 269.3)],
    ), // 3 Cocoa Tray
    Level(
      outer: '#7FB8A8',
      inner: '#2C5E52',
      dividers: [r(42, 200, 276, 6, 3, '#234B42')],
      slots: [Slot('gift-rose', 69.1, 138), Slot('bell', 113.3, 139), Slot('gift-sky', 157.4, 138), Slot('gift-rose', 202.6, 138), Slot('bell', 246.7, 139), Slot('gift-sky', 290.9, 138), Slot('ornament-sun', 76, 267.8), Slot('gift-sky', 128, 269), Slot('ornament-rose', 180, 267.8), Slot('gift-rose', 232, 269), Slot('ornament-sky', 284, 267.8)],
    ), // 4 Gift Wrap Box
    Level(
      outer: '#A8B88A',
      inner: '#4A5A32',
      dividers: [r(42, 156, 276, 5, 2.5, '#3C4A28'), r(42, 242, 276, 5, 2.5, '#3C4A28')],
      slots: [Slot('pinecone', 74.1, 115.5), Slot('candle-rose', 115.3, 121), Slot('pinecone', 156.4, 115.5), Slot('pinecone', 203.6, 115.5), Slot('candle-rose', 244.7, 121), Slot('pinecone', 285.9, 115.5), Slot('pinecone', 93, 203), Slot('candle-sky', 153, 208.5), Slot('pinecone', 213, 203), Slot('candle-sky', 273, 208.5), Slot('beanie', 129, 289.5), Slot('mitten', 240, 286.5)],
    ), // 5 Pinecone Basket
    Level(
      outer: '#B9D4EC',
      inner: '#41658E',
      dividers: [r(42, 156, 276, 5, 2.5, '#345377'), r(42, 242, 276, 5, 2.5, '#345377')],
      slots: [Slot('snowglobe', 76.7, 114.5), Slot('bell', 128.3, 117), Slot('snowglobe', 180, 114.5), Slot('bell', 231.7, 117), Slot('snowglobe', 283.3, 114.5), Slot('ornament-sky', 87, 202.2), Slot('ornament-rose', 149, 202.2), Slot('ornament-sun', 211, 202.2), Slot('ornament-sky', 273, 202.2), Slot('candycane', 90, 284.5), Slot('gift-rose', 180, 289.5), Slot('candycane', 246, 284.5)],
    ), // 6 Snow Globe Shelf
  ];
}

/// Winter box [i] (clamped to 0..[winterLevelCount]-1).
Level winterLevel(int i) {
  final k = i < 0 ? 0 : (i >= winterLevelCount ? winterLevelCount - 1 : i);
  return winterLevels[k];
}
