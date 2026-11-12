// Levels, rooms, furniture, pets and the SVG builders for the board, the lid and
// the house. Ported from the shipped HTML game (web-preview/index.html):
// LEVELS, ROOMS, LROOM, DECOR, VAR, PETS, BUSH, MILES, renderHouse(), drawLid(),
// renderStyles() / zoomPreviews() and the box drawing in setup().
//
// Colour strings passed in (matColor, stitchColor, houseLine) may be "#RRGGBB"
// or "rgba(r,g,b,a)". rgba() colours are converted to hex + opacity attributes.

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'art.dart';

export 'bonus.dart'
    show
        bonusLevel,
        bonusUnlockLevels,
        bonusStyleEvery,
        bonusPool,
        bonusIsMystery,
        bonusKindCount,
        bonusItemCount,
        kindsLookAlike;

/// One slot in a box: which kind of item belongs at (x, y) in board space.
class Slot {
  final String kind;
  final double x;
  final double y;
  const Slot(this.kind, this.x, this.y);
}

/// One level (a box): frame colour, inside colour, divider shapes, slots and
/// (for daily boxes) the theme index 0..4.
class Level {
  final String outer;
  final String inner;
  final List<Prim> dividers;
  final List<Slot> slots;
  final int theme;

  /// Mystery box: the slots show only neutral grey silhouettes
  /// (ghostSvg(kind, mystery: true)), so the player matches by shape.
  final bool mystery;
  Level({
    required this.outer,
    required this.inner,
    this.dividers = const <Prim>[],
    required this.slots,
    this.theme = 0,
    this.mystery = false,
  });
}

/// A room of the house (position in house space plus wall and floor colours).
class Room {
  final double x;
  final double y;
  final String wall;
  final String floor;
  const Room(this.x, this.y, this.wall, this.floor);
}

/// Daily boxes needed for pets 0..4: cat, fishbowl, flower garden, bunny and
/// songbird.
const List<int> milestones = [3, 7, 14, 21, 30];

/// The puppy: not earned from daily boxes, it comes with the Supporter Pack
/// (houseSvg(puppy: true)).
const int supporterPet = 5;

/// Number of pets (milestone pets plus the puppy); petPreviewSvg takes 0..5.
const int petCount = 6;

/// Furniture styles: 0 and 1 are free, 2 is earned (bonus boxes, surprise box)
/// or bought (Supporter Pack).
const int styleCount = 3;

/// LROOM: room index for each level.
const List<int> levelRoom = [
  0, 1, 2, 0, 1, 2, 0, 0, 1, 2, 3, 3, 4, 5, 4, 5, 4, 5, //
  6, 6, 6, 7, 7, 7, 8, 8, 8, 9, 9, 9,
];

/// The ten rooms: 0..5 as ROOMS in the HTML (1.1: lighter, warm floors so the
/// room label pill and the furniture stand out; Butter & Sage identity), 6 Attic Studio and 7 Reading Nook
/// on the attic floor, 8 Patio and 9 Garden in the garden strip (open air:
/// [Room.wall] is the sky there and [Room.floor] the ground).
const List<Room> rooms = <Room>[
  Room(30, 100, '#F6E3C6', '#D6A77C'),
  Room(180, 100, '#D6E4F0', '#CFA27C'),
  Room(30, 260, '#F3D6DE', '#DDA98E'),
  Room(180, 260, '#CFE8E3', '#86BCA2'),
  Room(30, -60, '#FFF0C9', '#D69C78'),
  Room(180, -60, '#E6DDF3', '#C4ACCB'),
  Room(30, -220, '#FFF6E5', '#DE9F84'),
  Room(180, -220, '#E4F0E7', '#D2A682'),
  Room(30, 436, '#DCEEEA', '#D9A48A'),
  Room(180, 436, '#E2F1EC', '#8DBE9C'),
];

/// Rooms of the attic floor and of the garden strip.
const List<int> atticRooms = <int>[6, 7];
const List<int> gardenRooms = <int>[8, 9];

/// Indexes of the levels that belong to [room].
List<int> levelsOfRoom(int room) {
  return <int>[
    for (var i = 0; i < levelRoom.length; i++)
      if (levelRoom[i] == room) i
  ];
}

/// The 30 levels: 0..17 as LEVELS in the HTML, 18..29 added in 1.1.
final List<Level> levels = _buildLevels();

