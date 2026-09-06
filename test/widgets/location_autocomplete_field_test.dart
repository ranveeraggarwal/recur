import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/places/fake_places_gateway.dart';
import 'package:recur/places/places_gateway.dart';
import 'package:recur/widgets/location_autocomplete_field.dart';

void main() {
  Future<TextEditingController> pumpField(
    WidgetTester tester,
    FakePlacesGateway places,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationAutocompleteField(
            controller: controller,
            places: places,
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('typing fewer than 3 characters does not search', (tester) async {
    final places = FakePlacesGateway();
    await pumpField(tester, places);

    await tester.enterText(find.byType(TextField), 'Ku');
    await tester.pump(const Duration(milliseconds: 500));

    expect(places.queries, isEmpty);
  });

  testWidgets('typing 3+ characters debounces then searches', (tester) async {
    final places = FakePlacesGateway()
      ..results = [
        const PlaceSuggestion(description: 'Kungsholmen, Stockholm, Sweden'),
      ];
    await pumpField(tester, places);

    await tester.enterText(find.byType(TextField), 'Kun');
    await tester.pump(const Duration(milliseconds: 100));
    expect(places.queries, isEmpty, reason: 'still within the debounce');

    await tester.pump(const Duration(milliseconds: 400));
    expect(places.queries, ['Kun']);
    expect(find.text('Kungsholmen, Stockholm, Sweden'), findsOneWidget);
  });

  testWidgets('tapping a suggestion fills the field and clears the list', (
    tester,
  ) async {
    final places = FakePlacesGateway()
      ..results = [
        const PlaceSuggestion(description: 'Kungsholmen, Stockholm, Sweden'),
      ];
    final controller = await pumpField(tester, places);

    await tester.enterText(find.byType(TextField), 'Kun');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Kungsholmen, Stockholm, Sweden'));
    await tester.pump();

    expect(controller.text, 'Kungsholmen, Stockholm, Sweden');
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('a suggestion longer than 80 characters is truncated', (
    tester,
  ) async {
    final longDescription = 'A' * 90;
    final places = FakePlacesGateway()
      ..results = [PlaceSuggestion(description: longDescription)];
    final controller = await pumpField(tester, places);

    await tester.enterText(find.byType(TextField), 'Kun');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(ListTile));
    await tester.pump();

    expect(controller.text.length, 80);
  });

  testWidgets('picking a suggestion does not search again or reopen the list', (
    tester,
  ) async {
    final places = FakePlacesGateway()
      ..results = [
        const PlaceSuggestion(description: 'Vasagatan 1, Stockholm'),
      ];
    await pumpField(tester, places);

    await tester.enterText(find.byType(TextField), 'Vasa');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Vasagatan 1, Stockholm'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ListTile), findsNothing);
    expect(places.queries.length, 1);
  });

  testWidgets('a programmatic text change while unfocused does not search', (
    tester,
  ) async {
    final places = FakePlacesGateway();
    final controller = await pumpField(tester, places);

    controller.text = 'Vasagatan 1';
    await tester.pump(const Duration(milliseconds: 500));

    expect(places.queries, isEmpty);
  });

  testWidgets('losing focus cancels a pending search', (tester) async {
    final places = FakePlacesGateway()
      ..results = [
        const PlaceSuggestion(description: 'Kungsholmen, Stockholm, Sweden'),
      ];
    await pumpField(tester, places);

    await tester.enterText(find.byType(TextField), 'Kun');
    await tester.pump(const Duration(milliseconds: 100));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ListTile), findsNothing);
  });
}
