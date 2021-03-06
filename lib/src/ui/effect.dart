library hauberk.ui.effect;

import 'dart:math' as math;

import 'package:malison/malison.dart';
import 'package:piecemeal/piecemeal.dart';

import '../engine.dart';

final _directionLines = {
  Direction.N: "|",
  Direction.NE: "/",
  Direction.E: "-",
  Direction.SE: r"\",
  Direction.S: "|",
  Direction.SW: "/",
  Direction.W: "-",
  Direction.NW: r"\"
};

/// Adds an [Effect]s that should be displayed when [event] happens.
void addEffects(List<Effect> effects, Event event) {
  switch (event.type) {
    case EventType.bolt:
    case EventType.cone:
      // TODO: Use something better for arrows.
      effects.add(new ElementEffect(event.pos, event.element));
      break;

    case EventType.toss:
      effects.add(new ItemEffect(event.pos, event.other));
      break;

    case EventType.hit:
      effects.add(new HitEffect(event.actor));
      break;

    case EventType.die:
      // TODO: Make number of particles vary based on monster health.
      for (var i = 0; i < 10; i++) {
        effects
            .add(new ParticleEffect(event.actor.x, event.actor.y, Color.red));
      }
      break;

    case EventType.heal:
      effects.add(new HealEffect(event.actor.pos.x, event.actor.pos.y));
      break;

    case EventType.fear:
      effects.add(new BlinkEffect(event.actor, Color.darkYellow));
      break;

    case EventType.courage:
      effects.add(new BlinkEffect(event.actor, Color.yellow));
      break;

    case EventType.detect:
      effects.add(new DetectEffect(event.pos));
      break;

    case EventType.teleport:
      var numParticles = (event.actor.pos - event.pos).kingLength * 2;
      for (var i = 0; i < numParticles; i++) {
        effects.add(new TeleportEffect(event.pos, event.actor.pos));
      }
      break;

    case EventType.spawn:
      // TODO: Something more interesting.
      effects.add(new FrameEffect(event.actor.pos, '*', Color.white));
      break;

    case EventType.howl:
      var colors = [Color.white, Color.lightGray, Color.gray, Color.gray];
      var color = colors[(event.other * 3).toInt()];
      effects.add(new FrameEffect(event.pos, '.', color));
      break;

    case EventType.slash:
    case EventType.stab:
      var line = _directionLines[event.dir];
      // TODO: Element color.
      effects.add(new FrameEffect(event.pos, line, Color.white));
      break;

    case EventType.gold:
      effects.add(new TreasureEffect(event.pos, event.other));
      break;
  }
}

typedef void DrawGlyph(int x, int y, Glyph glyph);

abstract class Effect {
  bool update(Game game);
  void render(Game game, DrawGlyph drawGlyph);
}

/// Creates a list of [Glyph]s for each combination of [chars] and [colors].
List<Glyph> _glyphs(String chars, List<Color> colors) {
  var results = <Glyph>[];
  for (var char in chars.codeUnits) {
    for (var color in colors) {
      results.add(new Glyph.fromCharCode(char, color));
    }
  }

  return results;
}

