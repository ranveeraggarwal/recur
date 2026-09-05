import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recur/places/nominatim_places_gateway.dart';
import 'package:recur/places/places_gateway.dart';

void main() {
  group('NominatimPlacesGateway', () {
    test('a blank query returns no suggestions without a request', () async {
      var requested = false;
      final gateway = NominatimPlacesGateway(
        client: MockClient((request) async {
          requested = true;
          return http.Response('[]', 200);
        }),
      );

      final results = await gateway.search('   ');

      expect(results, isEmpty);
      expect(requested, isFalse);
    });

    test('maps display_name entries to suggestions', () async {
      final gateway = NominatimPlacesGateway(
        client: MockClient((request) async {
          expect(request.url.queryParameters['q'], 'Kungsholmen');
          expect(request.headers['User-Agent'], isNotNull);
          return http.Response(
            jsonEncode([
              {'display_name': 'Kungsholmen, Stockholm, Sweden'},
              {'display_name': 'Kungsholmstorg, Stockholm, Sweden'},
            ]),
            200,
          );
        }),
      );

      final results = await gateway.search('Kungsholmen');

      expect(results, [
        const PlaceSuggestion(description: 'Kungsholmen, Stockholm, Sweden'),
        const PlaceSuggestion(description: 'Kungsholmstorg, Stockholm, Sweden'),
      ]);
    });

    test('a non-200 response returns no suggestions', () async {
      final gateway = NominatimPlacesGateway(
        client: MockClient((request) async => http.Response('', 503)),
      );

      expect(await gateway.search('Kungsholmen'), isEmpty);
    });

    test('a network error returns no suggestions', () async {
      final gateway = NominatimPlacesGateway(
        client: MockClient((request) => throw Exception('offline')),
      );

      expect(await gateway.search('Kungsholmen'), isEmpty);
    });
  });
}