List<Level> _buildLevels() {
  final r = Prim.rect;
  final c = Prim.circle;
  return <Level>[
    Level(
      outer: '#7FB89A',
      inner: '#4E8A6C',
      dividers: [c(110, 150, 31, '#427A5E'), c(180, 150, 31, '#427A5E'), c(250, 150, 31, '#427A5E'), c(110, 250, 31, '#427A5E'), c(180, 250, 31, '#427A5E'), c(250, 250, 31, '#427A5E')],
      slots: [Slot('egg', 110, 150), Slot('egg', 180, 150), Slot('egg', 250, 150), Slot('egg', 110, 250), Slot('egg', 180, 250), Slot('egg', 250, 250)],
    ), // 0
    Level(
      outer: '#7D9BCE',
      inner: '#4C6CA3',
      dividers: [r(42, 92, 276, 4, 2, '#3F5D90')],
      slots: [Slot('pencil-sun', 95, 205), Slot('pencil-mint', 135, 205), Slot('pencil-rose', 175, 205), Slot('pencil-peach', 215, 205), Slot('eraser', 272, 205)],
    ), // 1
    Level(
      outer: '#B98A5E',
      inner: '#80583A',
      dividers: [r(133, 84, 4, 232, 2, '#6C4A30'), r(223, 84, 4, 232, 2, '#6C4A30')],
      slots: [Slot('sock-rose', 70, 200), Slot('sock-rose', 110, 200), Slot('sock-mint', 160, 200), Slot('sock-mint', 200, 200), Slot('sock-lav', 250, 200), Slot('sock-lav', 290, 200)],
    ), // 2
    Level(
      outer: '#8A78AE',
      inner: '#56467A',
      dividers: [r(133, 80, 5, 240, 2, '#463966'), r(225, 80, 5, 240, 2, '#463966')],
      slots: [Slot('spoon', 70, 205), Slot('spoon', 104, 205), Slot('fork', 163, 205), Slot('fork', 197, 205), Slot('knife', 256, 205), Slot('knife', 290, 205)],
    ), // 3
    Level(
      outer: '#9C6E48',
      inner: '#5A4234',
      dividers: [r(42, 300, 276, 14, 3, '#45322A')],
      slots: [Slot('book0', 80, 252), Slot('book1', 112, 258), Slot('book2', 146, 248), Slot('book3', 181, 261), Slot('book4', 215, 254), Slot('book5', 247, 256), Slot('book6', 281, 250)],
    ), // 4
    Level(
      outer: '#5E9C97',
      inner: '#346E6B',
      dividers: [],
      slots: [Slot('palette', 120, 140), Slot('compact', 250, 140), Slot('lip-red', 92, 256), Slot('lip-berry', 132, 256), Slot('lip-coral', 172, 256), Slot('brush', 262, 245)],
    ), // 5
    Level(
      outer: '#6D80A3',
      inner: '#3E4F6E',
      dividers: [r(42, 192, 276, 10, 3, '#2F3D57'), r(42, 312, 276, 10, 3, '#2F3D57')],
      slots: [Slot('jar-paprika', 78, 162), Slot('jar-turmeric', 146, 162), Slot('jar-herb', 214, 162), Slot('jar-cinnamon', 282, 162), Slot('jar-herb', 78, 282), Slot('jar-cinnamon', 146, 282), Slot('jar-paprika', 214, 282), Slot('jar-turmeric', 282, 282)],
    ), // 6
    Level(
      outer: '#B9C7D4',
      inner: '#5A7894',
      dividers: [r(42, 190, 276, 8, 3, '#47627C'), r(42, 316, 276, 8, 3, '#47627C')],
      slots: [Slot('milk', 78, 142), Slot('juice', 120, 142), Slot('can-mint', 176, 165), Slot('can-rose', 220, 165), Slot('can-mint', 264, 165), Slot('jar-jam', 82, 284), Slot('jar-pickle', 140, 284), Slot('egg', 205, 290), Slot('egg', 250, 290), Slot('egg', 295, 290)],
    ), // 7
    Level(
      outer: '#E07A4F',
      inner: '#3F3A47',
      dividers: [r(42, 214, 276, 6, 3, '#2F2B36')],
      slots: [Slot('hammer', 90, 150), Slot('sd-red', 160, 155), Slot('sd-blue', 200, 155), Slot('wrench', 262, 158), Slot('tape', 96, 272), Slot('battery', 180, 272), Slot('battery', 214, 272), Slot('battery', 248, 272), Slot('battery', 282, 272)],
    ), // 8
    Level(
      outer: '#6F8FC4',
      inner: '#2F4A78',
      dividers: [r(178, 76, 4, 248, 2, '#405E92')],
      slots: [Slot('shirt-rose', 108, 128), Slot('shirt-sun', 108, 196), Slot('bookflat', 108, 272), Slot('toiletry', 250, 128), Slot('glasses', 250, 194), Slot('sock-mint', 228, 268), Slot('sock-mint', 272, 268)],
    ), // 9
    Level(
      outer: '#7FB8B0',
      inner: '#3F7A74',
      dividers: [r(42, 200, 276, 8, 3, '#33655F')],
      slots: [Slot('toothbrush', 72, 140), Slot('toothbrush', 106, 140), Slot('toothpaste', 152, 142), Slot('shampoo', 214, 142), Slot('shampoo', 264, 142), Slot('soap', 96, 268), Slot('soap', 164, 268), Slot('cotton', 252, 262)],
    ), // 10
    Level(
      outer: '#9784B0',
      inner: '#5B4A78',
      dividers: [r(42, 196, 276, 8, 3, '#4A3C64')],
      slots: [Slot('towel-rose', 82, 160), Slot('towel-rose', 136, 160), Slot('towel-sun', 190, 160), Slot('towel-sun', 244, 160), Slot('duck', 288, 262), Slot('towel-mint', 82, 268), Slot('towel-mint', 136, 268), Slot('bathbomb', 190, 270), Slot('bathbomb', 232, 270)],
    ), // 11
    Level(
      outer: '#F2B48C',
      inner: '#9C5A3C',
      dividers: [r(42, 200, 276, 8, 3, '#7E4730')],
      slots: [Slot('ball', 90, 140), Slot('ball', 160, 140), Slot('car', 254, 146), Slot('block-sun', 76, 262), Slot('block-mint', 132, 262), Slot('block-rose', 188, 262), Slot('rocket', 264, 250)],
    ), // 12
    Level(
      outer: '#C9A07A',
      inner: '#6E4E36',
      dividers: [r(42, 196, 276, 8, 3, '#5A3F2B'), r(42, 316, 276, 8, 3, '#5A3F2B')],
      slots: [Slot('sneaker', 80, 154), Slot('sneaker', 150, 154), Slot('boot', 208, 150), Slot('boot', 256, 150), Slot('heel', 82, 284), Slot('heel', 150, 284), Slot('slipper', 218, 286), Slot('slipper', 282, 286)],
    ), // 13
    Level(
      outer: '#5C7FC0',
      inner: '#33507F',
      dividers: [r(42, 206, 276, 8, 3, '#283F66')],
      slots: [Slot('note-sky', 84, 150), Slot('note-sun', 146, 150), Slot('ruler', 194, 150), Slot('pencil-sun', 228, 150), Slot('bottle-kid', 280, 150), Slot('lunchbox', 104, 272), Slot('eraser', 186, 272), Slot('pencil-mint', 258, 270)],
    ), // 14
    Level(
      outer: '#E5BE4E',
      inner: '#4A2F4F',
      dividers: [r(42, 198, 276, 6, 3, '#3A2440')],
      slots: [Slot('ring-rose', 76, 140), Slot('ring-mint', 124, 140), Slot('ring-sky', 172, 140), Slot('earring', 230, 140), Slot('earring', 274, 140), Slot('necklace', 104, 268), Slot('bracelet', 196, 268), Slot('watch', 272, 266)],
    ), // 15
    Level(
      outer: '#7FC4AA',
      inner: '#2F5E57',
      dividers: [r(42, 206, 276, 6, 3, '#244A44')],
      slots: [Slot('tube-red', 74, 150), Slot('tube-blue', 112, 150), Slot('tube-yellow', 150, 150), Slot('paintbrush', 196, 150), Slot('paintbrush', 226, 150), Slot('cup', 280, 154), Slot('palette', 116, 270), Slot('sponge', 232, 270)],
    ), // 16
    Level(
      outer: '#D9B48F',
      inner: '#5E4636',
      dividers: [r(42, 148, 276, 6, 3, '#4A372A'), r(42, 244, 276, 6, 3, '#4A372A')],
      slots: [Slot('sweater-rose', 86, 118), Slot('sweater-sky', 166, 118), Slot('sweater-sun', 246, 118), Slot('hat', 92, 206), Slot('hat', 176, 206), Slot('handbag', 262, 210), Slot('sweater-rose', 92, 290), Slot('sweater-sky', 176, 290), Slot('scarf', 264, 284)],
    ), // 17
    // --- 1.1: attic floor (rooms 6, 7) and garden strip (rooms 8, 9) ---
    Level(
      outer: '#E8A0B4',
      inner: '#8E4A62',
      dividers: [r(42, 200, 276, 6, 3, '#743A50')],
      slots: [Slot('spool-rose', 70, 136), Slot('spool-sky', 114, 136), Slot('spool-sun', 158, 136), Slot('spool-rose', 202, 136), Slot('spool-sky', 246, 136), Slot('thimble', 294, 140), Slot('scissors', 84, 264), Slot('pincushion', 164, 268), Slot('measure', 248, 268)],
    ), // 18
    Level(
      outer: '#C98F6B',
      inner: '#7A4E3A',
      dividers: [r(42, 200, 276, 6, 3, '#633E2E')],
      slots: [Slot('yarn-rose', 74, 136), Slot('yarn-sky', 136, 136), Slot('yarn-sun', 198, 136), Slot('mitten', 274, 136), Slot('yarn-rose', 70, 266), Slot('yarn-sky', 126, 266), Slot('yarn-sun', 182, 266), Slot('mitten', 240, 266), Slot('needles', 294, 264)],
    ), // 19
    Level(
      outer: '#9FB4C8',
      inner: '#4E6478',
      dividers: [r(42, 156, 276, 5, 2.5, '#3E5062'), r(42, 242, 276, 5, 2.5, '#3E5062')],
      slots: [Slot('btn-round', 76.5, 114), Slot('btn-round', 145.5, 114), Slot('btn-round', 214.5, 114), Slot('btn-square', 283.5, 114), Slot('btn-flower', 76.5, 200), Slot('btn-flower', 145.5, 200), Slot('btn-heart', 214.5, 198), Slot('btn-heart', 283.5, 198), Slot('btn-square', 111, 286), Slot('safety-pin', 249, 284)],
    ), // 20
    Level(
      outer: '#A88A6A',
      inner: '#5A4636',
      dividers: [r(42, 200, 276, 6, 3, '#46362A')],
      slots: [Slot('sleeve', 74, 136), Slot('sleeve', 134, 136), Slot('record', 192, 136), Slot('record', 248, 136), Slot('mic', 298, 134), Slot('record', 74, 266), Slot('cassette', 136, 266), Slot('cassette', 196, 266), Slot('headphones', 254, 264), Slot('mic', 302, 262)],
      mystery: true,
    ), // 21
    Level(
      outer: '#9FC9B0',
      inner: '#3E6E58',
      dividers: [r(42, 200, 276, 6, 3, '#305846')],
      slots: [Slot('tea-mint', 65, 148), Slot('tea-rose', 111, 148), Slot('tea-sun', 157, 148), Slot('tea-mint', 203, 148), Slot('tea-rose', 249, 148), Slot('tea-sun', 295, 148), Slot('teacup', 84, 264), Slot('teacup', 164, 264), Slot('sugar', 236, 266), Slot('sugar', 284, 266)],
    ), // 22
    Level(
      outer: '#8E9CC2',
      inner: '#3E4A72',
      dividers: [r(42, 200, 276, 6, 3, '#303A5C')],
      slots: [Slot('hl-sun', 64, 142), Slot('hl-mint', 96, 142), Slot('hl-rose', 128, 142), Slot('glue', 166, 142), Slot('glue', 202, 142), Slot('stapler', 270, 140), Slot('paperclip', 78, 272), Slot('paperclip', 116, 272), Slot('binder', 190, 270), Slot('binder', 254, 270)],
    ), // 23
    Level(
      outer: '#E5B76E',
      inner: '#8A5A2E',
      dividers: [r(42, 200, 276, 6, 3, '#704822')],
      slots: [Slot('sandwich', 74, 138), Slot('sandwich', 134, 138), Slot('juicebox', 186, 140), Slot('juicebox', 226, 140), Slot('banana', 282, 140), Slot('sandwich', 74, 268), Slot('apple', 126, 266), Slot('apple', 170, 266), Slot('apple', 214, 266), Slot('cupcake', 258, 266), Slot('cupcake', 298, 266)],
      mystery: true,
    ), // 24
    Level(
      outer: '#8E8798',
      inner: '#3A3442',
      dividers: [r(42, 196, 276, 6, 3, '#2C2734')],
      slots: [Slot('skewer', 62, 136), Slot('skewer', 92, 136), Slot('skewer', 122, 136), Slot('corn', 162, 136), Slot('corn', 200, 136), Slot('tongs', 244, 136), Slot('pepper', 292, 136), Slot('sausage', 96, 236), Slot('sausage', 96, 290), Slot('burger', 190, 264), Slot('burger', 262, 264)],
    ), // 25
    Level(
      outer: '#7FC4D8',
      inner: '#2F6E82',
      dividers: [r(42, 202, 276, 6, 3, '#245868')],
      slots: [Slot('flipflop', 64, 138), Slot('flipflop', 100, 138), Slot('sunscreen', 138, 138), Slot('spade', 176, 136), Slot('bucket', 226, 140), Slot('starfish', 286, 138), Slot('shell', 70, 266), Slot('shell', 120, 266), Slot('shell', 170, 266), Slot('starfish', 224, 268), Slot('shades', 284, 268)],
    ), // 26
    Level(
      outer: '#B7C98A',
      inner: '#5A6E3A',
      dividers: [r(42, 200, 276, 6, 3, '#48582E')],
      slots: [Slot('packet', 64, 136), Slot('packet', 104, 136), Slot('packet', 144, 136), Slot('packet', 184, 136), Slot('label', 226, 136), Slot('label', 262, 136), Slot('trowel', 298, 136), Slot('pot', 78, 266), Slot('pot', 136, 266), Slot('glove', 204, 264), Slot('bulb', 274, 264)],
      mystery: true,
    ), // 27
    Level(
      outer: '#C9A27E',
      inner: '#6A4A34',
      dividers: [r(42, 156, 276, 5, 2.5, '#553A28'), r(42, 242, 276, 5, 2.5, '#553A28')],
      slots: [Slot('cactus', 68, 114), Slot('cactus', 112, 114), Slot('succulent', 162, 112), Slot('succulent', 214, 112), Slot('wcan', 272, 116), Slot('pot', 82, 200), Slot('pot', 140, 200), Slot('glove', 206, 198), Slot('glove', 266, 198), Slot('twine', 88, 286), Slot('twine', 156, 286), Slot('handfork', 240, 284)],
    ), // 28
    Level(
      outer: '#E0C08A',
      inner: '#80603A',
      dividers: [r(42, 156, 276, 5, 2.5, '#684C2E'), r(42, 242, 276, 5, 2.5, '#684C2E')],
      slots: [Slot('apple', 72, 114), Slot('apple', 124, 114), Slot('apple', 176, 114), Slot('pear', 230, 114), Slot('pear', 282, 114), Slot('lemon', 84, 200), Slot('lemon', 152, 200), Slot('cherries', 218, 199), Slot('cherries', 278, 199), Slot('strawberry', 96, 286), Slot('strawberry', 180, 286), Slot('strawberry', 264, 286)],
      mystery: true,
    ), // 29
  ];
}

