import 'package:karbeat/src/rust/api/serialization.dart' as serialization_api;
import 'package:karbeat/src/rust/api/project.dart';

class SerializerService {
  Future<void> saveProject({required DawContext ctx, required String pathName}) async {
    await serialization_api.saveProject(ctx: ctx, pathName: pathName);
  }

  Future<UiApplicationState> loadProject({required DawContext ctx, required String pathName}) async {
    final uiState = await serialization_api.loadProject(ctx: ctx, pathName: pathName);
    return uiState;
  }
}