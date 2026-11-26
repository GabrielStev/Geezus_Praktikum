// Smoke tests for Geezus Flutter app.
// These tests verify pure logic only — no Flutter widget pumping,
// since that would require Supabase, SQLite, and sensor initialization.

import 'package:flutter_test/flutter_test.dart';
import 'package:geezus/core/services/gym_store.dart';

void main() {
  group('GymStore — basic calculations', () {
    setUp(() {
      GymStore.instance.resetForTesting();
    });

    test('totalVolumeKg starts at 0 after reload', () {
      expect(GymStore.instance.totalVolumeKg, equals(0.0));
    });

    test('gymDamage starts at 0 after reload', () {
      expect(GymStore.instance.gymDamage, equals(0));
      expect(GymStore.instance.totalBaseDamage, equals(0));
    });
  });

}