// ---------------------------------------------------------------------------
// furniture (DECOR) and its second style (VAR)
// ---------------------------------------------------------------------------

/// Number of furniture pieces (one per level).
const int decorCount = 30;

/// Floor-x centre of the moving box drawn while a level is not done (DECOR[i].b).
const List<int> _decorBase = <int>[
  22, 124, 60, 128, 76, 104, 52, 96, 44, 26, 102, 36, 100, 34, 42, 120, 130, 80, //
  36, 122, 80, 126, 82, 30, 132, 108, 84, 30, 62, 136,
];

const List<String> _decorSvgs = <String>[
  '<rect x="12" y="116" width="22" height="22" rx="3" fill="#D9825B"/><rect x="10" y="112" width="26" height="7" rx="2" fill="#C46F49"/><ellipse cx="16" cy="98" rx="6" ry="14" fill="#6FAE7E" transform="rotate(-25 16 98)"/><ellipse cx="30" cy="98" rx="6" ry="14" fill="#5E9C6E" transform="rotate(25 30 98)"/><ellipse cx="23" cy="92" rx="6" ry="16" fill="#7FC48E"/>',
  '<rect x="124" y="58" width="3" height="78" fill="#3A3046"/><ellipse cx="125.5" cy="137" rx="12" ry="3" fill="#3A3046"/><ellipse cx="125" cy="70" rx="22" ry="8" fill="#F6D26B" opacity=".35"/><path d="M112 60 L139 60 L133 40 L118 40Z" fill="#F2B48C"/>',
  '<ellipse cx="56" cy="136" rx="36" ry="5" fill="#F2B48C"/><ellipse cx="56" cy="136" rx="25" ry="3" fill="#F6D26B"/>',
  '<circle cx="118" cy="44" r="15" fill="#FFFFFF" stroke="#3A3046" stroke-width="3"/><path d="M118 44V34M118 44l7 4" stroke="#3A3046" stroke-width="2.5" stroke-linecap="round"/>',
  '<rect x="48" y="26" width="56" height="40" rx="3" fill="#FFFFFF" stroke="#B07D52" stroke-width="4"/><path d="M52 62 L68 44 L80 56 L88 48 L100 62Z" fill="#7FC4AA"/><circle cx="90" cy="38" r="5" fill="#F6D26B"/>',
  '<rect x="64" y="86" width="10" height="52" rx="3" fill="#8C6240"/><rect x="64" y="110" width="80" height="22" rx="5" fill="#FFFFFF"/><rect x="88" y="104" width="56" height="28" rx="6" fill="#CDBFE3"/><rect x="74" y="102" width="20" height="10" rx="5" fill="#F4F1EA"/><rect x="66" y="132" width="5" height="6" fill="#8C6240"/><rect x="136" y="132" width="5" height="6" fill="#8C6240"/>',
  '<rect x="73" y="0" width="2" height="28" fill="#3A3046"/><ellipse cx="74" cy="52" rx="24" ry="7" fill="#F6D26B" opacity=".35"/><path d="M60 42 L88 42 L80 26 L68 26Z" fill="#F6D26B"/>',
  '<rect x="72" y="100" width="58" height="7" rx="3" fill="#B07D52"/><rect x="77" y="107" width="5" height="31" fill="#8C6240"/><rect x="120" y="107" width="5" height="31" fill="#8C6240"/><rect x="86" y="88" width="11" height="12" rx="2" fill="#F4F1EA"/><ellipse cx="112" cy="97" rx="9" ry="3" fill="#E57A5B"/>',
  '<rect x="14" y="92" width="62" height="40" rx="12" fill="#8FB8E8"/><rect x="22" y="106" width="46" height="18" rx="6" fill="#B7D0EF"/><rect x="10" y="104" width="14" height="28" rx="6" fill="#7AA6DA"/><rect x="66" y="104" width="14" height="28" rx="6" fill="#7AA6DA"/><rect x="18" y="132" width="5" height="6" fill="#3A3046"/><rect x="68" y="132" width="5" height="6" fill="#3A3046"/>',
  '<rect x="16" y="24" width="46" height="52" rx="3" fill="#BFE0F2" stroke="#FFFFFF" stroke-width="4"/><rect x="37" y="24" width="4" height="52" fill="#FFFFFF"/><path d="M10 18 H68" stroke="#3A3046" stroke-width="3" stroke-linecap="round"/><path d="M12 20 Q22 50 14 82 L24 82 Q30 50 24 20Z" fill="#E58FA6"/><path d="M66 20 Q56 50 64 82 L54 82 Q48 50 54 20Z" fill="#E58FA6"/>',
  '<path d="M134 104 V80 h-8" stroke="#A9AFBA" stroke-width="3" fill="none"/><rect x="62" y="106" width="80" height="28" rx="12" fill="#FFFFFF" stroke="#C9CDD6" stroke-width="2"/><rect x="58" y="103" width="88" height="7" rx="3.5" fill="#E5EEF0"/><circle cx="80" cy="101" r="6" fill="#FFFFFF"/><circle cx="92" cy="97" r="8" fill="#FFFFFF"/><circle cx="106" cy="100" r="6" fill="#FFFFFF"/><rect x="70" y="134" width="5" height="4" fill="#C9CDD6"/><rect x="128" y="134" width="5" height="4" fill="#C9CDD6"/>',
  '<ellipse cx="34" cy="54" rx="16" ry="22" fill="#D6ECF5" stroke="#E5BE4E" stroke-width="3"/><path d="M26 46 L36 38" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/><rect x="16" y="92" width="38" height="8" rx="3" fill="#FFFFFF"/><rect x="30" y="100" width="10" height="38" fill="#E5EEF0"/>',
  '<path d="M98 66 L94 74 M98 66 L102 74" stroke="#8C6240" stroke-width="2.5" stroke-linecap="round"/><polygon points="68,138 98,72 128,138" fill="#F6D26B"/><polygon points="83,138 98,72 92,138" fill="#FFFFFF" opacity=".35"/><polygon points="88,138 98,104 108,138" fill="#E57A5B"/>',
  '<rect x="12" y="112" width="44" height="22" rx="10" fill="#E58FA6"/><ellipse cx="34" cy="112" rx="22" ry="7" fill="#F4A7B9"/><rect x="14" y="134" width="40" height="4" rx="2" fill="#3A3046" opacity=".25"/>',
  '<rect x="8" y="94" width="9" height="44" rx="3" fill="#8FB8E8"/><rect x="66" y="108" width="7" height="30" rx="3" fill="#8FB8E8"/><rect x="10" y="112" width="62" height="20" rx="5" fill="#FFFFFF"/><rect x="28" y="106" width="44" height="26" rx="6" fill="#F4A7B9"/><rect x="17" y="103" width="18" height="10" rx="5" fill="#F4F1EA"/><polygon fill="#FFFFFF" points="50.0,113.0 51.3,116.2 54.8,116.5 52.1,118.7 52.9,122.0 50.0,120.3 47.1,122.0 47.9,118.7 45.2,116.5 48.7,116.2"/>',
  '<path d="M110 130 L104 138 M130 130 L136 138" stroke="#8C6240" stroke-width="3" stroke-linecap="round"/><ellipse cx="120" cy="82" rx="16" ry="46" fill="#D6ECF5" stroke="#E5BE4E" stroke-width="4"/><path d="M112 66 L124 52 M112 82 L126 66" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>',
  '<path d="M8 20 Q75 50 142 20" stroke="#3A3046" stroke-width="1.5" fill="none"/><polygon fill="#F6D26B" points="26.0,23.0 27.9,27.5 32.7,27.8 29.0,31.0 30.1,35.7 26.0,33.1 21.9,35.7 23.0,31.0 19.3,27.8 24.1,27.5"/><polygon fill="#8FB8E8" points="52.0,32.0 53.9,36.5 58.7,36.8 55.0,40.0 56.1,44.7 52.0,42.1 47.9,44.7 49.0,40.0 45.3,36.8 50.1,36.5"/><polygon fill="#F6D26B" points="75.0,34.0 77.1,39.1 82.6,39.5 78.4,43.1 79.7,48.5 75.0,45.6 70.3,48.5 71.6,43.1 67.4,39.5 72.9,39.1"/><polygon fill="#8FB8E8" points="98.0,32.0 99.9,36.5 104.7,36.8 101.0,40.0 102.1,44.7 98.0,42.1 93.9,44.7 95.0,40.0 91.3,36.8 96.1,36.5"/><polygon fill="#F6D26B" points="124.0,23.0 125.9,27.5 130.7,27.8 127.0,31.0 128.1,35.7 124.0,33.1 119.9,35.7 121.0,31.0 117.3,27.8 122.1,27.5"/>',
  '<path d="M60 136 V36 M100 136 V36 M56 36 H104" stroke="#3A3046" stroke-width="3" stroke-linecap="round"/><path d="M68 36 l-6 8 h12z M80 36 l-6 8 h12z M92 36 l-6 8 h12z" fill="none" stroke="#A9AFBA" stroke-width="1.5"/><rect x="62" y="44" width="12" height="40" rx="3" fill="#E58FA6"/><rect x="74" y="44" width="12" height="52" rx="3" fill="#8FB8E8"/><rect x="86" y="44" width="12" height="34" rx="3" fill="#F6D26B"/><rect x="54" y="134" width="52" height="4" rx="2" fill="#3A3046"/>',
  // 18 sewing table (Attic Studio)
  '<rect x="8" y="98" width="56" height="6" rx="2" fill="#B07D52"/><rect x="12" y="104" width="4" height="34" fill="#8C6240"/><rect x="56" y="104" width="4" height="34" fill="#8C6240"/><rect x="12" y="124" width="48" height="3" fill="#8C6240"/><rect x="16" y="92" width="40" height="6" rx="2" fill="#E58FA6"/><rect x="42" y="70" width="11" height="24" rx="3" fill="#E58FA6"/><rect x="20" y="68" width="33" height="10" rx="5" fill="#E58FA6"/><rect x="23" y="77" width="3" height="12" fill="#C9CDD6"/><circle cx="52" cy="76" r="5" fill="#F4F1EA"/><rect x="31" y="61" width="6" height="7" rx="1" fill="#8FB8E8"/>',
  // 19 rocking chair
  '<path d="M98 135 Q122 144 146 133" stroke="#8C6240" stroke-width="4" fill="none" stroke-linecap="round"/><rect x="104" y="112" width="4" height="24" fill="#8C6240"/><rect x="134" y="110" width="4" height="25" fill="#8C6240"/><rect x="130" y="62" width="9" height="52" rx="4" fill="#B07D52"/><rect x="100" y="106" width="42" height="8" rx="3" fill="#B07D52"/><rect x="106" y="94" width="3" height="13" fill="#8C6240"/><rect x="104" y="90" width="30" height="5" rx="2.5" fill="#B07D52"/><rect x="104" y="100" width="28" height="7" rx="3.5" fill="#9FD3C0"/><path d="M127 68 L138 68 L137 98 L124 94Z" fill="#F6D26B"/><rect x="125" y="80" width="12" height="3" fill="#FFFFFF" opacity=".6"/>',
  // 20 easel
  '<path d="M68 138 L81 56 L94 138 M81 60 L81 138" stroke="#8C6240" stroke-width="3" stroke-linecap="round" fill="none"/><rect x="66" y="60" width="30" height="28" rx="2" fill="#FFFFFF"/><polygon points="68,86 76,74 82,80 88,72 94,86" fill="#7FC4AA"/><circle cx="88" cy="67" r="3.5" fill="#F6D26B"/><rect x="64" y="88" width="34" height="4" rx="2" fill="#B07D52"/>',
  // 21 record player (Reading Nook)
  '<rect x="108" y="108" width="38" height="30" rx="3" fill="#B07D52"/><rect x="112" y="113" width="30" height="9" rx="2" fill="#8C6240"/><rect x="112" y="125" width="30" height="9" rx="2" fill="#8C6240"/><circle cx="127" cy="117.5" r="1.6" fill="#F6D26B"/><circle cx="127" cy="129.5" r="1.6" fill="#F6D26B"/><rect x="112" y="96" width="24" height="12" rx="2" fill="#E57A5B"/><ellipse cx="123" cy="96" rx="11" ry="2.5" fill="#3A3046"/><path d="M128 94 L132 88 L137 66 Q146 60 148 71 Q144 81 134 90Z" fill="#E5BE4E"/>',
  // 22 beanbag
  '<path d="M60 138 Q55 112 72 104 Q86 96 100 106 Q110 116 106 138Z" fill="#F4A7B9"/><path d="M66 124 Q80 116 96 122" stroke="#E58FA6" stroke-width="2.5" fill="none" stroke-linecap="round"/><ellipse cx="74" cy="112" rx="6" ry="4" fill="#FFFFFF" opacity=".35"/>',
  // 23 bookcase
  '<rect x="8" y="42" width="46" height="96" rx="3" fill="#B07D52"/><rect x="12" y="46" width="38" height="88" rx="2" fill="#8C6240"/><rect x="12" y="70" width="38" height="3" fill="#B07D52"/><rect x="12" y="96" width="38" height="3" fill="#B07D52"/><rect x="12" y="120" width="38" height="3" fill="#B07D52"/><rect x="14" y="54" width="6" height="16" fill="#E58FA6"/><rect x="21" y="56" width="5" height="14" fill="#8FB8E8"/><rect x="27" y="53" width="7" height="17" fill="#F6D26B"/><rect x="38" y="58" width="10" height="12" fill="#9FD3C0"/><rect x="14" y="80" width="5" height="16" fill="#CDBFE3"/><rect x="20" y="82" width="7" height="14" fill="#E57A5B"/><rect x="30" y="79" width="6" height="17" fill="#8FB8E8"/><rect x="37" y="81" width="5" height="15" fill="#F6D26B"/><rect x="16" y="104" width="7" height="16" fill="#9FD3C0"/><rect x="24" y="106" width="6" height="14" fill="#F4A7B9"/><circle cx="41" cy="114" r="5" fill="#7FB06A"/>',
  // 24 garden table (Patio)
  '<rect x="119" y="46" width="2" height="54" fill="#C9CDD6"/><polygon points="96,58 120,42 144,58" fill="#E58FA6"/><polygon points="114,58 120,42 126,58" fill="#FFFFFF" opacity=".45"/><rect x="117" y="104" width="6" height="30" fill="#C9CDD6"/><ellipse cx="120" cy="136" rx="13" ry="3" fill="#C9CDD6"/><ellipse cx="120" cy="101" rx="24" ry="5" fill="#F4F1EA"/><rect x="104" y="82" width="12" height="16" rx="4" fill="#F6D26B"/><rect x="102" y="80" width="16" height="4" rx="2" fill="#FFFFFF"/><rect x="127" y="88" width="7" height="10" rx="2" fill="#F6D26B"/>',
  // 25 string lights
  '<path d="M4 14 Q75 44 146 14" stroke="#3A3046" stroke-width="1.5" fill="none"/><circle cx="21.8" cy="27.6" r="8" fill="#F6D26B" opacity=".3"/><rect x="20.2" y="20.6" width="3" height="3" fill="#3A3046"/><ellipse cx="21.8" cy="27.6" rx="3.5" ry="4.5" fill="#F6D26B"/><circle cx="39.5" cy="32.2" r="8" fill="#F4A7B9" opacity=".3"/><rect x="38" y="25.2" width="3" height="3" fill="#3A3046"/><ellipse cx="39.5" cy="32.2" rx="3.5" ry="4.5" fill="#F4A7B9"/><circle cx="57.2" cy="35.1" r="8" fill="#9FD3C0" opacity=".3"/><rect x="55.8" y="28.1" width="3" height="3" fill="#3A3046"/><ellipse cx="57.2" cy="35.1" rx="3.5" ry="4.5" fill="#9FD3C0"/><circle cx="75" cy="36" r="8" fill="#F6D26B" opacity=".3"/><rect x="73.5" y="29" width="3" height="3" fill="#3A3046"/><ellipse cx="75" cy="36" rx="3.5" ry="4.5" fill="#F6D26B"/><circle cx="92.8" cy="35.1" r="8" fill="#F4A7B9" opacity=".3"/><rect x="91.2" y="28.1" width="3" height="3" fill="#3A3046"/><ellipse cx="92.8" cy="35.1" rx="3.5" ry="4.5" fill="#F4A7B9"/><circle cx="110.5" cy="32.2" r="8" fill="#9FD3C0" opacity=".3"/><rect x="109" y="25.2" width="3" height="3" fill="#3A3046"/><ellipse cx="110.5" cy="32.2" rx="3.5" ry="4.5" fill="#9FD3C0"/><circle cx="128.2" cy="27.6" r="8" fill="#F6D26B" opacity=".3"/><rect x="126.8" y="20.6" width="3" height="3" fill="#3A3046"/><ellipse cx="128.2" cy="27.6" rx="3.5" ry="4.5" fill="#F6D26B"/>',
  // 26 hammock
  '<rect x="8" y="62" width="5" height="76" rx="2" fill="#8C6240"/><rect x="76" y="62" width="5" height="76" rx="2" fill="#8C6240"/><path d="M12 70 Q44 116 78 70 L78 76 Q44 126 12 76Z" fill="#E57A5B"/><path d="M18 81 Q44 111 72 81" stroke="#FFFFFF" stroke-width="3" fill="none" opacity=".6"/><ellipse cx="21" cy="81" rx="7" ry="4" fill="#F4F1EA"/>',
  // 27 raised flower bed (Garden)
  '<path d="M18 112 V95 M30 112 V89 M42 112 V97 M54 112 V91 M64 112 V99" stroke="#5E9C4E" stroke-width="2"/><circle cx="18" cy="94" r="5" fill="#F4A7B9"/><circle cx="30" cy="88" r="5" fill="#F6D26B"/><circle cx="42" cy="96" r="5" fill="#E58FA6"/><circle cx="54" cy="90" r="5" fill="#CDBFE3"/><circle cx="64" cy="98" r="4" fill="#F6D26B"/><circle cx="18" cy="94" r="1.8" fill="#FFFFFF"/><circle cx="30" cy="88" r="1.8" fill="#FFFFFF"/><circle cx="42" cy="96" r="1.8" fill="#FFFFFF"/><circle cx="54" cy="90" r="1.8" fill="#FFFFFF"/><rect x="8" y="112" width="62" height="26" rx="3" fill="#B07D52"/><rect x="8" y="112" width="62" height="5" rx="2" fill="#8C6240"/><rect x="8" y="125" width="62" height="2" fill="#8C6240"/>',
  // 28 birdhouse
  '<rect x="82" y="72" width="4" height="66" fill="#8C6240"/><rect x="72" y="52" width="24" height="22" rx="2" fill="#8FB8E8"/><polygon points="68,55 84,38 100,55" fill="#E57A5B"/><circle cx="84" cy="62" r="4" fill="#3A3046"/><rect x="80" y="68" width="8" height="2" rx="1" fill="#8C6240"/>',
  // 29 apple tree
  '<rect x="120" y="80" width="10" height="58" rx="3" fill="#8C6240"/><path d="M125 98 L111 84" stroke="#8C6240" stroke-width="4" stroke-linecap="round"/><circle cx="108" cy="66" r="14" fill="#6FA05E"/><circle cx="140" cy="62" r="10" fill="#6FA05E"/><circle cx="125" cy="50" r="22" fill="#7FB06A"/><circle cx="114" cy="56" r="3.5" fill="#E57A5B"/><circle cx="132" cy="43" r="3.5" fill="#E57A5B"/><circle cx="135" cy="63" r="3.5" fill="#E57A5B"/><circle cx="104" cy="70" r="3.5" fill="#E57A5B"/><circle cx="141" cy="135" r="3" fill="#E57A5B"/>',
];

