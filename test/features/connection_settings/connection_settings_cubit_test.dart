import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samantha/features/connection_settings/data/connection_api.dart';
import 'package:samantha/features/connection_settings/data/connection_settings_repository.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_cubit.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_state.dart';

class MockConnectionSettingsRepository extends Mock
    implements ConnectionSettingsRepository {}

class MockConnectionApi extends Mock implements ConnectionApi {}

void main() {
  late MockConnectionSettingsRepository repository;
  late MockConnectionApi api;

  setUp(() {
    repository = MockConnectionSettingsRepository();
    api = MockConnectionApi();
  });

  group('ConnectionSettingsCubit', () {
    blocTest<ConnectionSettingsCubit, ConnectionSettingsState>(
      'emits Loading then Loaded with saved values on load()',
      setUp: () {
        when(() => repository.getHost()).thenAnswer((_) async => '100.1.2.3');
        when(() => repository.getAuthToken()).thenAnswer((_) async => 'secret');
      },
      build: () => ConnectionSettingsCubit(repository, api),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ConnectionSettingsLoading>(),
        isA<ConnectionSettingsLoaded>()
            .having((s) => s.host, 'host', '100.1.2.3')
            .having((s) => s.authToken, 'authToken', 'secret'),
      ],
    );

    blocTest<ConnectionSettingsCubit, ConnectionSettingsState>(
      'emits Loaded with empty values when nothing is saved',
      setUp: () {
        when(() => repository.getHost()).thenAnswer((_) async => null);
        when(() => repository.getAuthToken()).thenAnswer((_) async => null);
      },
      build: () => ConnectionSettingsCubit(repository, api),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ConnectionSettingsLoading>(),
        isA<ConnectionSettingsLoaded>()
            .having((s) => s.host, 'host', '')
            .having((s) => s.authToken, 'authToken', ''),
      ],
    );

    blocTest<ConnectionSettingsCubit, ConnectionSettingsState>(
      'save() persists values and emits Loaded',
      setUp: () {
        when(() => repository.saveHost(any())).thenAnswer((_) async {});
        when(() => repository.saveAuthToken(any())).thenAnswer((_) async {});
      },
      build: () => ConnectionSettingsCubit(repository, api),
      seed: () => ConnectionSettingsLoaded(host: '', authToken: ''),
      act: (cubit) => cubit.save('100.1.2.3', 'secret'),
      expect: () => [
        isA<ConnectionSettingsLoaded>()
            .having((s) => s.host, 'host', '100.1.2.3')
            .having((s) => s.authToken, 'authToken', 'secret'),
      ],
      verify: (_) {
        verify(() => repository.saveHost('100.1.2.3')).called(1);
        verify(() => repository.saveAuthToken('secret')).called(1);
      },
    );

    blocTest<ConnectionSettingsCubit, ConnectionSettingsState>(
      'testConnection() emits Testing then TestSuccess on health check OK',
      setUp: () {
        when(() => api.checkHealth('100.1.2.3'))
            .thenAnswer((_) async => true);
      },
      build: () => ConnectionSettingsCubit(repository, api),
      seed: () => ConnectionSettingsLoaded(host: '100.1.2.3', authToken: 's'),
      act: (cubit) => cubit.testConnection('100.1.2.3'),
      expect: () => [
        isA<ConnectionSettingsTesting>()
            .having((s) => s.host, 'host', '100.1.2.3'),
        isA<ConnectionSettingsTestSuccess>()
            .having((s) => s.host, 'host', '100.1.2.3'),
      ],
    );

    blocTest<ConnectionSettingsCubit, ConnectionSettingsState>(
      'testConnection() emits Testing then TestFailure on health check error',
      setUp: () {
        when(() => api.checkHealth('fail.host'))
            .thenThrow(Exception('Connection refused'));
      },
      build: () => ConnectionSettingsCubit(repository, api),
      seed: () => ConnectionSettingsLoaded(host: 'fail.host', authToken: 's'),
      act: (cubit) => cubit.testConnection('fail.host'),
      expect: () => [
        isA<ConnectionSettingsTesting>(),
        isA<ConnectionSettingsTestFailure>()
            .having((s) => s.message, 'message', contains('Connection refused')),
      ],
    );
  });
}
