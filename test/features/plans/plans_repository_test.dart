import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/plans/data/plans_repository.dart';
import 'package:swipe_eat/features/plans/models/plan_slot.dart';

void main() {
  group('PlansRepository', () {
    test('constructs from an injected client without initialising Supabase',
        () {
      final client = SupabaseClient(
        'https://stub.supabase.co',
        'stub-anon-key',
      );
      addTearDown(client.dispose);

      expect(() => PlansRepository(client: client), returnsNormally);
    });

    test('construction is free; only the request needs the singleton', () {
      // The dashboard builds a PlansController before Supabase.initialize has
      // necessarily run, so nothing may touch the singleton until a request
      // actually goes out — where the controller catches and retries.
      final repository = PlansRepository();

      expect(repository.list(from: DateTime(2026, 9)), throwsA(isA<Error>()));
      expect(
        repository.create(restaurantId: 1, date: DateTime(2026, 9, 4)),
        throwsA(isA<Error>()),
      );
      expect(repository.cancel(1), throwsA(isA<Error>()));
      expect(repository.setTime(1, time: '20:00:00'), throwsA(isA<Error>()));
      expect(repository.markKept(DateTime(2026, 9, 2)), throwsA(isA<Error>()));
      expect(repository.stats(DateTime(2026, 9, 2)), throwsA(isA<Error>()));
    });
  });

  group('PlanSlot', () {
    test('the five chips are the design\'s five, dinner pre-pressed', () {
      expect(
        PlanSlot.all.map((slot) => slot.label),
        ['12:30', '18:30', '20:00', '21:30', 'Late'],
      );
      expect(PlanSlot.initial.label, '20:00');
    });

    test('a clock slot posts a time; Late posts a label instead', () {
      expect(PlanSlot.dinner.wireTime, '20:00:00');
      expect(PlanSlot.dinner.wireLabel, isNull);
      expect(PlanSlot.supper.wireTime, isNull);
      expect(PlanSlot.supper.wireLabel, 'late');
    });

    test('a stored row maps back onto the chip it was picked from', () {
      expect(
        PlanSlot.forStored(hour: 18, minute: 30, timeLabel: null)?.label,
        '18:30',
      );
      expect(
        PlanSlot.forStored(hour: null, minute: null, timeLabel: 'late')?.label,
        'Late',
      );
      // A time set from somewhere other than these chips still reads back.
      expect(planTimeText(hour: 19, minute: 5, timeLabel: null), '19:05');
      expect(planTimeText(hour: null, minute: null, timeLabel: 'late'), 'Late');
    });
  });
}