/// Item bounding boxes of the furniture in room-local coordinates: left, top,
/// right, bottom (what getBBox() returns in the browser).
const List<List<double>> _decorBox = <List<double>>[
  [4.645, 76, 41.355, 138], // 0
  [103, 40, 147, 140], // 1
  [20, 131, 92, 141], // 2
  [103, 29, 133, 59], // 3
  [48, 26, 104, 66], // 4
  [64, 86, 144, 138], // 5
  [50, 0, 98, 59], // 6
  [72, 88, 130, 138], // 7
  [10, 92, 80, 138], // 8
  [10, 18, 68, 82], // 9
  [58, 80, 146, 138], // 10
  [16, 32, 54, 138], // 11
  [68, 66, 128, 138], // 12
  [12, 105, 56, 138], // 13
  [8, 94, 73, 138], // 14
  [104, 36, 136, 138], // 15
  [8, 20, 142, 48.5], // 16
  [54, 36, 106, 138], // 17
  [8, 61, 64, 138], // 18
  [98, 62, 146, 139.05], // 19
  [64, 56, 98, 138], // 20
  [108, 63.882, 148, 138], // 21
  [58.864, 100.444, 107.143, 138], // 22
  [8, 42, 54, 138], // 23
  [96, 42, 144, 139], // 24
  [4, 14, 146, 44], // 25
  [8, 62, 81, 138], // 26
  [8, 83, 70, 138], // 27
  [68, 38, 100, 138], // 28
  [94, 28, 150, 138], // 29
];

