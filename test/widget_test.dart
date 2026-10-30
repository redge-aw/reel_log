import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_log/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';


class _ThrowingStore extends InMemorySharedPreferencesStore {
  _ThrowingStore.empty() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    throw Exception('write fail');
  }
}

Future<void> _pumpApp(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  await t.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(const MainApp());
  await t.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester t) async {
  await t.tap(find.text('Log a film'));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('logTitle')), findsOneWidget);
}

Future<List<dynamic>> _readStore() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString('reel_log_films')!) as List;
}

Future<String?> _readRawStore() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('reel_log_films');
}

Future<void> _openDetail(WidgetTester t, String title) async {
  await t.tap(find.text(title));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('detailBack')), findsOneWidget);
}

Future<void> _pumpCustomFilms(
    WidgetTester t, List<Map<String, dynamic>> films) async {
  SharedPreferences.setMockInitialValues(
      {'reel_log_films': jsonEncode(films)});
  await t.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(const MainApp());
  await t.pumpAndSettle();
}

Map<String, dynamic> _storedFilm(List<dynamic> films, String title) =>
    films.cast<Map<String, dynamic>>().firstWhere((f) => f['title'] == title);

Future<void> _tapSave(WidgetTester t) async {
  await t.pump(); // flush the last entered text into field state
  await t.tap(find.widgetWithText(FilledButton, 'Save'));
  await t.pumpAndSettle();
}

String _fieldText(WidgetTester t, Key key) =>
    t.widget<TextField>(find.byKey(key)).controller!.text;

