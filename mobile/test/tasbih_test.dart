import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/tasbih/data/tasbih_repository.dart';
import 'package:lahuma/features/tasbih/domain/tasbih.dart';
import 'package:lahuma/features/tasbih/presentation/tasbih_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('beadsCounted', () {
    test('goes across for 33, back for the next 33', () {
      expect(beadsCounted(0), 0);
      expect(beadsCounted(1), 1);
      expect(beadsCounted(33), 33);
      expect(beadsCounted(34), 32);
      expect(beadsCounted(66), 0);
      expect(beadsCounted(67), 1);
    });

    test('every tap moves exactly one bead', () {
      for (var n = 0; n < 250; n++) {
        expect((beadsCounted(n + 1) - beadsCounted(n)).abs(), 1,
            reason: 'from $n');
      }
    });
  });

  group('TasbihNotifier', () {
    late DateTime clock;
    late TasbihRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      clock = DateTime(2026, 11, 2, 6);
      repo = TasbihRepository(now: () => clock);
    });

    Future<TasbihNotifier> loaded() async {
      final n = TasbihNotifier(repo);
      await Future<void>.delayed(Duration.zero);
      return n;
    }

    Future<void> saved() => Future<void>.delayed(Duration.zero);

    test('ignores taps until the saved state is read', () {
      final n = TasbihNotifier(repo);
      expect(n.increment(), TasbihTap.ignored);
      expect(n.state.count, 0);
    });

    test('reports rounds of 33 and the target', () async {
      final n = await loaded();
      n.select('tahlil'); // 100
      final taps = [for (var i = 0; i < 100; i++) n.increment()];
      expect(taps[32], TasbihTap.round);
      expect(taps[65], TasbihTap.round);
      expect(taps[98], TasbihTap.round);
      expect(taps[99], TasbihTap.reached);
      expect(taps.where((t) => t == TasbihTap.counted).length, 96);
      expect(n.increment(), TasbihTap.counted, reason: 'counting on');
    });

    test('undo takes back the count and its stats', () async {
      final n = await loaded();
      expect(n.undo(), isFalse);
      n.increment();
      n.increment();
      expect(n.undo(), isTrue);
      expect(n.state.count, 1);
      expect(n.state.stats.todayOn('2026-11-02'), 1);
      expect(n.state.stats.totalOf('subhan'), 1);
    });

    test('reset clears the count but keeps the stats', () async {
      final n = await loaded();
      for (var i = 0; i < 5; i++) {
        n.increment();
      }
      n.reset();
      expect(n.state.count, 0);
      expect(n.state.stats.totalOf('subhan'), 5);
    });

    test('next starts a finished dhikr afresh and keeps an unfinished one',
        () async {
      final n = await loaded();
      for (var i = 0; i < 33; i++) {
        n.increment();
      }
      n.next();
      expect(n.state.currentId, 'hamd');
      expect(n.state.countOf('subhan'), 0);

      n.increment();
      n.next();
      expect(n.state.countOf('hamd'), 1);
    });

    test('next wraps from the last dhikr to the first', () async {
      final n = await loaded();
      n.select('salah');
      n.next();
      expect(n.state.currentId, 'subhan');
    });

    test('today starts from zero on a new day; totals carry on', () async {
      final n = await loaded();
      n.increment();
      n.increment();
      clock = DateTime(2026, 11, 3, 6);
      n.increment();
      expect(n.state.stats.todayOn('2026-11-03'), 1);
      expect(n.state.stats.totalOf('subhan'), 3);
    });

    test('persists choice, counts, targets, custom adhkar and settings',
        () async {
      final n = await loaded();
      n.setTarget('subhan', 99);
      n.setTarget('hamd', null);
      final custom = n.addCustom('  سبحان الله وبحمده  ', 7);
      n.increment();
      n.increment();
      n.updateSettings(const TasbihSettings(
          sound: true, haptics: false, material: BeadMaterial.pearl));
      await saved();

      final state = await repo.load();
      expect(state.currentId, custom.id);
      expect(state.current.text, 'سبحان الله وبحمده');
      expect(state.current.target, 7);
      expect(state.count, 2);
      expect(state.adhkar.firstWhere((d) => d.id == 'subhan').target, 99);
      expect(state.adhkar.firstWhere((d) => d.id == 'hamd').target, isNull);
      expect(state.adhkar.firstWhere((d) => d.id == 'takbir').target, 34);
      expect(state.settings.sound, isTrue);
      expect(state.settings.haptics, isFalse);
      expect(state.settings.material, BeadMaterial.pearl);
      expect(state.stats.totalOf(custom.id), 2);
    });

    test('removing a custom dhikr drops its count and totals', () async {
      final n = await loaded();
      final custom = n.addCustom('ذكر', null);
      n.increment();
      n.remove(custom.id);
      expect(n.state.adhkar.any((d) => d.id == custom.id), isFalse);
      expect(n.state.currentId, 'subhan');
      expect(n.state.stats.totalOf(custom.id), 0);

      n.remove('subhan');
      expect(n.state.adhkar.any((d) => d.id == 'subhan'), isTrue,
          reason: 'presets stay');
    });

    test('fast tapping still saves the latest count', () async {
      final n = await loaded();
      for (var i = 0; i < 50; i++) {
        n.increment();
      }
      for (var i = 0; i < 5; i++) {
        await saved();
      }
      expect((await repo.load()).count, 50);
    });
  });
}
