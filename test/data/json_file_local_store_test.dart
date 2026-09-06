import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/json_file_local_store.dart';

void main() {
  group('JsonFileLocalStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recur_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('read returns null when file is missing', () async {
      final store = JsonFileLocalStore(tempDir);
      final result = await store.read('event_types');
      expect(result, isNull);
    });

    test('write then read returns the written value', () async {
      final store = JsonFileLocalStore(tempDir);
      const json = '{"name":"test"}';
      await store.write('event_types', json);
      final result = await store.read('event_types');
      expect(result, json);
    });

    test('overwrite updates the value', () async {
      final store = JsonFileLocalStore(tempDir);
      const json1 = '{"name":"test1"}';
      const json2 = '{"name":"test2"}';
      await store.write('event_types', json1);
      await store.write('event_types', json2);
      final result = await store.read('event_types');
      expect(result, json2);
    });

    test('delete removes the file', () async {
      final store = JsonFileLocalStore(tempDir);
      const json = '{"name":"test"}';
      await store.write('event_types', json);
      await store.delete('event_types');
      final result = await store.read('event_types');
      expect(result, isNull);
    });

    test('delete ignores missing files', () async {
      final store = JsonFileLocalStore(tempDir);
      await store.delete('nonexistent');
      expect(true, true); // If it gets here without error, it passed
    });

    test('no .tmp file remains after write', () async {
      final store = JsonFileLocalStore(tempDir);
      const json = '{"name":"test"}';
      await store.write('event_types', json);

      final tmpFile = File('${tempDir.path}/event_types.json.tmp');
      final exists = await tmpFile.exists();
      expect(exists, false);
    });

    test('writing the same key twice leaves exactly one file with the second '
        'content', () async {
      final store = JsonFileLocalStore(tempDir);
      const json1 = '{"name":"test1"}';
      const json2 = '{"name":"test2"}';
      await store.write('event_types', json1);
      await store.write('event_types', json2);

      final entries = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('event_types'))
          .toList();
      expect(entries, hasLength(1));
      expect(await store.read('event_types'), json2);
    });

    test(
      'a second store on the same directory reads what the first wrote',
      () async {
        final store1 = JsonFileLocalStore(tempDir);
        const json = '{"name":"test"}';
        await store1.write('event_types', json);

        final store2 = JsonFileLocalStore(tempDir);
        final result = await store2.read('event_types');
        expect(result, json);
      },
    );

    test('creates root directory recursively if needed', () async {
      final nestedDir = Directory('${tempDir.path}/nested/path');
      expect(await nestedDir.exists(), false);

      final store = JsonFileLocalStore(nestedDir);
      const json = '{"name":"test"}';
      await store.write('event_types', json);

      expect(await nestedDir.exists(), true);
      expect(await store.read('event_types'), json);
    });

    test('invalid key throws ArgumentError', () async {
      final store = JsonFileLocalStore(tempDir);
      expect(
        () => store.write('INVALID_KEY', '{}'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => store.write('key-with-dash', '{}'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => store.write('key with space', '{}'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('valid keys match ^[a-z_]+\$', () async {
      final store = JsonFileLocalStore(tempDir);
      const json = '{"name":"test"}';

      // These should work
      await store.write('event_types', json);
      await store.write('bookings', json);
      await store.write('settings', json);
      await store.write('test_key', json);
      await store.write('_underscore', json);

      expect(await store.read('event_types'), json);
      expect(await store.read('bookings'), json);
      expect(await store.read('settings'), json);
      expect(await store.read('test_key'), json);
      expect(await store.read('_underscore'), json);
    });

    test('multiple keys can coexist in same directory', () async {
      final store = JsonFileLocalStore(tempDir);
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