void main() {
  test('Film JSON round-trips through the persistence format', () {
    final f = Film(
      id: 5,
      title: 'Arrival',
      year: 2016,
      watchedYear: 2026,
      rating: 5,
      notes: 'Third watch. The structure still lands.',
    );
    final back = Film.fromJson(
        jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>);
    expect(back.id, 5);
    expect(back.title, 'Arrival');
    expect(back.year, 2016);
    expect(back.rating, 5);
    expect(back.notes, 'Third watch. The structure still lands.');
    expect(back.watchedYear, 2026);
  });

  test('Film without a release year omits it from JSON', () {
    final back = Film.fromJson(
        jsonDecode(jsonEncode(const Film(id: 9, title: 'Aftersun', watchedYear: 2024, rating: 0)))
            as Map<String, dynamic>);
    expect(back.year, isNull);
    expect((jsonDecode(jsonEncode(const Film(id: 9, title: 'Aftersun', watchedYear: 2024, rating: 0)))
        as Map<String, dynamic>).containsKey('year'), isFalse);
    final withYear = Film.fromJson(
        jsonDecode(jsonEncode(const Film(id: 10, title: 'Arrival', year: 2016, watchedYear: 2026, rating: 5)))
            as Map<String, dynamic>);
    expect(withYear.year, 2016);
  });

  test('Film round-trips the watched-year shape, legacy dates load as years',
      () {
    final back = Film.fromJson(
        jsonDecode(jsonEncode(const Film(id: 11, title: 'Aftersun', watchedYear: 2020, rating: 0)))
            as Map<String, dynamic>);
    expect(back.watchedYear, 2020);
    expect(
        (jsonDecode(jsonEncode(const Film(id: 11, title: 'Aftersun', watchedYear: 2020, rating: 0)))
            as Map<String, dynamic>)['watched'],
        2020);
    final legacy = Film.fromJson({
      'id': 12,
      'title': 'Old Film',
      'year': 1999,
      'watched': '2020-05-04T00:00:00.000',
      'rating': 4,
      'notes': 'Kept.',
      'director': 'Someone',
    });
    expect(legacy.watchedYear, 2020);
    expect(legacy.year, 1999);
  });

  test('Film without notes omits them from JSON', () {
    final back = Film.fromJson(
        jsonDecode(jsonEncode(const Film(id: 13, title: 'Aftersun', watchedYear: 2024, rating: 0)))
            as Map<String, dynamic>);
    expect(back.notes, isNull);
    expect((jsonDecode(jsonEncode(const Film(id: 13, title: 'Aftersun', watchedYear: 2024, rating: 0)))
        as Map<String, dynamic>).containsKey('notes'), isFalse);
    final withNotes = Film.fromJson(
        jsonDecode(jsonEncode(const Film(id: 14, title: 'Arrival', watchedYear: 2026, rating: 5, notes: 'Kept.')))
            as Map<String, dynamic>);
    expect(withNotes.notes, 'Kept.');
  });

  testWidgets('renders seed, search narrows, Rated 4+ filters', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MainApp());
    await t.pumpAndSettle();

    // Demo seed: 5 films averaging 4.4.
    expect(find.text('Dune: Part Two'), findsOneWidget);
    expect(find.text('Parasite'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('4.4'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'arrival');
    await t.pumpAndSettle();
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Parasite'), findsNothing);

    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();
    await t.tap(find.text('Rated 4+'));
    await t.pumpAndSettle();
    expect(find.text('Oppenheimer'), findsNothing); // rated 3
    expect(find.text('Arrival'), findsOneWidget);
  });

  testWidgets('log sheet opens and Save is gated by the title', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MainApp());
    await t.pumpAndSettle();

    await t.tap(find.text('Log a film'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('logTitle')), findsOneWidget);
    expect(find.byKey(const Key('logReleaseYear')), findsOneWidget);
    expect(find.byKey(const Key('logWatchedYear')), findsOneWidget);
    expect(find.byKey(const Key('logNotes')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    FilledButton save() =>
        t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(save().onPressed, isNull); // empty title

    await t.enterText(find.byKey(const Key('logTitle')), '   ');
    await t.pump();
    expect(save().onPressed, isNull); // whitespace title

    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.pump();
    expect(save().onPressed, isNotNull);

    await t.enterText(find.byKey(const Key('logTitle')), '');
    await t.pump();
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(save().onPressed, isNull);

    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.pump();
    expect(find.text('Enter a title.'), findsNothing);
    expect(save().onPressed, isNotNull);
  });


  testWidgets('blank release year saves absent with no year on the row',
      (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.enterText(find.byKey(const Key('logWatchedYear')), '2020');
    await _tapSave(t);
    expect(find.text('Save'), findsNothing); // sheet closed
    expect(find.text('Aftersun'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget); // watched year shown
    final films = await _readStore();
    final saved = _storedFilm(films, 'Aftersun');
    expect(saved.containsKey('year'), isFalse);
    expect(saved['watched'], 2020);
  });

  testWidgets('release year longer than four digits is kept as four',
      (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.enterText(find.byKey(const Key('logReleaseYear')), '20219');
    expect(_fieldText(t, const Key('logReleaseYear')), '2021');
    await _tapSave(t);
    expect(_storedFilm(await _readStore(), 'Aftersun')['year'], 2021);
  });

  testWidgets('unrated save leaves the average unchanged', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await _tapSave(t);
    expect(find.text('4.4'), findsOneWidget);
    expect(_storedFilm(await _readStore(), 'Aftersun')['rating'], 0);
  });

  testWidgets('tapping the selected star clears the rating', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.tap(find.byTooltip('4 of 5'));
    await t.pump();
    await t.tap(find.byTooltip('4 of 5'));
    await t.pump();
    await _tapSave(t);
    expect(_storedFilm(await _readStore(), 'Aftersun')['rating'], 0);
  });

  testWidgets('saved rating is stored and moves the average', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.tap(find.byTooltip('3 of 5'));
    await t.pump();
    await _tapSave(t);
    expect(_storedFilm(await _readStore(), 'Aftersun')['rating'], 3);
    expect(find.text('4.2'), findsOneWidget); // (22 + 3) / 6
  });

  testWidgets('Cancel discards the draft', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    expect(find.text('Aftersun'), findsNothing);
    expect((await _readStore()).length, 5);
  });

  testWidgets('close control discards the draft', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.tap(find.byKey(const Key('logClose')));
    await t.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    expect(find.text('Aftersun'), findsNothing);
    expect((await _readStore()).length, 5);
  });

  testWidgets('tapping outside the sheet discards the draft', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.tapAt(const Offset(20, 80));
    await t.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    expect(find.text('Aftersun'), findsNothing);
    expect((await _readStore()).length, 5);
  });

  testWidgets('dragging the sheet down discards the draft', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.fling(find.byIcon(Icons.close), const Offset(0, 400), 800);
    await t.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    expect(find.text('Aftersun'), findsNothing);
    expect((await _readStore()).length, 5);
  });

  testWidgets('earlier watched year sorts below a later one', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.enterText(find.byKey(const Key('logWatchedYear')), '2020');
    await _tapSave(t);
    expect(find.text('Aftersun'), findsOneWidget);
    final topNew = t.getTopLeft(find.text('Aftersun')).dy;
    final topLater = t.getTopLeft(find.text('Parasite')).dy; // watched 2025
    expect(topNew, greaterThan(topLater));
  });

  testWidgets('notes are trimmed, blank notes stored absent', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.enterText(
        find.byKey(const Key('logNotes')), '  Great sound.  ');
    await _tapSave(t);
    expect(
        _storedFilm(await _readStore(), 'Aftersun')['notes'], 'Great sound.');

    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Anora');
    await _tapSave(t);
    expect(_storedFilm(await _readStore(), 'Anora').containsKey('notes'),
        isFalse);
  });

  testWidgets('saves receive distinct unused ids', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await _tapSave(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Anora');
    await _tapSave(t);
    final films = await _readStore();
    final first = _storedFilm(films, 'Aftersun')['id'] as int;
    final second = _storedFilm(films, 'Anora')['id'] as int;
    expect(first, isNot(second));
    expect({3, 5, 6, 7, 8}.contains(first), isFalse);
    expect({3, 5, 6, 7, 8}.contains(second), isFalse);
  });

  testWidgets('saved store has no director key', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await _tapSave(t);
    expect((await _readRawStore())!.contains('director'), isFalse);
  });

  testWidgets('saved film survives re-pump', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await _tapSave(t);
    await t.pumpWidget(const MainApp());
    await t.pumpAndSettle();
    expect(find.text('Aftersun'), findsOneWidget);
  });

  testWidgets('two-digit release year blocks save', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.enterText(find.byKey(const Key('logReleaseYear')), '99');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(find.text('Enter a 4-digit year.'), findsOneWidget);
    expect(find.byKey(const Key('logTitle')), findsOneWidget); // still open
    expect((await _readStore()).length, 5);
  });

  testWidgets('cleared watched year blocks save', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.enterText(find.byKey(const Key('logWatchedYear')), '');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(find.text('Enter a 4-digit year.'), findsOneWidget);
    expect(find.byKey(const Key('logTitle')), findsOneWidget); // still open
    expect((await _readStore()).length, 5);
  });

  testWidgets('two-digit watched year blocks save', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.enterText(find.byKey(const Key('logWatchedYear')), '20');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(find.text('Enter a 4-digit year.'), findsOneWidget);
    expect(find.byKey(const Key('logTitle')), findsOneWidget); // still open
    expect((await _readStore()).length, 5);
  });

  testWidgets('successful save trims the title and confirms it', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), ' Aftersun ');
    await _tapSave(t);
    expect(find.text('Save'), findsNothing); // sheet closed
    expect(find.text('Added "Aftersun"'), findsOneWidget);
    expect(find.text('Aftersun'), findsWidgets);
    expect(_storedFilm(await _readStore(), 'Aftersun')['title'], 'Aftersun');
  });

  testWidgets('watched year defaults to the current year', (t) async {
    await _pumpApp(t);
    await _openSheet(t);
    expect(_fieldText(t, const Key('logWatchedYear')),
        '${DateTime.now().year}');
  });

  testWidgets('write failure rolls back and keeps the draft', (t) async {
    await _pumpApp(t);
    final platform = SharedPreferencesStorePlatform.instance;
    addTearDown(
        () => SharedPreferencesStorePlatform.instance = platform);
    SharedPreferences.setMockInitialValues({}); // reset instance cache
    SharedPreferencesStorePlatform.instance = _ThrowingStore.empty();
    await _openSheet(t);
    await t.enterText(find.byKey(const Key('logTitle')), 'Aftersun');
    await t.enterText(find.byKey(const Key('logReleaseYear')), '2022');
    await t.enterText(find.byKey(const Key('logNotes')), 'Keep me.');
    await t.tap(find.byTooltip('3 of 5'));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(find.text('Added "Aftersun"'), findsNothing);
    expect(find.text('Couldn\'t save "Aftersun". Try again.'),
        findsOneWidget);
    expect(find.byKey(const Key('logTitle')), findsOneWidget); // still open
    expect(_fieldText(t, const Key('logTitle')), 'Aftersun');
    expect(_fieldText(t, const Key('logReleaseYear')), '2022');
    expect(_fieldText(t, const Key('logNotes')), 'Keep me.');
    // Only the draft field matches: nothing reached the list.
    expect(find.text('Aftersun'), findsOneWidget);
  });

  testWidgets('prior saves with a year and a watched date still load',
      (t) async {
    SharedPreferences.setMockInitialValues({
      'reel_log_films': jsonEncode([
        {
          'id': 42,
          'title': 'Old Film',
          'year': 1999,
          'watched': '2020-05-04T00:00:00.000',
          'rating': 4,
          'notes': 'Kept.',
          'director': 'Someone',
        },
      ]),
    });
    await t.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MainApp());
    await t.pumpAndSettle();
    expect(find.text('Old Film'), findsOneWidget);
    expect(find.text('1999'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
  });

  testWidgets('detail opens from a row and back preserves search and filter',
      (t) async {
    await _pumpApp(t);
    await t.enterText(find.byType(TextField), 'dune');
    await t.pump();
    await t.tap(find.widgetWithText(ChoiceChip, '2026'));
    await t.pumpAndSettle();
    expect(find.text('Spirited Away'), findsNothing); // 2025 filtered out
    await _openDetail(t, 'Dune: Part Two');
    expect(_fieldText(t, const Key('detailTitle')), 'Dune: Part Two');
    expect(_fieldText(t, const Key('detailReleaseYear')), '2024');
    await t.tap(find.byKey(const Key('detailBack')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detailBack')), findsNothing);
    expect(find.text('Dune: Part Two'), findsOneWidget);
    expect(find.text('Spirited Away'), findsNothing); // filter preserved
  });

  testWidgets('detail shows empty editable release year when year is absent',
      (t) async {
    await _pumpCustomFilms(t, [
      {'id': 9, 'title': 'Aftersun', 'watched': 2024, 'rating': 0},
    ]);
    await _openDetail(t, 'Aftersun');
    expect(_fieldText(t, const Key('detailReleaseYear')), '');
    expect(_fieldText(t, const Key('detailTitle')), 'Aftersun');
    expect(_fieldText(t, const Key('detailWatchedYear')), '2024');
  });

  testWidgets('detail rating is sticky, persists, and updates the list',
      (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Arrival'); // seed rating 5
    expect(find.text('5 of 5'), findsOneWidget);
    expect(find.text('Not rated'), findsNothing);
    await t.tap(find.byTooltip('4 of 5'));
    await t.pumpAndSettle();
    expect(find.text('4 of 5'), findsOneWidget);
    expect(_storedFilm(await _readStore(), 'Arrival')['rating'], 4);
    await t.tap(find.byTooltip('4 of 5')); // re-tap keeps the rating
    await t.pumpAndSettle();
    expect(_storedFilm(await _readStore(), 'Arrival')['rating'], 4);
    expect(find.text('4 of 5'), findsOneWidget);
    await t.tap(find.byKey(const Key('detailBack')));
    await t.pumpAndSettle();
    expect(find.text('4.2'), findsOneWidget); // (4+4+3+5+5) / 5
  });

  testWidgets('detail shows Not rated for an unrated film', (t) async {
    await _pumpCustomFilms(t, [
      {'id': 9, 'title': 'Aftersun', 'watched': 2024, 'rating': 0},
    ]);
    await _openDetail(t, 'Aftersun');
    expect(find.text('Not rated'), findsOneWidget);
    await t.tap(find.byTooltip('3 of 5'));
    await t.pumpAndSettle();
    expect(find.text('3 of 5'), findsOneWidget);
    expect(_storedFilm(await _readStore(), 'Aftersun')['rating'], 3);
  });

  testWidgets('detail rating write failure reverts and shows an error',
      (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Oppenheimer'); // seed rating 3
    expect(find.text('3 of 5'), findsOneWidget);
    final platform = SharedPreferencesStorePlatform.instance;
    addTearDown(
        () => SharedPreferencesStorePlatform.instance = platform);
    SharedPreferences.setMockInitialValues({}); // reset instance cache
    SharedPreferencesStorePlatform.instance = _ThrowingStore.empty();
    await t.tap(find.byTooltip('5 of 5'));
    await t.pumpAndSettle();
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    expect(find.text('3 of 5'), findsOneWidget); // reverted
    await t.tap(find.byKey(const Key('detailBack')));
    await t.pumpAndSettle();
    expect(find.text('4.4'), findsOneWidget); // list unchanged
  });

  testWidgets('detail notes autosave after 500ms with caption', (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Parasite');
    expect(_fieldText(t, const Key('detailNotes')),
        'Staircases everywhere once you notice them.');
    expect(find.text('Saved automatically'), findsOneWidget);
    await t.enterText(find.byKey(const Key('detailNotes')), 'New note.');
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(
        _storedFilm(await _readStore(), 'Parasite')['notes'], 'New note.');
    expect(find.text('Saved automatically'), findsOneWidget);
  });

  testWidgets('detail blank notes are stored absent', (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Parasite');
    await t.enterText(find.byKey(const Key('detailNotes')), '   ');
    await t.pump();
    await t.tap(find.byKey(const Key('detailBack')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detailBack')), findsNothing); // popped
    expect(_storedFilm(await _readStore(), 'Parasite').containsKey('notes'),
        isFalse);
  });

  testWidgets('detail notes flush on back before 500ms elapses', (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Dune: Part Two'); // seed has no notes
    await t.enterText(find.byKey(const Key('detailNotes')), 'Typed fast.');
    await t.pump();
    await t.tap(find.byKey(const Key('detailBack')));
    await t.pumpAndSettle();
    expect(_storedFilm(await _readStore(), 'Dune: Part Two')['notes'],
        'Typed fast.');
  });

  testWidgets('detail shows Film not found when the id is missing',
      (t) async {
    SharedPreferences.setMockInitialValues({
      'reel_log_films': jsonEncode([
        {'id': 42, 'title': 'Only Film', 'watched': 2024, 'rating': 3},
      ]),
    });
    await t.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MainApp());
    // Seed rows show before the load completes; Dune's id is gone after it.
    await t.tap(find.text('Dune: Part Two'));
    await t.pumpAndSettle();
    expect(find.text('Film not found.'), findsOneWidget);
    expect(find.text('Only Film'), findsOneWidget);
  });

  testWidgets('detail whitespace title is blocked, valid title trims',
      (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Dune: Part Two');
    await t.enterText(find.byKey(const Key('detailTitle')), '   ');
    await t.pump();
    await t.tap(find.byKey(const Key('detailBack')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detailBack')), findsOneWidget); // stays
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(_storedFilm(await _readStore(), 'Dune: Part Two')['title'],
        'Dune: Part Two');
    await t.enterText(find.byKey(const Key('detailTitle')), ' Past Lives ');
    await t.pump();
    await t.tap(find.byKey(const Key('detailNotes'))); // blur commits
    await t.pumpAndSettle();
    expect(find.text('Enter a title.'), findsNothing);
    expect(find.text('PL'), findsWidgets); // poster initials updated
    expect(_storedFilm(await _readStore(), 'Past Lives')['title'],
        'Past Lives');
  });

  testWidgets('detail short release year is blocked', (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Dune: Part Two');
    await t.enterText(find.byKey(const Key('detailReleaseYear')), '99');
    await t.pump();
    await t.tap(find.byKey(const Key('detailBack')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detailBack')), findsOneWidget); // stays
    expect(find.text('Enter a 4-digit year.'), findsOneWidget);
    expect(_storedFilm(await _readStore(), 'Dune: Part Two')['year'], 2024);
  });

  testWidgets('detail watched year validates, release blank stores absent',
      (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Dune: Part Two'); // year 2024, watched 2026
    await t.enterText(find.byKey(const Key('detailWatchedYear')), '20');
    await t.pump();
    await t.tap(find.byKey(const Key('detailBack')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detailBack')), findsOneWidget); // stays
    expect(find.text('Enter a 4-digit year.'), findsOneWidget);
    expect(
        _storedFilm(await _readStore(), 'Dune: Part Two')['watched'], 2026);
    await t.enterText(find.byKey(const Key('detailWatchedYear')), '2020');
    await t.enterText(find.byKey(const Key('detailReleaseYear')), '');
    await t.pump();
    await t.tap(find.byKey(const Key('detailNotes'))); // blur commits
    await t.pumpAndSettle();
    expect(find.text('Enter a 4-digit year.'), findsNothing);
    final saved = _storedFilm(await _readStore(), 'Dune: Part Two');
    expect(saved['watched'], 2020);
    expect(saved.containsKey('year'), isFalse);
  });

  testWidgets('detail text write failure keeps draft and stays open on back',
      (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Dune: Part Two');
    final platform = SharedPreferencesStorePlatform.instance;
    addTearDown(
        () => SharedPreferencesStorePlatform.instance = platform);
    SharedPreferences.setMockInitialValues({}); // reset instance cache
    SharedPreferencesStorePlatform.instance = _ThrowingStore.empty();
    await t.enterText(find.byKey(const Key('detailNotes')), 'Lost draft?');
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    expect(_fieldText(t, const Key('detailNotes')), 'Lost draft?');
    await t.tap(find.byKey(const Key('detailBack'))); // flush fails: stays
    await t.pumpAndSettle();
    expect(find.byKey(const Key('detailBack')), findsOneWidget);
    expect(_fieldText(t, const Key('detailNotes')), 'Lost draft?');
  });

  testWidgets('detail watched year write failure keeps the draft',
      (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Dune: Part Two');
    final platform = SharedPreferencesStorePlatform.instance;
    addTearDown(
        () => SharedPreferencesStorePlatform.instance = platform);
    SharedPreferences.setMockInitialValues({}); // reset instance cache
    SharedPreferencesStorePlatform.instance = _ThrowingStore.empty();
    await t.enterText(find.byKey(const Key('detailWatchedYear')), '2020');
    await t.pump();
    await t.tap(find.byKey(const Key('detailNotes'))); // blur commits
    await t.pumpAndSettle();
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    expect(_fieldText(t, const Key('detailWatchedYear')), '2020');
  });

  testWidgets('detail has no share/remove controls or unmodeled keys',
      (t) async {
    await _pumpApp(t);
    await _openDetail(t, 'Arrival');
    expect(find.text('Share'), findsNothing);
    expect(find.text('Share film'), findsNothing);
    expect(find.text('Remove'), findsNothing);
    await t.tap(find.byTooltip('4 of 5'));
    await t.pumpAndSettle();
    final raw = await _readRawStore();
    expect(raw!.contains('director'), isFalse);
    expect(raw.contains('runtime'), isFalse);
    expect(raw.contains('genre'), isFalse);
  });
}
