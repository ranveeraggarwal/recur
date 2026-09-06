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

    test('the request carries a real, identifying User-Agent', () async {
      String? userAgent;
      final gateway = NominatimPlacesGateway(
        client: MockClient((request) async {
          userAgent = request.headers['User-Agent'];
          return http.Response('[]', 200);
        }),
      );

      await gateway.search('Kungsholmen');

      expect(userAgent, isNotNull);
      expect(userAgent, contains('github.com/ranveeraggarwal/recur'));
      expect(userAgent, isNot(contains('contact none')));
    });

    test('a second search waits out the remainder of one second since the '
        'first', () async {
      final waited = <Duration>[];
      final gateway = NominatimPlacesGateway(
        client: MockClient((request) async => http.Response('[]', 200)),
        wait: (duration) {
          waited.add(duration);
          return Future.value();
        },
      );

      await gateway.search('Kungsholmen');
      expect(waited, isEmpty);

      await gateway.search('Kungsholmstorg');

      expect(waited, hasLength(1));
      // The two calls above run back to back with no real delay between
      // them, so the wait should be close to the full second, not zero.
      expect(waited.single.inMilliseconds, greaterThan(500));
      expect(
        waited.single.inMilliseconds,
        lessThanOrEqualTo(const Duration(seconds: 1).inMilliseconds),
      );
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
