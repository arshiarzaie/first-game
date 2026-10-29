import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/config/game_config.dart';

/// S4 world-table contracts: every world resolves to a distinct backdrop
/// asset, an in-bounds painted-horizon anchor and a full track palette.
void main() {
  test('worlds resolve distinct backdrop assets', () {
    expect(GameConfig.backdropKeyFor(GameWorld.duskHollow),
        isNot(equals(GameConfig.backdropKeyFor(GameWorld.moonveilMarsh))));
    expect(GameConfig.backdropKeyFor(GameWorld.duskHollow),
        startsWith('worlds/'));
    expect(GameConfig.backdropKeyFor(GameWorld.moonveilMarsh),
        startsWith('worlds/moonveil_marsh/'));
  });

  test('painted-horizon anchors stay within the drawable image', () {
    for (final world in GameWorld.values) {
      final fraction = GameConfig.backdropHorizonFractionFor(world);
      expect(fraction, greaterThan(0));
      expect(fraction, lessThan(1));
    }
  });

  test('track strip keys exist and are distinct for every world', () {
    final keys = GameWorld.values
        .map(GameConfig.trackStripKeyFor)
        .toList();
    for (final key in keys) {
      expect(key, isNotNull);
      expect(key, contains('track_strip.png'));
      expect(key!.startsWith('assets/'), isFalse,
          reason: 'Flame images.load already prefixes assets/images/');
    }
    expect(keys.toSet().length, equals(GameWorld.values.length));
  });

  test('corridor pillar and prop keys use Flame-relative paths', () {
    final pillarKeys =
        GameWorld.values.map(GameConfig.corridorPillarKeyFor).toList();
    expect(pillarKeys.toSet().length, equals(GameWorld.values.length));
    for (final key in [
      ...pillarKeys,
      GameConfig.orbSpriteAsset,
      GameConfig.obstacleSpriteAsset,
      GameConfig.obstacleArchSpriteAsset,
      GameConfig.obstacleMonolithSpriteAsset,
    ]) {
      expect(key.startsWith('assets/'), isFalse,
          reason: 'Flame images.load keys must not double-prefix assets/');
    }
  });

  test('every world has a complete opaque-free track palette', () {
    for (final world in GameWorld.values) {
      final values = <int>[
        GameConfig.trackFillArgbFor(world),
        GameConfig.trackEdgeArgbFor(world),
        GameConfig.trackLaneArgbFor(world),
        GameConfig.trackStripeArgbFor(world),
      ];
      for (final argb in values) {
        // All palette colors are translucent-but-visible (alpha > 0x40).
        expect(argb >>> 24, greaterThan(0x40));
      }
    }
  });
}
