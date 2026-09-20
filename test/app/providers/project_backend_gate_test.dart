import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/backend_operation_gate.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/services/serializer_service.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _ProjectNotifier extends ProjectNotifier {
  final DawContext context = _MockDawContext();

  @override
  DawContext get dawContext => context;

  @override
  Future<ApplicationDataStore> build() =>
      Completer<ApplicationDataStore>().future;
}

class _SerializerService extends SerializerService {
  final saveCompleter = Completer<void>();

  @override
  Future<void> saveProject({
    required DawContext ctx,
    required String pathName,
  }) {
    return saveCompleter.future;
  }
}

void main() {
  test('project save holds the backend gate until Rust completes', () async {
    final serializer = _SerializerService();
    final container = ProviderContainer.test(
      overrides: [
        projectProvider.overrideWith(_ProjectNotifier.new),
        serializerServiceProvider.overrideWithValue(serializer),
      ],
    );
    final project = container.read(projectProvider.notifier);

    final saving = project.saveProject('/tmp/project.dgdaw');
    expect(container.read(backendOperationGateProvider), 1);

    serializer.saveCompleter.complete();
    await saving;
    expect(container.read(backendOperationGateProvider), 0);
  });
}
