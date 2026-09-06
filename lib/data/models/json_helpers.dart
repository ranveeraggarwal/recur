/// Small shared helpers for reading the models back out of JSON.
library;

/// Reads [key] from [json] as a [T], throwing a [FormatException] (naming
/// [typeName] and [key]) when the key is missing, null, or the wrong type —
/// never a raw cast error.
T requireJson<T>(Map<String, dynamic> json, String key, String typeName) {
  if (!json.containsKey(key) || json[key] == null) {
    throw FormatException('Missing required key "$key" in $typeName JSON.');
  }
  final value = json[key];
  if (value is! T) {
    throw FormatException('Key "$key" in $typeName JSON has the wrong type.');
  }
  return value;
}
