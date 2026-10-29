import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reel_log/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Film JSON round-trips through the persistence format', () {
    final f = Film(
      id: 5,
      title: 'Arrival',
      year: 2016,
      watched: DateTime(2026, 8, 15),
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
    expect(back.watched, DateTime(2026, 8, 15));
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
}
