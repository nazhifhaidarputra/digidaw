import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/setting/models/project_settings_state.dart';

final projectSettingsProvider = Provider<ProjectSettingsState>((ref) {
  final project = ref.watch(projectProvider);
  return ProjectSettingsState(
    metadata: project.value?.metadata,
    hasProject: project.hasValue,
  );
});
