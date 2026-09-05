/// The one door to an address/place lookup.
///
/// Nothing in the app talks to a places API directly. Everything goes
/// through [PlacesGateway]. Only the file that implements this interface
/// against a real service knows that service exists; every screen and every
/// test uses `FakePlacesGateway`. See `docs/architecture.md`, section
/// "Places gateway".
library;

/// One address suggestion, as shown in an autocomplete list.
final class PlaceSuggestion {
  const PlaceSuggestion({required this.description});

  /// The full, human-readable address, ready to store as-is.
  final String description;

  @override
  bool operator ==(Object other) =>
      other is PlaceSuggestion && other.description == description;

  @override
  int get hashCode => description.hashCode;

  @override
  String toString() => 'PlaceSuggestion(description: $description)';
}

/// The boundary the app talks to instead of a places/geocoding API directly.
abstract interface class PlacesGateway {
  /// Address suggestions matching [query], best match first. Returns an
  /// empty list for a blank query or when the lookup fails; this is an
  /// autocomplete convenience, not something the rest of the app depends on.
  Future<List<PlaceSuggestion>> search(String query);
}
