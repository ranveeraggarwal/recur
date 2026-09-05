/// An in-memory [PlacesGateway], for every screen and every test.
///
/// See `docs/architecture.md`, section "Places gateway".
library;

import 'places_gateway.dart';

/// A plain, mutable [PlacesGateway] that lives in memory.
///
/// Tests seed [results] with the suggestions the next call to [search]
/// should return, and can inspect [queries] to see what was searched for.
class FakePlacesGateway implements PlacesGateway {
  List<PlaceSuggestion> results = [];

  /// Every query [search] was called with, in order.
  final List<String> queries = [];

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    queries.add(query);
    return List.of(results);
  }
}
