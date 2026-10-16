import 'package:flutter_test/flutter_test.dart';
import 'package:soul_dusk_run/game/presentation/chroma_key.dart';

void main() {
  group('chromaKeyAlpha', () {
    test('exact key color (pure magenta) is fully transparent', () {
      expect(chromaKeyAlpha(255, 0, 255), 0.0);
    });

    test('near-key purple inside the softness window is transparent', () {
      // Distance 40 < softStart (60).
      expect(chromaKeyAlpha(235, 10, 240), 0.0);
    });

    test('Soul gold body colors stay fully opaque', () {
      // #FFD166 body core — far from magenta.
      expect(chromaKeyAlpha(255, 209, 102), 1.0);
      // #FF9F68 ray orange — far from magenta.
      expect(chromaKeyAlpha(255, 159, 104), 1.0);
    });

    test('brown eyes stay fully opaque', () {
      expect(chromaKeyAlpha(58, 42, 40), 1.0);
    });

    test('edge band fades monotonically between transparent and opaque', () {
      // Sweep across the soft band as distance grows.
      var previous = 0.0;
      for (var r = 196; r <= 255; r += 2) {
        final alpha = chromaKeyAlpha(r, 0, 115);
        expect(alpha, greaterThanOrEqualTo(previous));
        expect(alpha, lessThanOrEqualTo(1.0));
        previous = alpha;
      }
      // A mid-band color is partially transparent.
      final mid = chromaKeyAlpha(225, 0, 190);
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));
    });

    test('custom softer spec widens the fade band', () {
      const wide = ChromaKeySpec(softEnd: 300);
      const tight = ChromaKeySpec(softEnd: 120);
      const r = 255, g = 0, b = 140; // same color vs both specs
      expect(
        chromaKeyAlpha(r, g, b, wide),
        lessThan(chromaKeyAlpha(r, g, b, tight)),
      );
    });
  });
}
