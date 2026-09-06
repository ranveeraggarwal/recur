/// The real [PlacesGateway], backed by OpenStreetMap's Nominatim search API.
///
/// Nominatim is free and needs no API key, unlike Google Places or Mapbox.
/// Its usage policy (https://operations.osmfoundation.org/policies/nominatim/)
/// asks for a descriptive `User-Agent` and at most one request per second.
/// This gateway enforces both itself - the `User-Agent` identifies the real
/// repository, and [search] waits out any remainder of that second before
/// sending - rather than relying on `LocationAutocompleteField`'s debounce,
/// which only slows typing and is not enforced for every caller. This is the
/// only file in the app that talks to Nominatim. See `docs/architecture.md`,
/// section "Places gateway".
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'places_gateway.dart';

/// The app version sent in the `User-Agent`, kept in sync with the
/// `version:` line in `pubspec.yaml` by hand.
const String _appVersion = '1.0.0';

/// Identifies this app and gives Nominatim a way to reach its operator, per
/// https://operations.osmfoundation.org/policies/nominatim/.
const String _userAgent =
    'Recur/$_appVersion (+https://github.com/ranveeraggarwal/recur)';

/// The minimum gap the Nominatim usage policy allows between requests.
const Duration _minRequestGap = Duration(seconds: 1);

class NominatimPlacesGateway implements PlacesGateway {
  NominatimPlacesGateway({http.Client? client, this.wait = Future.delayed})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Delays the next request until the rate limit allows it. Injectable so
  /// tests can assert on the requested delay without actually sleeping.
  final Future<void> Function(Duration) wait;

  DateTime? _lastRequestAt;

  static final Uri _searchUrl = Uri.parse(
    'https://nominatim.openstreetmap.org/search',
  );

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = _searchUrl.replace(
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'addressdetails': '0',
        'limit': '5',
      },
    );

    try {
      final lastRequestAt = _lastRequestAt;
      if (lastRequestAt != null) {
        final elapsed = DateTime.now().difference(lastRequestAt);
        if (elapsed < _minRequestGap) {
          await wait(_minRequestGap - elapsed);
        }
      }
      _lastRequestAt = DateTime.now();

      final response = await _client.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return [];

      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic> && entry['display_name'] is String)
            PlaceSuggestion(description: entry['display_name'] as String),
      ];
    } catch (_) {
      // A failed lookup just means no suggestions; the field still works as
      // a plain text field.
      return [];
    }
  }
}
