import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/export_project_state.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';

class _GeneralSettings extends GeneralSettingsNotifier {
  _GeneralSettings(this.initial);

  final GeneralSettingsState initial;

  @override
  GeneralSettingsState build() => initial;
}

ProviderContainer _container(GeneralSettingsState general) {
  final container = ProviderContainer(
    overrides: [
      generalSettingsProvider.overrideWith(() => _GeneralSettings(general)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('exports go to the default folder until another is picked', () {
    final container = _container(
      const GeneralSettingsState(defaultExportFolder: '/exports'),
    );

    expect(container.read(exportDirectoryProvider), '/exports');

    container
        .read(exportProjectProvider.notifier)
        .updateExportDirectory('/picked');
    expect(container.read(exportDirectoryProvider), '/picked');
  });

  test('a default folder that no longer exists is not used', () {
    final container = _container(
      GeneralSettingsState(
        defaultExportFolder: '/gone',
        missingFolders: ISet(const {DefaultFolder.export}),
      ),
    );

    expect(container.read(exportDirectoryProvider), isNull);
  });
}
