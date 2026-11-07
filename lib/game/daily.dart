// The daily box: one puzzle per calendar day, the same on web and Android.
// Ported from dailyLevel() / seeded() / POOL / DSTYLE of the shipped HTML game.

import 'art.dart';
import 'content.dart';

/// Item kinds a daily box can use (POOL in the HTML).
const List<String> dailyPool = <String>[
  'egg', 'jar-paprika', 'jar-herb', 'jar-turmeric', 'can-mint', 'can-rose', 'milk', 'juice', 'shampoo', 'pencil-sun', 'pencil-mint', 'pencil-rose', 'toothbrush', 'tube-red', 'tube-blue', 'tube-yellow', 'battery', 'sock-rose', 'sock-mint', 'sock-lav', 'lip-red', 'lip-coral', 'earring', 'ring-rose', 'ring-mint', 'block-sun', 'block-mint', 'block-rose', 'cup', 'towel-rose', 'towel-sun', 'bathbomb', 'sd-red', 'sd-blue', 'bottle-kid', 'scarf', 'eraser', 'note-sky', 'note-sun', 'ball',
];

/// Box colours for daily boxes: outer, inner, divider (DSTYLE in the HTML).
const List<List<String>> dailyStyles = <List<String>>[
  ['#7FB89A', '#4E8A6C', '#427A5E'],
  ['#7D9BCE', '#4C6CA3', '#3F5D90'],
  ['#B98A5E', '#80583A', '#6C4A30'],
  ['#8A78AE', '#56467A', '#463966'],
  ['#5E9C97', '#346E6B', '#2A5A57'],
  ['#6D80A3', '#3E4F6E', '#2F3D57'],
  ['#E07A4F', '#3F3A47', '#2F2B36'],
  ['#E5BE4E', '#4A2F4F', '#3A2440'],
  ['#F2B48C', '#9C5A3C', '#7E4730'],
];

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Local date as "YYYY-MM-DD" (the fields of [d] are used as they are, so pass
/// a local DateTime such as DateTime.now()).
String dayString(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';
}

const int _mask32 = 0xFFFFFFFF;
const int _two32 = 4294967296;

/// Math.imul on unsigned 32-bit values (both arguments and the result are in
/// 0 .. 2^32-1). Uses 16-bit halves so that every intermediate value stays
/// below 2^53 and the result is identical on the Dart VM and on the web.
int _imul(int a, int b) {
  final x = a & _mask32;
  final y = b & _mask32;
  final ah = x ~/ 65536;
  final al = x % 65536;
  final bh = y ~/ 65536;
  final bl = y % 65536;
  final mid = (ah * bl + al * bh) % 65536;
  return (al * bl + mid * 65536) % _two32;
}

/// seeded() of the HTML: a small 32-bit hash that returns a function giving
/// numbers in [0, 1). All state is kept as unsigned 32-bit integers.
double Function() seeded(String str) {
  var h = (1779033703 ^ str.length) & _mask32;
  for (var i = 0; i < str.length; i++) {
    h = _imul((h ^ str.codeUnitAt(i)) & _mask32, 3432918353);
    // h = h << 13 | h >>> 19  (rotate left by 13)
    h = ((h * 8192) % _two32) + (h ~/ 524288);
  }
  return () {
    h = _imul((h ^ (h ~/ 65536)) & _mask32, 2246822507);
    h = _imul((h ^ (h ~/ 8192)) & _mask32, 3266489909);
    h = (h ^ (h ~/ 65536)) & _mask32;
    return h / _two32;
  };
}

/// Same algorithm and seed ("tidynook:" + day) as dailyLevel() in the HTML, so a
/// given date gives the same puzzle on web and Android. [day] is "YYYY-MM-DD".
Level dailyLevel(String day) {
  final r = seeded('tidynook:$day');
  final pool = List<String>.of(dailyPool);
  for (var i = pool.length - 1; i > 0; i--) {
    final j = (r() * (i + 1)).floor();
    final t = pool[i];
    pool[i] = pool[j];
    pool[j] = t;
  }
  final picked = pool.sublist(0, 4);
  final counts = r() < 0.5 ? <int>[3, 3, 2, 2] : <int>[4, 2, 2, 2];
  final seq = <String>[];
  for (var n = 0; n < picked.length; n++) {
    for (var c = 0; c < counts[n]; c++) {
      seq.add(picked[n]);
    }
  }
  final style = dailyStyles[(r() * dailyStyles.length).floor()];
  final theme = (r() * 5).floor();
  final slots = <Slot>[];
  for (var n = 0; n < seq.length; n++) {
    slots.add(Slot(seq[n], 42 + 27.6 + 55.2 * (n % 5), n < 5 ? 140.0 : 268.0));
  }
  return Level(
    outer: style[0],
    inner: style[1],
    theme: theme,
    dividers: <Prim>[Prim.rect(42, 201, 276, 6, 3, style[2])],
    slots: slots,
  );
}
