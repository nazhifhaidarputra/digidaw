import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'browser_panel_state.freezed.dart';

@freezed
abstract class BrowserSample with _$BrowserSample {
  const factory BrowserSample({required String name, required String path}) =
      _BrowserSample;
}

@freezed
abstract class FileTree with _$FileTree {
  const factory FileTree({
    required String name,
    required String path,
    @Default(IListConst<FileTree>([])) IList<FileTree> directories,
    @Default(IListConst<BrowserSample>([])) IList<BrowserSample> samples,
  }) = _FileTree;
}

@freezed
abstract class BrowserPanelState with _$BrowserPanelState {
  const factory BrowserPanelState({
    @Default(false) bool isExpanded,
    @Default(false) bool isLoadingDirectory,
    @Default(IMapConst<String, FileTree>({}))
    IMap<String, FileTree> directories,
    @Default(ISetConst<String>({})) ISet<String> expandedDirectoryPaths,
    String? selectedSamplePath,
  }) = _BrowserPanelState;
}