/// Style B colour swaps for each piece of furniture.
const List<Map<String, String>> _variants = <Map<String, String>>[
  {'#D9825B': '#8FB8E8', '#C46F49': '#7AA6DA'},
  {'#F2B48C': '#9FD3C0'},
  {'#F2B48C': '#9FD3C0', '#F6D26B': '#CDBFE3'},
  {'#FFFFFF': '#F6D26B'},
  {'#B07D52': '#3A3046', '#7FC4AA': '#E58FA6'},
  {'#CDBFE3': '#9FD3C0', '#8C6240': '#D9B48F'},
  {'#F6D26B': '#E58FA6'},
  {'#B07D52': '#F4F1EA', '#8C6240': '#C9C3CF', '#F4F1EA': '#9FD3C0'},
  {'#8FB8E8': '#F2B48C', '#B7D0EF': '#F7CDAF', '#7AA6DA': '#E89C6E'},
  {'#E58FA6': '#7FC4AA'},
  {'#C9CDD6': '#E5BE4E', '#E5EEF0': '#F6D26B'},
  {'#E5BE4E': '#E58FA6', '#E5EEF0': '#CDBFE3'},
  {'#F6D26B': '#9FD3C0', '#E57A5B': '#8FB8E8'},
  {'#E58FA6': '#7FC4AA', '#F4A7B9': '#9FD3C0'},
  {'#8FB8E8': '#E5BE4E', '#F4A7B9': '#CDBFE3'},
  {'#E5BE4E': '#3A3046'},
  {'#F6D26B': '#F4A7B9', '#8FB8E8': '#9FD3C0'},
  {'#E58FA6': '#F6D26B', '#8FB8E8': '#E57A5B'},
  {'#E58FA6': '#7FC4AA', '#B07D52': '#F4F1EA', '#8C6240': '#C9C3CF'}, // 18
  {'#B07D52': '#F4F1EA', '#8C6240': '#C9C3CF', '#9FD3C0': '#F4A7B9'}, // 19
  {'#8C6240': '#C9C3CF', '#B07D52': '#E5BE4E', '#7FC4AA': '#E58FA6'}, // 20
  {'#B07D52': '#F4F1EA', '#8C6240': '#C9C3CF', '#E57A5B': '#8FB8E8'}, // 21
  {'#F4A7B9': '#8FB8E8', '#E58FA6': '#7AA6DA'}, // 22
  {'#B07D52': '#F4F1EA', '#8C6240': '#D6CFDD'}, // 23
  {'#E58FA6': '#8FB8E8', '#F4F1EA': '#E6C9A8', '#C9CDD6': '#B07D52'}, // 24
  {'#F4A7B9': '#F6D26B', '#9FD3C0': '#F6D26B'}, // 25
  {'#E57A5B': '#8FB8E8', '#8C6240': '#C9C3CF'}, // 26
  {'#B07D52': '#F4F1EA', '#8C6240': '#C9C3CF'}, // 27
  {'#8FB8E8': '#F6D26B', '#E57A5B': '#7FC4AA'}, // 28
  {'#7FB06A': '#F4A7B9', '#6FA05E': '#E58FA6', '#E57A5B': '#FFFFFF'}, // 29
];

