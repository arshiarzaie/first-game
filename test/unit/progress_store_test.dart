import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soul_dusk_run/game/config/game_config.dart';
import 'package:soul_dusk_run/game/systems/progress_store.dart';

/// S8 progress-store contracts:
/// - the banked suns total starts at zero and accumulates via addSuns;
/// - totals persist across store reloads (same app launch);
/// - non-positive deposits never change the total (no negative state);
/// - world thresholds: Dusk Hollow open, then increasing requirement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('total starts at zero and accumulates', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ProgressStore.load();
    expect(store.totalSuns, equals(0));

    expect(await store.addSuns(3), equals(3));
    expect(store.totalSuns, equals(3));
    expect(await store.addSuns(4), equals(7));
    expect(store.totalSuns, equals(7));
  });

  test('suns persist across store reloads', () async {
    SharedPreferences.setMockInitialValues({'sdr_total_suns': 12});
    final store = await ProgressStore.load();
    expect(store.totalSuns, equals(12));
    await store.addSuns(8);

    final reloaded = await ProgressStore.load();
    expect(reloaded.totalSuns, equals(20));
  });

  test('zero or negative deposits never move the total', () async {
    SharedPreferences.setMockInitialValues({'sdr_total_suns': 5});
    final store = await ProgressStore.load();
    expect(await store.addSuns(0), equals(5));
    expect(await store.addSuns(-7), equals(5));
    expect(store.totalSuns, equals(5));
  });

  test('world unlock thresholds: dusk open, others increasing', () {
    expect(GameConfig.worldUnlockSunsFor(GameWorld.duskHollow), equals(0));
    expect(
      GameConfig.worldUnlockSunsFor(GameWorld.moonveilMarsh),
      greaterThan(0),
    );
    expect(
      GameConfig.worldUnlockSunsFor(GameWorld.emberfallCanyon),
      greaterThan(GameConfig.worldUnlockSunsFor(GameWorld.moonveilMarsh)),
    );
  });
}
