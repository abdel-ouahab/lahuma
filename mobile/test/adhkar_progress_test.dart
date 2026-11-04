import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/adhkar/data/adhkar_progress_repository.dart';
import 'package:lahuma/features/adhkar/domain/dhikr.dart';
import 'package:lahuma/features/adhkar/presentation/adhkar_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const thrice =
    Dhikr(period: AdhkarPeriod.morning, index: 2, text: 'نص', count: 3);
const once =
    Dhikr(period: AdhkarPeriod.evening, index: 0, text: 'نص', count: 1);

void main() {
  late DateTime clock;
  late AdhkarProgressRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 19, 7);
    repo = AdhkarProgressRepository(now: () => clock);
  });

  Future<AdhkarProgressNotifier> loaded() async {
    final n = AdhkarProgressNotifier(repo);
    await Future<void>.delayed(Duration.zero);
    return n;
  }

  test('counts up to the required count and reports completion once', () async {
    final n = await loaded();
    expect(n.increment(thrice), isFalse);
    expect(n.increment(thrice), isFalse);
    expect(n.increment(thrice), isTrue);
    expect(n.increment(thrice), isFalse, reason: 'already complete');
    expect(n.state.countOf(thrice.id), 3);
  });

  test('persists counts for the same day', () async {
    final n = await loaded();
    n.increment(thrice);
    n.increment(once);
    await Future<void>.delayed(Duration.zero);

    final progress = await repo.loadProgress();
    expect(progress.countOf('morning-2'), 1);
    expect(progress.countOf('evening-0'), 1);
  });

  test('starts from zero on a new day', () async {
    final n = await loaded();
    n.increment(thrice);
    await Future<void>.delayed(Duration.zero);

    clock = DateTime(2026, 10, 20, 7);
    expect((await repo.loadProgress()).countOf(thrice.id), 0);

    // Also when the app stayed open over midnight.
    expect(n.increment(thrice), isFalse);
    expect(n.state.date, '2026-10-20');
    expect(n.state.countOf(thrice.id), 1);
  });

  test('reset and resetAll clear counts', () async {
    final n = await loaded();
    n.increment(thrice);
    n.increment(once);
    n.reset(thrice);
    expect(n.state.countOf(thrice.id), 0);
    expect(n.state.countOf(once.id), 1);
    n.resetAll([thrice, once]);
    expect(n.state.counts, isEmpty);
  });

  test('ignores a corrupt stored value', () async {
    SharedPreferences.setMockInitialValues({'adhkar.progress': '{oops'});
    expect((await repo.loadProgress()).counts, isEmpty);
  });

  test('favourites toggle and persist', () async {
    final n = AdhkarFavoritesNotifier(repo);
    await Future<void>.delayed(Duration.zero);
    expect(n.toggle(thrice), isTrue);
    expect(n.toggle(once), isTrue);
    expect(n.toggle(once), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(await repo.loadFavorites(), {'morning-2'});

    final reloaded = AdhkarFavoritesNotifier(repo);
    await Future<void>.delayed(Duration.zero);
    expect(reloaded.state, {'morning-2'});
  });

  test('each finished dhikr counts once a day, totals persist', () async {
    final n = AdhkarCompletionsNotifier(repo);
    await Future<void>.delayed(Duration.zero);
    n.record(thrice);
    n.record(thrice); // same day: ignored
    n.record(once);
    clock = clock.add(const Duration(days: 1));
    n.record(thrice);
    expect(n.state.countOf(AdhkarPeriod.morning), 2);
    expect(n.state.countOf(AdhkarPeriod.evening), 1);

    final reloaded = AdhkarCompletionsNotifier(repo);
    await Future<void>.delayed(Duration.zero);
    expect(reloaded.state.countOf(AdhkarPeriod.morning), 2);
    expect(reloaded.state.countOf(AdhkarPeriod.evening), 1);
  });

  test('a dhikr finished before loading adds to the saved total', () async {
    await repo.saveCompletions(const AdhkarCompletions(
        counts: {AdhkarPeriod.morning: 4}, date: '2026-10-18'));
    final n = AdhkarCompletionsNotifier(repo)..record(thrice);
    await Future<void>.delayed(Duration.zero);
    expect(n.state.countOf(AdhkarPeriod.morning), 5);
    expect((await repo.loadCompletions()).countOf(AdhkarPeriod.morning), 5);
  });

  test('ignores corrupt stored completions', () async {
    SharedPreferences.setMockInitialValues({
      'adhkar.completions': '{"counts": {"morning": "x"}, "today": 3}',
    });
    final c = await repo.loadCompletions();
    expect(c.countOf(AdhkarPeriod.morning), 0);
    expect(c.countedToday, isEmpty);
  });

  test('today shows finished adhkar of a period out of all of them', () async {
    const single =
        Dhikr(period: AdhkarPeriod.morning, index: 0, text: 'نص', count: 1);
    final container = ProviderContainer(overrides: [
      adhkarProgressRepositoryProvider.overrideWithValue(repo),
      adhkarProvider.overrideWith((ref) async => const AdhkarCollection({
            AdhkarPeriod.morning: [single, thrice],
            AdhkarPeriod.evening: [once],
          })),
    ]);
    addTearDown(container.dispose);
    container.listen(adhkarTodayProvider(AdhkarPeriod.morning), (_, __) {});
    await container.read(adhkarProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(adhkarTodayProvider(AdhkarPeriod.morning)),
        (done: 0, total: 2));

    final n = container.read(adhkarProgressProvider.notifier);
    n.increment(single);
    n.increment(thrice);
    expect(container.read(adhkarTodayProvider(AdhkarPeriod.morning)),
        (done: 1, total: 2),
        reason: 'thrice is said once of three');

    // The app invalidates it on resume, so a new day starts from nothing.
    clock = DateTime(2026, 10, 20, 7);
    container.invalidate(adhkarTodayProvider);
    expect(container.read(adhkarTodayProvider(AdhkarPeriod.morning)),
        (done: 0, total: 2),
        reason: 'yesterday does not count');
  });
}