/// Style C (index 2) colour swaps for each piece of furniture: a third palette,
/// different from styles A and B.
const List<Map<String, String>> _variants2 = <Map<String, String>>[
  {'#D9825B': '#F4F1EA', '#C46F49': '#C9C3CF'}, // 0 potted plant
  {'#F2B48C': '#CDBFE3'}, // 1
  {'#F2B48C': '#8FB8E8', '#F6D26B': '#F4F1EA'}, // 2
  {'#FFFFFF': '#9FD3C0'}, // 3
  {'#B07D52': '#E5BE4E', '#7FC4AA': '#8FB8E8'}, // 4
  {'#CDBFE3': '#F4A7B9', '#FFFFFF': '#F4F1EA', '#F4F1EA': '#F6D26B'}, // 5
  {'#F6D26B': '#9FD3C0'}, // 6
  {'#B07D52': '#9C6E48', '#8C6240': '#5A4234', '#E57A5B': '#F6D26B'}, // 7
  {'#8FB8E8': '#CDBFE3', '#B7D0EF': '#E6DDF3', '#7AA6DA': '#B3A3D0'}, // 8
  {'#E58FA6': '#F6D26B'}, // 9
  {'#C9CDD6': '#8FB8E8', '#E5EEF0': '#BFE0F2'}, // 10
  {'#E5BE4E': '#7FC4AA', '#E5EEF0': '#CFE8E3'}, // 11
  {'#F6D26B': '#CDBFE3', '#E57A5B': '#E58FA6'}, // 12
  {'#E58FA6': '#E5BE4E', '#F4A7B9': '#F6D26B'}, // 13
  {'#8FB8E8': '#7FC4AA', '#F4A7B9': '#F6D26B'}, // 14
  {'#E5BE4E': '#E58FA6'}, // 15
  {'#F6D26B': '#CDBFE3', '#8FB8E8': '#E57A5B'}, // 16
  {'#E58FA6': '#CDBFE3', '#8FB8E8': '#7FC4AA', '#F6D26B': '#F4A7B9'}, // 17
  {'#E58FA6': '#F6D26B', '#B07D52': '#5A4234', '#8C6240': '#3A3046', '#8FB8E8': '#E57A5B'}, // 18
  {'#B07D52': '#E58FA6', '#8C6240': '#C9587C', '#9FD3C0': '#F4F1EA', '#F6D26B': '#CDBFE3'}, // 19
  {'#8C6240': '#3A3046', '#B07D52': '#3A3046', '#7FC4AA': '#8FB8E8', '#F6D26B': '#E57A5B'}, // 20
  {'#B07D52': '#5A4234', '#8C6240': '#3A3046', '#E57A5B': '#7FC4AA', '#E5BE4E': '#C9CDD6'}, // 21
  {'#F4A7B9': '#F6D26B', '#E58FA6': '#E5BE4E'}, // 22
  {'#B07D52': '#7FC4AA', '#8C6240': '#4E8A6C'}, // 23
  {'#E58FA6': '#F6D26B', '#F4F1EA': '#3A3046', '#C9CDD6': '#4A4057'}, // 24
  {'#F6D26B': '#8FB8E8', '#F4A7B9': '#CDBFE3', '#9FD3C0': '#FFFFFF'}, // 25
  {'#E57A5B': '#9FD3C0', '#8C6240': '#5A4234', '#F4F1EA': '#F6D26B'}, // 26
  {'#B07D52': '#8FB8E8', '#8C6240': '#7AA6DA', '#F4A7B9': '#FFFFFF', '#E58FA6': '#F2B48C'}, // 27
  {'#8FB8E8': '#F4F1EA', '#E57A5B': '#3A3046', '#8C6240': '#C9C3CF'}, // 28
  {'#7FB06A': '#F2B48C', '#6FA05E': '#E8A86E', '#E57A5B': '#C9452E'}, // 29
];

final RegExp _hexColour = RegExp(r'#[0-9A-F]{6}');

/// SVG fragment (room-local coordinates, no svg wrapper) of furniture [i] in
/// style [v] (0 = style A, 1 = style B, 2 = style C). Other values draw style A.
String decorSvg(int i, int v) {
  final s = _decorSvgs[i];
  if (v != 1 && v != 2) {
    return s;
  }
  final map = v == 1 ? _variants[i] : _variants2[i];
  return s.replaceAllMapped(_hexColour, (Match m) => map[m[0]!] ?? m[0]!);
}

String _boxArt(int x) {
  return '<g transform="translate(${fmtNum(x - 11)} 116)">'
      '<rect width="22" height="22" rx="2" fill="#D9B48F" stroke="#A97E55" stroke-width="1.5"/>'
      '<rect x="9" width="4" height="22" fill="#F4E9D6" opacity=".85"/></g>';
}

// ---------------------------------------------------------------------------
// pets and the garden (rewards of the daily boxes)
// ---------------------------------------------------------------------------

class _Pet {
  final int room; // -1 = outside the rooms (garden by the house)
  final String svg; // all of it, in room (or house) coordinates
  final String one; // what the win card shows
  final List<double> box; // bounds of [one]: left, top, right, bottom
  const _Pet(this.room, this.svg, this.one, this.box);
}

const String _bunny = '<ellipse cx="106" cy="131" rx="11" ry="8" fill="#D8C7B5"/><circle cx="95" cy="129" r="3.5" fill="#FFFFFF"/><ellipse cx="111.5" cy="111" rx="2.6" ry="7.5" fill="#D8C7B5"/><ellipse cx="117" cy="111.5" rx="2.6" ry="7.5" fill="#D8C7B5"/><ellipse cx="111.5" cy="111.5" rx="1.2" ry="5" fill="#F4A7B9"/><ellipse cx="117" cy="112" rx="1.2" ry="5" fill="#F4A7B9"/><circle cx="114" cy="122" r="6.5" fill="#D8C7B5"/><ellipse cx="104" cy="134" rx="5" ry="2.5" fill="#F4ECE2"/><circle cx="116" cy="121" r="1.2" fill="#3A3046"/><circle cx="120" cy="123.5" r="1.1" fill="#E58FA6"/>';
const String _songbird = '<rect x="78.25" y="0" width="1.5" height="22" fill="#3A3046"/><path d="M66 60 V38 Q66 22 79 22 Q92 22 92 38 V60Z" fill="#FFF6E0" opacity=".7"/><rect x="68" y="54" width="22" height="1.6" fill="#B07D52"/><polygon points="71,47 65,44 66,51" fill="#7AA6DA"/><ellipse cx="77" cy="48" rx="7" ry="5.5" fill="#8FB8E8"/><ellipse cx="79" cy="51" rx="3.5" ry="2" fill="#F4F1EA"/><ellipse cx="75" cy="48" rx="4.5" ry="3" fill="#7AA6DA"/><circle cx="83" cy="43.5" r="4" fill="#8FB8E8"/><polygon points="86.5,42.5 90,44 86.5,45.5" fill="#F6B26B"/><circle cx="84" cy="42.5" r="1" fill="#3A3046"/><path d="M66 60 V38 Q66 22 79 22 Q92 22 92 38 V60 M72.5 60 V26.5 M79 60 V22 M85.5 60 V26.5" stroke="#E5BE4E" stroke-width="1.5" fill="none"/><rect x="63" y="58" width="32" height="5" rx="2" fill="#E5BE4E"/>';
const String _puppy = '<polygon points="31,128 22,121 24,131" fill="#E6C9A8"/><ellipse cx="44" cy="131" rx="14" ry="7" fill="#E6C9A8"/><ellipse cx="40" cy="128" rx="4.5" ry="3" fill="#B07D52"/><rect x="50" y="125" width="4" height="9" rx="2" fill="#E57A5B"/><circle cx="58" cy="124" r="7" fill="#E6C9A8"/><ellipse cx="63" cy="127" rx="4.5" ry="3" fill="#F4E6D2"/><circle cx="66.5" cy="126" r="1.6" fill="#3A3046"/><circle cx="59.5" cy="122" r="1.1" fill="#3A3046"/><ellipse cx="54" cy="123" rx="3" ry="6" fill="#B07D52"/><ellipse cx="47" cy="137" rx="5" ry="1.8" fill="#C9B28F"/>';

const List<_Pet> _pets = <_Pet>[
  _Pet(0, '<path d="M41 131 Q33 126 38 119" stroke="#F2B48C" stroke-width="4" fill="none" stroke-linecap="round"/><ellipse cx="54" cy="131" rx="13" ry="7" fill="#F2B48C"/><circle cx="66" cy="124" r="7" fill="#F2B48C"/><polygon points="60,120 62,112 66,118" fill="#F2B48C"/><polygon points="66,118 70,112 72,120" fill="#F2B48C"/><path d="M62.5 125q1.5 1.5 3 0M67 125q1.5 1.5 3 0" stroke="#3A3046" stroke-width="1.2" fill="none"/><path d="M47 129q3-2 6 0M52 133q3-2 6 0" stroke="#D9825B" stroke-width="2" fill="none"/>', '<path d="M41 131 Q33 126 38 119" stroke="#F2B48C" stroke-width="4" fill="none" stroke-linecap="round"/><ellipse cx="54" cy="131" rx="13" ry="7" fill="#F2B48C"/><circle cx="66" cy="124" r="7" fill="#F2B48C"/><polygon points="60,120 62,112 66,118" fill="#F2B48C"/><polygon points="66,118 70,112 72,120" fill="#F2B48C"/><path d="M62.5 125q1.5 1.5 3 0M67 125q1.5 1.5 3 0" stroke="#3A3046" stroke-width="1.2" fill="none"/><path d="M47 129q3-2 6 0M52 133q3-2 6 0" stroke="#D9825B" stroke-width="2" fill="none"/>', [36.077, 112, 73, 138]),
  _Pet(1, '<rect x="80" y="86" width="34" height="4" rx="2" fill="#8C6240"/><circle cx="97" cy="74" r="12" fill="#BFE0F2"/><rect x="86" y="62" width="22" height="3" rx="1.5" fill="#DDF0FA"/><ellipse cx="95" cy="77" rx="5" ry="3" fill="#F08A6C"/><polygon points="99,77 104,73 104,81" fill="#F08A6C"/><circle cx="103" cy="68" r="1.5" fill="#FFFFFF"/>', '<rect x="80" y="86" width="34" height="4" rx="2" fill="#8C6240"/><circle cx="97" cy="74" r="12" fill="#BFE0F2"/><rect x="86" y="62" width="22" height="3" rx="1.5" fill="#DDF0FA"/><ellipse cx="95" cy="77" rx="5" ry="3" fill="#F08A6C"/><polygon points="99,77 104,73 104,81" fill="#F08A6C"/><circle cx="103" cy="68" r="1.5" fill="#FFFFFF"/>', [80, 62, 114, 90]),
  _Pet(-1, '<ellipse cx="28" cy="414" rx="22" ry="13" fill="#7FC48E"/><ellipse cx="36" cy="410" rx="12" ry="9" fill="#6FAE7E"/><circle cx="18" cy="406" r="4" fill="#F4A7B9"/><circle cx="32" cy="402" r="4" fill="#F6D26B"/><circle cx="40" cy="412" r="3.5" fill="#E58FA6"/><circle cx="24" cy="415" r="3" fill="#FFFFFF"/><ellipse cx="332" cy="414" rx="22" ry="13" fill="#7FC48E"/><ellipse cx="340" cy="410" rx="12" ry="9" fill="#6FAE7E"/><circle cx="322" cy="406" r="4" fill="#F4A7B9"/><circle cx="336" cy="402" r="4" fill="#F6D26B"/><circle cx="344" cy="412" r="3.5" fill="#E58FA6"/><circle cx="328" cy="415" r="3" fill="#FFFFFF"/>', '<ellipse cx="28" cy="414" rx="22" ry="13" fill="#7FC48E"/><ellipse cx="36" cy="410" rx="12" ry="9" fill="#6FAE7E"/><circle cx="18" cy="406" r="4" fill="#F4A7B9"/><circle cx="32" cy="402" r="4" fill="#F6D26B"/><circle cx="40" cy="412" r="3.5" fill="#E58FA6"/><circle cx="24" cy="415" r="3" fill="#FFFFFF"/>', [6, 398, 50, 427]),
  _Pet(9, _bunny, _bunny, [91.5, 103.5, 121.1, 139]), // bunny (Garden)
  _Pet(7, _songbird, _songbird, [63, 0, 95, 63]), // songbird in its cage (Reading Nook)
  _Pet(8, _puppy, _puppy, [22, 117, 68.1, 138.8]), // puppy under the hammock (Patio)
];

