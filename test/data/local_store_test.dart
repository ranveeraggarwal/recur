import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/local_store.dart';

void main() {
  group('InMemoryLocalStore', () {
    late InMemoryLocalStore store;

    setUp(() {
      store = InMemoryLocalStore();
    });

    test('read returns null when key is missing', () async {
      final result = await store.read('event_types');
      expect(result, isNull);
    });

    test('write then read returns the written value', () async {
      const json = '{"name":"test"}';
      await store.write('event_types', json);
      final result = await store.read('event_types');
      expect(result, json);
    });

    test('overwrite updates the value', () async {
      const json1 = '{"name":"test1"}';
      const json2 = '{"name":"test2"}';
      await store.write('event_types', json1);
      await store.write('event_types', json2);
      final result = await store.read('event_types');
      expect(result, json2);
    });

    test('delete removes the value', () async {
      const json = '{"name":"test"}';
      await store.write('event_types', json);
      await store.delete('event_types');
      final result = await store.read('event_types');
      expect(result, isNull);
    });

    test('delete ignores missing keys', () async {
      await store.delete('nonexistent');
      expect(true, true); // If it gets here without error, it passed
    });

    test('snapshot returns unmodifiable copy of store', () async {
      const json = '{"name":"test"}';
      await store.write('event_types', json);
      final snapshot = store.snapshot;
      expect(snapshot['event_types'], json);
      expect(snapshot, isA<Map<String, String>>());
    });

    test('snapshot is unmodifiable', () async {
      const json = '{"name":"test"}';
      await store.write('event_types', json);
      final snapshot = store.snapshot;
      expect(() => snapshot['new_key'] = 'value', throwsUnsupportedError);
    });

    test('multiple keys can coexist', () async {
      const json1 = '{"name":"event1"}';
      const json2 = '{"name":"event2"}';
      const json3 = '{"name":"settings"}';
      await store.write('event_types', json1);
      await store.write('bookings', json2);
      await store.write('settings', json3);
      expect(await store.read('event_types'), json1);
      expect(await store.read('bookings'), json2);
      expect(await store.read('settings'), json3);
    });
  });
}
