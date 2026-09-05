/// The real [PlacesGateway], backed by OpenStreetMap's Nominatim search API.
///
/// Nominatim is free and needs no API key, unlike Google Places or Mapbox.
/// Its usage policy (https://operations.osmfoundation.org/policies/nominatim/)
/// asks for a descriptive `User-Agent` and at most ~1 request/second, which
/// the debounce in `LocationAutocompleteField` respects. This is the only
/// file in the app that talks to Nominatim. See `docs/architecture.md`,
/// section "Places gateway".
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'places_gateway.dart';

class NominatimPlacesGateway implements PlacesGateway {
  NominatimPlacesGateway({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

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
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'Recur (github.com/recur; contact none)'},
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