final _elementSequences = <Element, List<List<Glyph>>> {
  Element.none: [
    _glyphs("•", [Color.lightBrown]),
    _glyphs("•", [Color.lightBrown]),
    _glyphs("•", [Color.brown])
  ],
  Element.air: [
    _glyphs("Oo", [Color.white, Color.lightAqua]),
    _glyphs(".", [Color.lightAqua]),
    _glyphs(".", [Color.lightGray])
  ],
  Element.earth: [
    _glyphs("*%", [Color.lightBrown, Color.gold]),
    _glyphs("*%", [Color.brown, Color.darkOrange]),
    _glyphs("•*", [Color.brown]),
    _glyphs("•", [Color.darkBrown])
  ],
  Element.fire: [
    _glyphs("*", [Color.gold, Color.yellow]),
    _glyphs("*", [Color.orange]),
    _glyphs("•", [Color.red]),
    _glyphs("•", [Color.darkRed, Color.red]),
    _glyphs(".", [Color.darkRed, Color.red])
  ],
  Element.water: [
    _glyphs("Oo", [Color.aqua, Color.lightBlue]),
    _glyphs("o•~", [Color.blue]),
    _glyphs("~", [Color.blue]),
    _glyphs("~", [Color.darkBlue]),
    _glyphs(".", [Color.darkBlue])
  ],
  Element.acid: [
    _glyphs("Oo", [Color.yellow, Color.gold]),
    _glyphs("o•~", [Color.darkYellow, Color.gold]),
    _glyphs(":,", [Color.darkYellow, Color.darkGold]),
    _glyphs(".", [Color.darkYellow])
  ],
  Element.cold: [
    _glyphs("*", [Color.white]),
    _glyphs("+x", [Color.lightBlue, Color.white]),
    _glyphs("+x", [Color.lightBlue, Color.lightGray]),
    _glyphs(".", [Color.gray, Color.darkBlue])
  ],
  Element.lightning: [
    _glyphs("*", [Color.lightPurple]),
    _glyphs(r"-|\/", [Color.purple, Color.white]),
    _glyphs(".", [Color.black, Color.black, Color.black, Color.lightPurple])
  ],
  Element.poison: [
    _glyphs("Oo", [Color.yellow, Color.lightGreen]),
    _glyphs("o•", [Color.green, Color.green, Color.darkYellow]),
    _glyphs("•", [Color.darkGreen, Color.darkYellow]),
    _glyphs(".", [Color.darkGreen])
  ],
  Element.dark: [
    _glyphs("*%", [Color.black, Color.black, Color.lightGray]),
    _glyphs("•", [Color.black, Color.black, Color.gray]),
    _glyphs(".", [Color.black]),
    _glyphs(".", [Color.black])
  ],
  Element.light: [
    _glyphs("*", [Color.white]),
    _glyphs("x+", [Color.white, Color.lightYellow]),
    _glyphs(":;\"'`,", [Color.lightGray, Color.yellow]),
    _glyphs(".", [Color.gray, Color.yellow])
  ],
  Element.spirit: [
    _glyphs("Oo*+", [Color.lightPurple, Color.gray]),
    _glyphs("o+", [Color.purple, Color.green]),
    _glyphs("•.", [Color.darkPurple, Color.darkGreen, Color.darkGreen])
  ]
};

/// Draws a motionless particle for an [Element] that fades in intensity over
/// time.
class ElementEffect implements Effect {
  final Vec _pos;
  final List<List<Glyph>> _sequence;
  int _age = 0;

  ElementEffect(this._pos, Element element)
      : _sequence = _elementSequences[element];

  bool update(Game game) {
    if (rng.oneIn(_age + 1)) _age++;
    return _age <= _sequence.length;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    drawGlyph(_pos.x, _pos.y, rng.item(_sequence[_age - 1]));
  }
}

class FrameEffect implements Effect {
  final Vec pos;
  final String char;
  final Color color;
  int life;

  FrameEffect(this.pos, this.char, this.color, {this.life: 4});

  bool update(Game game) {
    if (!game.stage[pos].visible) return false;

    return --life >= 0;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    drawGlyph(pos.x, pos.y, new Glyph(char, color));
  }
}

/// Draws an [Item] as a given position. Used for thrown items.
class ItemEffect implements Effect {
  final Vec pos;
  final Item item;
  int _life = 2;

  ItemEffect(this.pos, this.item);

  bool update(Game game) {
    if (!game.stage[pos].visible) return false;

    return --_life >= 0;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    drawGlyph(pos.x, pos.y, item.appearance);
  }
}

/// Blinks the background color for an actor a couple of times.
class BlinkEffect implements Effect {
  final Actor actor;
  final Color color;
  int life = 8 * 3;

  BlinkEffect(this.actor, this.color);

  bool update(Game game) {
    return --life >= 0;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    if (!actor.isVisible) return;

    if ((life ~/ 8) % 2 == 0) {
      var glyph = actor.appearance;
      glyph = new Glyph.fromCharCode(glyph.char, glyph.fore, color);
      drawGlyph(actor.pos.x, actor.pos.y, glyph);
    }
  }
}

class HitEffect implements Effect {
  final Actor actor;
  final int health;
  int frame = 0;

  static final _numFrames = 23;

  HitEffect(Actor actor)
      : actor = actor,
        health = 10 * actor.health.current ~/ actor.health.max;

  bool update(Game game) {
    return frame++ < _numFrames;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    var back = const [
      Color.lightRed, Color.red, Color.darkRed, Color.black
    ][frame ~/ 6];

    drawGlyph(actor.x, actor.y,
        new Glyph(' 123456789'[health], Color.black, back));
  }
}