// ---------------------------------------------------------------------------
// SVG builders
// ---------------------------------------------------------------------------

/// flutter_svg does not draw <text>, so the UI draws the texts itself.
/// Font size of the room labels ("<room name> \u00B7 n/m") in house space.
const double roomLabelFontSize = 12;

/// Centre of the lid's "tap to open" text in board space (HTML baseline 232, size 17).
const Offset lidTextCenter = Offset(180, 226);

/// Font size of the lid text in board space.
const double lidTextFontSize = 17;

/// Visual centre of the label of [room] in house space (HTML baseline is
/// room.y + 154 at font size 12). The UI draws "<room name> \u00B7 n/m" there.
Offset roomLabelCenter(int room) {
  final r = rooms[room];
  return Offset(r.x + 75, r.y + 149);
}

/// Full board background as an <svg> with viewBox "0 40 360 594": box shadow,
/// frame (outer), inside (inner), dividers, then the rug (mat) and its stitched
/// border. [matColor] and [stitchColor] come from the UI theme.
String boardSvg(Level level,
    {required String matColor, required String stitchColor}) {
  final b = StringBuffer()
    ..write('<rect x="30" y="66" width="300" height="280" rx="24" fill="rgba(20,12,30,.18)"/>')
    ..write('<rect x="30" y="60" width="300" height="280" rx="24" fill="${level.outer}"/>')
    ..write('<rect x="42" y="72" width="276" height="256" rx="16" fill="${level.inner}"/>')
    ..write(primsSvg(level.dividers))
    ..write('<rect x="14" y="364" width="332" height="262" rx="26" fill="$matColor"/>')
    ..write('<rect x="24" y="374" width="312" height="242" rx="18" fill="none" '
        'stroke="$stitchColor" stroke-width="2" stroke-dasharray="6 5"/>');
  return svgDocument('0 40 360 594', b.toString());
}

/// The closed lid as an <svg> with viewBox "0 40 360 594" (transparent outside
/// the box). [tapText] is kept for compatibility but ignored: flutter_svg does
/// not draw <text>, so the UI draws the text at [lidTextCenter] itself.
String lidSvg(Level level, {String? tapText}) {
  final b = StringBuffer()
    ..write('<rect x="30" y="60" width="300" height="280" rx="24" fill="${level.outer}"/>')
    ..write('<rect x="46" y="76" width="268" height="248" rx="16" fill="rgba(255,255,255,.18)"/>')
    ..write('<rect x="52" y="82" width="256" height="236" rx="13" fill="none" '
        'stroke="rgba(255,255,255,.35)" stroke-width="2" stroke-dasharray="7 6"/>')
    ..write('<rect x="140" y="170" width="80" height="22" rx="11" fill="#2E2638" opacity=".85"/>')
    ..write('<rect x="150" y="176" width="60" height="6" rx="3" fill="rgba(255,255,255,.35)"/>');
  return svgDocument('0 40 360 594', b.toString());
}

/// viewBox of the whole 1.1 house: the attic floor under the raised roof, the
/// three storeys of 1.0 and the garden strip in front (houseSvg(extended: true)).
const String houseViewBox = '10 -306 340 912';

/// Top-left corner and size of [houseViewBox] in house space.
const Offset houseOrigin = Offset(10, -306);
const Size houseSize = Size(340, 912);

/// viewBox of the 1.0 house (rooms 0..5 only): what houseSvg() draws by default,
/// so the 1.0 house screen keeps working until it switches to [houseViewBox].
const String houseViewBoxLegacy = '10 -146 340 574';
const Offset houseOriginLegacy = Offset(10, -146);
const Size houseSizeLegacy = Size(340, 574);

/// Number of rooms drawn by houseSvg(extended: false).
const int legacyRoomCount = 6;

/// Room-local backdrop drawn over the wall colour (attic slopes, sky, fence).
String _roomBackdrop(int ri) {
  switch (ri) {
    case 3: {
        final b = StringBuffer();
        for (var y = 20; y < 138; y += 20) {
          b.write('<rect x="0" y="$y" width="150" height="1.5" fill="rgba(255,255,255,.7)"/>');
        }
        return b.toString();
    }
    case 6:
      return '<polygon points="0,0 56,0 0,56" fill="#F3E3C6"/>'
          '<path d="M0 56 L56 0" stroke="#D9B98F" stroke-width="4"/>'
          '<circle cx="104" cy="30" r="12" fill="#DCEEF2" stroke="#D9B98F" stroke-width="3"/>'
          '<path d="M104 18V42M92 30H116" stroke="#D9B98F" stroke-width="2"/>';
    case 7:
      return '<polygon points="94,0 150,0 150,56" fill="#CFE3D5"/>'
          '<path d="M94 0 L150 56" stroke="#A3C6AE" stroke-width="4"/>';
    case 8: {
        final b = StringBuffer()
          ..write('<ellipse cx="44" cy="60" rx="15" ry="6" fill="#FFFFFF" opacity=".85"/>')
          ..write('<ellipse cx="54" cy="55" rx="10" ry="7" fill="#FFFFFF" opacity=".85"/>')
          ..write('<rect x="0" y="106" width="150" height="32" fill="#7DB592"/>');
        for (var x = 9; x < 150; x += 16) {
          b.write('<circle cx="$x" cy="107" r="9" fill="#7DB592"/>');
        }
        b.write('<circle cx="30" cy="114" r="1.8" fill="#F4A7B9"/>'
            '<circle cx="98" cy="112" r="1.8" fill="#FFFFFF"/>'
            '<circle cx="134" cy="118" r="1.8" fill="#F6D26B"/>');
        return b.toString();
    }
    case 9: {
        final b = StringBuffer()
          ..write('<circle cx="22" cy="24" r="10" fill="#FFE38A"/>')
          ..write('<ellipse cx="70" cy="22" rx="14" ry="6" fill="#FFFFFF" opacity=".85"/>')
          ..write('<ellipse cx="80" cy="18" rx="9" ry="6" fill="#FFFFFF" opacity=".85"/>')
          ..write('<rect x="0" y="110" width="150" height="3" fill="#E9E3EE"/>')
          ..write('<rect x="0" y="126" width="150" height="3" fill="#E9E3EE"/>');
        for (var x = 3; x < 142; x += 13) {
          b.write('<polygon points="$x,138 $x,101 ${x + 4},96 ${x + 8},101 ${x + 8},138" fill="#FBF8FC"/>');
        }
        return b.toString();
    }
    default:
      return '';
  }
}

/// Room-local details drawn over the floor colour (patio tiles, grass).
String _floorDetail(int ri) {
  switch (ri) {
    case 8: {
        final b = StringBuffer('<rect x="0" y="148" width="150" height="1.5" fill="rgba(255,255,255,.45)"/>');
        for (var x = 25; x < 150; x += 25) {
          b.write('<rect x="$x" y="138" width="1.5" height="22" fill="rgba(255,255,255,.45)"/>');
        }
        return b.toString();
    }
    case 9:
      return '<polygon points="10,146 13,140 16,146" fill="#6EA585"/>'
          '<polygon points="52,152 55,146 58,152" fill="#6EA585"/>'
          '<polygon points="96,145 99,139 102,145" fill="#6EA585"/>'
          '<polygon points="132,153 135,147 138,153" fill="#6EA585"/>';
    default:
      return '';
  }
}

