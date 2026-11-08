import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/config/game_config.dart';

/// S4–S20 world-table & portal-cycle contracts: every world resolves to
/// distinct modular 3D assets, an in-bounds horizon anchor, Flame-relative
/// keys, a closed 3-world Crystal Portal cycle, and a complete track palette.
void main() {
  test('worlds resolve distinct backdrop and modular 3D element assets', () {
    expect(GameConfig.backdropKeyFor(GameWorld.duskHollow),
        isNot(equals(GameConfig.backdropKeyFor(GameWorld.moonveilMarsh))));
    expect(GameConfig.backdropKeyFor(GameWorld.duskHollow),
        startsWith('worlds/'));
    expect(GameConfig.backdropKeyFor(GameWorld.moonveilMarsh),
        startsWith('worlds/moonveil_marsh/'));

    expect(
      GameWorld.values.map(GameConfig.valleyFloorKeyFor).toSet().length,
      equals(GameWorld.values.length),
    );
    expect(
      GameWorld.values.map(GameConfig.canyonWallKeyFor).toSet().length,
      equals(GameWorld.values.length),
    );
    expect(
      GameWorld.values.map(GameConfig.skyCitadelKeyFor).toSet().length,
      equals(GameWorld.values.length),
    );
  });

  test('crystal portal biome cycle visits all three worlds in order', () {
    expect(GameConfig.nextWorldAfter(GameWorld.duskHollow),
        equals(GameWorld.moonveilMarsh));
    expect(GameConfig.nextWorldAfter(GameWorld.moonveilMarsh),
        equals(GameWorld.emberfallCanyon));
    expect(GameConfig.nextWorldAfter(GameWorld.emberfallCanyon),
        equals(GameWorld.duskHollow));
  });

  test('painted-horizon anchors stay within the drawable image', () {
    for (final world in GameWorld.values) {
      final fraction = GameConfig.backdropHorizonFractionFor(world);
      expect(fraction, greaterThan(0));
      expect(fraction, lessThan(1));
    }
  });

  test('track strip keys exist and are distinct for every world', () {
    final keys = GameWorld.values.map(GameConfig.trackStripKeyFor).toList();
    for (final key in keys) {
      expect(key, isNotNull);
      expect(key, contains('track_strip.png'));
      expect(key!.startsWith('assets/'), isFalse,
          reason: 'Flame images.load already prefixes assets/images/');
    }
    expect(keys.toSet().length, equals(GameWorld.values.length));
  });

  test('modular 3D world, close-up Soul, and portal keys use Flame-relative paths',
      () {
    final pillarKeys =
        GameWorld.values.map(GameConfig.corridorPillarKeyFor).toList();
    expect(pillarKeys.toSet().length, equals(GameWorld.values.length));
    for (final key in [
      ...pillarKeys,
      ...GameWorld.values.map(GameConfig.floatingIslandKeyFor),
      ...GameWorld.values.map(GameConfig.cliffSideKeyFor),
      ...GameWorld.values.map(GameConfig.valleyFloorKeyFor),
      ...GameWorld.values.map(GameConfig.canyonWallKeyFor),
      ...GameWorld.values.map(GameConfig.skyCitadelKeyFor),
      GameConfig.soulHoverOpenSpriteKey,
      GameConfig.soulHoverBlinkSpriteKey,
      GameConfig.soulJumpSpriteKey,
      GameConfig.soulSlideSpriteKey,
      GameConfig.orbSpriteAsset,
      GameConfig.obstacleSpriteAsset,
      GameConfig.obstacleArchSpriteAsset,
      GameConfig.obstacleMonolithSpriteAsset,
      GameConfig.goldenCloudSpriteAsset,
      GameConfig.viaductRuinSpriteAsset,
      GameConfig.skyCloudSpriteAsset,
      GameConfig.crystalPortalSpriteAsset,
    ]) {
      expect(key.startsWith('assets/'), isFalse,
          reason: 'Flame images.load keys must not double-prefix assets/');
    }
  });

  test('S22 24-frame athletic run cycle and wide 3-lane causeway invariants hold',
      () {
    expect(GameConfig.runFrameCount, equals(24));
    expect(GameConfig.runCycleFps, greaterThanOrEqualTo(24.0));

    // Grand 3-lane causeway is wide (>= 1.10 * screenWidth at player plane)
    // and offers >= 0.38 * screenHeight visible runway ahead of Soul!
    expect(GameConfig.trackBottomHalfWidthRatio, greaterThanOrEqualTo(0.55));
    final runwaySpan = GameConfig.playerPlaneRatio - GameConfig.horizonRatio;
    expect(runwaySpan, greaterThanOrEqualTo(0.38));
    expect(GameConfig.horizonRatio, inInclusiveRange(0.40, 0.50));
    expect(GameConfig.ambientParticleCount, greaterThanOrEqualTo(40));
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
        expect(argb >>> 24, greaterThan(0x40));
      }
    }
  });
}
