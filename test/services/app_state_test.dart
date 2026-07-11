import 'dart:io';

import 'package:simutil/services/app_state.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late String statePath;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('simutil_app_state_');
    statePath = '${dir.path}/nested/state.json';
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  AppStateServiceImpl service() =>
      AppStateServiceImpl(stateFilePath: statePath);

  test('load returns default state when the file is missing', () async {
    final state = await service().load();

    expect(state.lastSeenVersion, isNull);
  });

  test('save then load round-trips lastSeenVersion', () async {
    await service().save(const AppState(lastSeenVersion: '0.6.1'));

    final state = await service().load();

    expect(state.lastSeenVersion, '0.6.1');
  });

  test('update applies the updater and persists the result', () async {
    await service().save(const AppState(lastSeenVersion: '0.6.0'));

    final updated = await service().update(
      (state) => state.copyWith(lastSeenVersion: '0.6.2'),
    );

    expect(updated.lastSeenVersion, '0.6.2');
    expect((await service().load()).lastSeenVersion, '0.6.2');
  });

  test(
    'load returns default state when the file contains invalid JSON',
    () async {
      File(statePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('{not valid json');

      final state = await service().load();

      expect(state.lastSeenVersion, isNull);
    },
  );
}