class ParticleEffect implements Effect {
  num x;
  num y;
  num h;
  num v;
  int life;
  final Color color;

  ParticleEffect(this.x, this.y, this.color) {
    final theta = rng.range(628) / 100;
    final radius = rng.range(30, 40) / 100;

    h = math.cos(theta) * radius;
    v = math.sin(theta) * radius;
    life = rng.range(7, 15);
  }

  bool update(Game game) {
    x += h;
    y += v;

    final pos = new Vec(x.toInt(), y.toInt());
    if (!game.stage.bounds.contains(pos)) return false;
    if (!game.stage[pos].isPassable) return false;

    return life-- > 0;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    drawGlyph(x.toInt(), y.toInt(), new Glyph('*', color));
  }
}

/// A particle that starts with a random initial velocity and arcs towards a
/// target.
class TeleportEffect implements Effect {
  num x;
  num y;
  num h;
  num v;
  int age = 0;
  final Vec target;

  static final _colors = [
    Color.lightAqua,
    Color.aqua,
    Color.lightBlue,
    Color.white
  ];

  TeleportEffect(Vec from, this.target) {
    x = from.x;
    y = from.y;

    var theta = rng.range(628) / 100;
    var radius = rng.range(10, 80) / 100;

    h = math.cos(theta) * radius;
    v = math.sin(theta) * radius;
  }

  bool update(Game game) {
    var friction = 1.0 - age * 0.015;
    h *= friction;
    v *= friction;

    var pull = age * 0.003;
    h += (target.x - x) * pull;
    v += (target.y - y) * pull;

    x += h;
    y += v;

    age++;
    return (new Vec(x, y) - target) > 1;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    var pos = new Vec(x.toInt(), y.toInt());
    if (!game.stage.bounds.contains(pos)) return;

    var char = _getChar(h, v);
    var color = rng.item(_colors);

    drawGlyph(pos.x, pos.y, new Glyph.fromCharCode(char, color));
  }

  /// Chooses a "line" character based on the vector [x], [y]. It will try to
  /// pick a line that follows the vector.
  _getChar(num x, num y) {
    var velocity = new Vec((x * 10).toInt(), (y * 10).toInt());
    if (velocity < 5) return CharCode.bullet;

    var angle = math.atan2(x, y) / (math.PI * 2) * 16 + 8;
    return r"|\\--//||\\--//||".codeUnitAt(angle.floor());
  }
}

class HealEffect implements Effect {
  int x;
  int y;
  int frame = 0;

  HealEffect(this.x, this.y);

  bool update(Game game) {
    return frame++ < 24;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    if (!game.stage.get(x, y).visible) return;

    var back;
    switch ((frame ~/ 4) % 4) {
      case 0: back = Color.black;      break;
      case 1: back = Color.darkAqua;   break;
      case 2: back = Color.aqua;       break;
      case 3: back = Color.lightAqua;  break;
    }

    drawGlyph(x - 1, y, new Glyph('-', back));
    drawGlyph(x + 1, y, new Glyph('-', back));
    drawGlyph(x, y - 1, new Glyph('|', back));
    drawGlyph(x, y + 1, new Glyph('|', back));
  }
}

class DetectEffect implements Effect {
  final Vec pos;
  int life = 30;

  DetectEffect(this.pos);

  bool update(Game game) {
    return --life >= 0;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    var radius = life ~/ 4;
    var glyph = new Glyph("*", Color.lightGold);

    var bounds = new Rect(
        pos.x - radius, pos.y - radius, radius * 2 + 1, radius * 2 + 1);

    for (var pixel in bounds) {
      var relative = pos - pixel;
      if (relative < radius && relative > radius - 2) {
        drawGlyph(pixel.x, pixel.y, glyph);
      }
    }
  }
}

/// Floats a treasure item upward.
class TreasureEffect implements Effect {
  final int _x;
  int _y;
  final Item _item;
  int _life = 8;

  TreasureEffect(Vec pos, this._item)
      : _x = pos.x,
        _y = pos.y;

  bool update(Game game) {
    if (_life % 2 == 0) {
      _y--;
      if (_y < 0) return false;
    }

    return --_life >= 0;
  }

  void render(Game game, DrawGlyph drawGlyph) {
    drawGlyph(_x, _y, _item.appearance);
  }
}
