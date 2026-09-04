import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/local_store.dart';
import 'package:recur/data/models/app_settings.dart';
import 'package:recur/data/settings_repository.dart';

void main() {
  group('LocalSettingsRepository', () {
    late InMemoryLocalStore store;
    late LocalSettingsRepository repository;

    setUp(() {
      store = InMemoryLocalStore();
      repository = LocalSettingsRepository(store);
    });

    test('get returns AppSettings.empty when the store is empty', () async {
      expect(await repository.get(), AppSettings.empty);
    });

    test('save then get returns the saved settings', () async {
      const settings = AppSettings(selectedCalendarId: 'cal1');
      await repository.save(settings);

      expect(await repository.get(), settings);
    });

    test('save overwrites the previous settings', () async {
      await repository.save(const AppSettings(selectedCalendarId: 'cal1'));
      await repository.save(const AppSettings(selectedCalendarId: 'cal2'));

      expect(
        await repository.get(),
        const AppSettings(selectedCalendarId: 'cal2'),
      );
    });

    test(
      'data survives a second repository instance on the same store',
      () async {
        const settings = AppSettings(selectedCalendarId: 'cal1');
        await repository.save(settings);

        final second = LocalSettingsRepository(store);
        expect(await second.get(), settings);
      },
    );

    test('a malformed document throws FormatException', () async {
      await store.write('settings', 'not json');

      expect(() => repository.get(), throwsA(isA<FormatException>()));
    });

    test(
      'a document that is not a JSON object throws FormatException',
      () async {
        await store.write('settings', '[1,2,3]');

        expect(() => repository.get(), throwsA(isA<FormatException>()));
      },
    );
  });
}