/// The whole house as an <svg>, like renderHouse() in the HTML: rooms,
/// furniture for done levels in the chosen style, moving boxes for levels not
/// done, the room-complete check marks and the pets from daily milestones.
/// [houseLine] is the outline colour from the theme. [roomNames] are already
/// translated (index = room index); flutter_svg does not draw text, so the UI
/// draws the labels itself at [roomLabelCenter].
///
/// [extended] = false (the default) draws the 1.0 house with viewBox
/// [houseViewBoxLegacy] (rooms 0..5, pets 0..2), exactly as 1.0 did, so the
/// 1.0 house screen keeps working. [extended] = true draws the 1.1 house with
/// the attic floor and the garden strip, viewBox [houseViewBox].
/// [puppy] adds the Supporter Pack puppy (pet [supporterPet]) to the Patio.
String houseSvg({
  required Set<int> done,
  required Map<int, int> styles,
  required int dailyTotal,
  required List<String> roomNames,
  required String houseLine,
  bool puppy = false,
  bool extended = false,
}) {
  final hl = houseLine;
  final s = StringBuffer();
  if (extended) {
    s
      ..write('<rect x="22" y="-216" width="316" height="640" rx="6" fill="rgba(20,12,30,.12)"/>')
      ..write('<rect x="22" y="444" width="316" height="160" rx="6" fill="rgba(20,12,30,.12)"/>')
      ..write('<rect x="250" y="-284" width="24" height="50" fill="#B05070" stroke="$hl" stroke-width="3"/>')
      ..write('<polygon points="16,-216 180,-298 344,-216" fill="#C9587C" stroke="$hl" stroke-width="4" stroke-linejoin="round"/>')
      ..write('<circle cx="180" cy="-248" r="13" fill="#FBE3E8" stroke="$hl" stroke-width="3"/>')
      ..write('<rect x="14" y="417" width="332" height="15" rx="7" fill="#9CCB8A"/>');
  } else {
    s
      ..write('<rect x="22" y="-56" width="316" height="480" rx="6" fill="rgba(20,12,30,.12)"/>')
      ..write('<rect x="250" y="-124" width="24" height="50" fill="#B05070" stroke="$hl" stroke-width="3"/>')
      ..write('<polygon points="16,-56 180,-138 344,-56" fill="#C9587C" stroke="$hl" stroke-width="4" stroke-linejoin="round"/>')
      ..write('<circle cx="180" cy="-88" r="13" fill="#FBE3E8" stroke="$hl" stroke-width="3"/>');
  }
  final roomCount = extended ? rooms.length : legacyRoomCount;
  for (var ri = 0; ri < roomCount; ri++) {
    final room = rooms[ri];
    final lv = levelsOfRoom(ri);
    final n = lv.where((i) => done.contains(i)).length;
    final full = n == lv.length;
    s.write('<g transform="translate(${fmtNum(room.x)} ${fmtNum(room.y)})">'
        '<rect width="150" height="160" fill="${room.wall}"/>');
    s.write(_roomBackdrop(ri));
    if (full && !gardenRooms.contains(ri)) {
      s.write('<rect width="150" height="138" fill="#FFE9A8" opacity=".25"/>');
    }
    s.write('<rect y="138" width="150" height="22" fill="${room.floor}"/>');
    s.write(_floorDetail(ri));
    for (final i in lv) {
      if (done.contains(i)) {
        s.write('<g>${decorSvg(i, styles[i] ?? 0)}</g>');
      } else {
        s.write(_boxArt(_decorBase[i]));
      }
    }
    if (full) {
      s.write('<circle cx="136" cy="14" r="9" fill="#7FC4AA"/>'
          '<path d="M131.5 14l3 3 6-6" stroke="#173A2E" stroke-width="2.2" fill="none" stroke-linecap="round"/>');
    }
    s.write('</g>');
  }
  if (extended) {
    s
      ..write('<rect x="30" y="-220" width="300" height="640" fill="none" stroke="$hl" stroke-width="4" rx="2"/>')
      ..write('<path d="M180 -220V420M30 260H330M30 -60H330" fill="none" stroke="$hl" stroke-width="4"/>')
      ..write('<path d="M30 100H330" fill="none" stroke="$hl" stroke-width="7"/>')
      ..write('<rect x="30" y="436" width="300" height="160" fill="none" stroke="$hl" stroke-width="4" rx="2"/>')
      ..write('<path d="M180 436V596" fill="none" stroke="$hl" stroke-width="3"/>');
  } else {
    s
      ..write('<rect x="30" y="-60" width="300" height="480" fill="none" stroke="$hl" stroke-width="4" rx="2"/>')
      ..write('<path d="M180 -60V420M30 260H330" fill="none" stroke="$hl" stroke-width="4"/>')
      ..write('<path d="M30 100H330" fill="none" stroke="$hl" stroke-width="7"/>');
  }
  // rewards from daily boxes (and the Supporter Pack puppy)
  for (var k = 0; k < _pets.length; k++) {
    final earned = k < milestones.length
        ? dailyTotal >= milestones[k]
        : (k == supporterPet && puppy);
    if (!earned) {
      continue;
    }
    final p = _pets[k];
    if (p.room < 0) {
      s.write('<g>${p.svg}</g>');
    } else if (p.room < roomCount) {
      final room = rooms[p.room];
      s.write('<g transform="translate(${fmtNum(room.x)} ${fmtNum(room.y)})"><g>${p.svg}</g></g>');
    }
  }
  return svgDocument(extended ? houseViewBox : houseViewBoxLegacy, s.toString());
}

/// Where the sparkles go when pet [pet] arrives, in house space (the garden
/// has two bushes, so two spots).
List<Offset> petSpots(int pet) {
  if (pet < 0 || pet >= _pets.length) {
    return const <Offset>[];
  }
  final p = _pets[pet];
  if (p.room < 0) {
    return const <Offset>[Offset(28, 410), Offset(332, 410)];
  }
  final room = rooms[p.room];
  return <Offset>[
    Offset(room.x + (p.box[0] + p.box[2]) / 2, room.y + (p.box[1] + p.box[3]) / 2),
  ];
}

/// Room of pet [pet] (-1 for the flower garden by the house).
int petRoom(int pet) => _pets[pet].room;

/// Tap area of furniture [levelIndex] in house space, for toggling its style.
Rect decorHitRect(int levelIndex) {
  final room = rooms[levelRoom[levelIndex]];
  final b = _decorBox[levelIndex];
  var rect = Rect.fromLTRB(
          room.x + b[0], room.y + b[1], room.x + b[2], room.y + b[3])
      .inflate(5);
  if (rect.width < 40) {
    rect = Rect.fromCenter(center: rect.center, width: 40, height: rect.height);
  }
  if (rect.height < 40) {
    rect = Rect.fromCenter(center: rect.center, width: rect.width, height: 40);
  }
  return rect;
}

/// viewBox string that zooms onto [box] (left, top, right, bottom), like
/// zoomPreviews() in the HTML.
String _zoomViewBox(List<double> box) {
  final w = box[2] - box[0];
  final h = box[3] - box[1];
  final side = math.max(w, h) * 1.3 + 8;
  final cx = box[0] + w / 2;
  final cy = box[1] + h / 2;
  return '${(cx - side / 2).toStringAsFixed(1)} ${(cy - side / 2).toStringAsFixed(1)} '
      '${side.toStringAsFixed(1)} ${side.toStringAsFixed(1)}';
}

/// Furniture preview for the win card (variant 0..2): the piece in its room
/// colours, zoomed onto the piece like zoomPreviews() does.
String decorPreviewSvg(int levelIndex, int variant) {
  final room = rooms[levelRoom[levelIndex]];
  final body = '<rect x="-150" y="-160" width="450" height="480" fill="${room.wall}"/>'
      '<rect x="-150" y="138" width="450" height="200" fill="${room.floor}"/>'
      '<g>${decorSvg(levelIndex, variant)}</g>';
  return svgDocument(_zoomViewBox(_decorBox[levelIndex]), body);
}

final RegExp _anyHex = RegExp(r'#([0-9A-Fa-f]{6})');

String _greyscale(String svg) {
  return svg.replaceAllMapped(_anyHex, (Match m) {
    final v = int.parse(m[1]!, radix: 16);
    final r = (v >> 16) & 0xFF;
    final g = (v >> 8) & 0xFF;
    final b = v & 0xFF;
    final y = (0.2126 * r + 0.7152 * g + 0.0722 * b).round().clamp(0, 255).toInt();
    final h = y.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$h$h$h';
  });
}

/// Pet/garden preview for the daily win card. [locked] = greyed out at 35% opacity.
String petPreviewSvg(int petIndex, {required bool locked}) {
  final p = _pets[petIndex];
  final out = p.room < 0;
  final bg = out ? '#DDEFE3' : rooms[p.room].wall;
  final fl = out ? '#C9E4D1' : rooms[p.room].floor;
  final floorY = out ? 421 : 138;
  var body = '<rect x="-300" y="-300" width="900" height="1000" fill="$bg"/>'
      '<rect x="-300" y="$floorY" width="900" height="400" fill="$fl"/>'
      '<g>${p.one}</g>';
  if (locked) {
    body = '<g opacity="0.35">${_greyscale(body)}</g>';
  }
  return svgDocument(_zoomViewBox(p.box), body);
}
