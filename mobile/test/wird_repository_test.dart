import 'package:flutter_test/flutter_test.dart';
import 'package:lahuma/features/wird/data/wird_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime clock;
  late WirdRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 3, 10, 9);
    repo = WirdRepository(now: () => clock);
  });

  test('starts empty with the default goal', () async {
    final state = await repo.load();
    expect(state.ayahsToday, 0);
    expect(state.goal, WirdRepository.defaultGoal);
    expect(state.streak, 0);
  });

  test('accumulates ayahs and persists them', () async {
    var state = await repo.load();
    state = await repo.addRead(state, 5);
    state = await repo.addRead(state, 3);
    expect(state.ayahsToday, 8);
    expect((await repo.load()).ayahsToday, 8);
  });

  test('starts a streak the first time the goal is met, once per day',
      () async {
    var state = await repo.setGoal(await repo.load(), 10);
    state = await repo.addRead(state, 10);
    expect(state.goalReached, isTrue);
    expect(state.streak, 1);
    state = await repo.addRead(state, 4); // more reading must not add a day
    expect(state.streak, 1);
  });

  test('extends the streak on consecutive days and resets the count', () async {
    var state = await repo.setGoal(await repo.load(), 10);
    state = await repo.addRead(state, 10);

    clock = DateTime(2026, 3, 11, 9);
    state = await repo.load();
    expect(state.ayahsToday, 0, reason: 'a new day starts from zero');
    expect(state.streak, 1, reason: 'yesterday still counts');

    state = await repo.addRead(state, 10);
    expect(state.streak, 2);
  });

  test('breaks the streak after a missed day', () async {
    var state = await repo.setGoal(await repo.load(), 10);
    state = await repo.addRead(state, 10);

    clock = DateTime(2026, 3, 13, 9); // skipped the 11th and 12th
    state = await repo.load();
    expect(state.streak, 0);

    state = await repo.addRead(state, 10);
    expect(state.streak, 1);
  });

  test('fraction is capped at 1', () async {
    var state = await repo.setGoal(await repo.load(), 5);
    state = await repo.addRead(state, 20);
    expect(state.fraction, 1);
  });

  test('keeps earlier days in the history for the week strip', () async {
    var state = await repo.setGoal(await repo.load(), 10);
    state = await repo.addRead(state, 7);

    clock = DateTime(2026, 3, 11, 9);
    state = await repo.load();
    expect(state.countOn(DateTime(2026, 3, 10)), 7);
    expect(state.countOn(DateTime(2026, 3, 11)), 0);

    state = await repo.addRead(state, 4);
    expect(state.countOn(DateTime(2026, 3, 11)), 4);

    // Read without reloading first: the rollover still files yesterday.
    clock = DateTime(2026, 3, 12, 9);
    state = await repo.addRead(state, 2);
    expect(state.countOn(DateTime(2026, 3, 11)), 4);
    expect((await repo.load()).countOn(DateTime(2026, 3, 10)), 7);
  });

  test('drops history older than two weeks', () async {
    var state = await repo.addRead(await repo.load(), 3);
    clock = DateTime(2026, 3, 30, 9);
    state = await repo.load();
    expect(state.history, isEmpty);
  });
}
