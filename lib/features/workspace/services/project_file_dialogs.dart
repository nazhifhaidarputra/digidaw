import 'package:file_picker/file_picker.dart' as picker;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:karbeat/core/l10n/localizer.dart';

/// Native file extension for DigiDAW projects.
const dgdawProjectExtension = 'dgdaw';

/// Extension used by projects saved before the `.dgdaw` format.
const karbeatProjectExtension = 'karbeat';

/// Project save filter. The description is shown by the desktop file dialog.
XTypeGroup get dgdawProjectTypeGroup => XTypeGroup(
  label: tr('workspace-file-type-project'),
  extensions: const <String>[dgdawProjectExtension],
);

/// Legacy project filter, kept so old `.karbeat` projects can still be opened.
XTypeGroup get karbeatProjectTypeGroup => XTypeGroup(
  label: tr('workspace-file-type-karbeat-project'),
  extensions: const <String>[karbeatProjectExtension],
);

/// File extension for mixer channel templates.
const channelTemplateExtension = 'effch';

/// Channel template save filter.
XTypeGroup get channelTemplateTypeGroup => XTypeGroup(
  label: tr('workspace-file-type-channel-template'),
  extensions: const <String>[channelTemplateExtension],
);

List<XTypeGroup> get _projectOpenTypeGroups => [
  dgdawProjectTypeGroup,
  karbeatProjectTypeGroup,
];

/// Desktop file dialogs can show named filter groups. Mobile pickers fall back
/// to `file_picker`, which only supports extension filters.
bool get _usesDesktopTypeLabels {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

/// Whether [path] names a project file this app can open.
bool isSupportedProjectFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.$dgdawProjectExtension') ||
      lower.endsWith('.$karbeatProjectExtension');
}

/// Opens the project chooser, restricted to supported project files and
/// starting in [initialDirectory] when given.
///
/// Returns `null` when the user cancels.
Future<String?> pickProjectFileToOpen({String? initialDirectory}) async {
  if (!_usesDesktopTypeLabels) {
    final result = await picker.FilePicker.pickFiles(
      initialDirectory: initialDirectory,
      type: picker.FileType.custom,
      allowedExtensions: <String>[
        dgdawProjectExtension,
        karbeatProjectExtension,
      ],
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return isSupportedProjectFile(path) ? path : null;
  }

  final file = await openFile(
    acceptedTypeGroups: _projectOpenTypeGroups,
    initialDirectory: initialDirectory,
    confirmButtonText: tr('workspace-file-open'),
  );
  if (file == null) return null;
  final path = file.path;
  return isSupportedProjectFile(path) ? path : null;
}

/// Opens the save chooser, starting in [initialDirectory] when given, and
/// returns a path ending in `.dgdaw`.
///
/// Returns `null` when the user cancels.
Future<String?> pickProjectFileToSave({String? initialDirectory}) async {
  if (!_usesDesktopTypeLabels) {
    final path = await picker.FilePicker.saveFile(
      initialDirectory: initialDirectory,
      fileName: 'untitled.$dgdawProjectExtension',
      type: picker.FileType.custom,
      allowedExtensions: const <String>[dgdawProjectExtension],
    );
    return path == null ? null : withFileExtension(path, dgdawProjectExtension);
  }

  final location = await getSaveLocation(
    acceptedTypeGroups: <XTypeGroup>[dgdawProjectTypeGroup],
    initialDirectory: initialDirectory,
    suggestedName: 'untitled.$dgdawProjectExtension',
    confirmButtonText: tr('common-save'),
  );
  if (location == null) return null;
  return withFileExtension(location.path, dgdawProjectExtension);
}

/// File dialog filter for an audio export format.
XTypeGroup audioExportTypeGroup(String extension) {
  final normalizedExtension = extension.toLowerCase();
  return XTypeGroup(
    label: tr('workspace-file-type-audio', {
      'format': normalizedExtension.toUpperCase(),
      'extension': normalizedExtension,
    }),
    extensions: <String>[normalizedExtension],
  );
}

/// Opens the export save chooser locked to [extension], starting in
/// [initialDirectory] when given, and returns a matching path.
///
/// Returns `null` when the user cancels.
Future<String?> pickAudioExportFileToSave({
  required String fileName,
  required String extension,
  String? initialDirectory,
}) async {
  final normalizedExtension = extension.toLowerCase();
  final suggestedName = withFileExtension(fileName, normalizedExtension);
  if (!_usesDesktopTypeLabels) {
    final path = await picker.FilePicker.saveFile(
      initialDirectory: initialDirectory,
      fileName: suggestedName,
      type: picker.FileType.custom,
      allowedExtensions: <String>[normalizedExtension],
    );
    return path == null ? null : withFileExtension(path, normalizedExtension);
  }

  final location = await getSaveLocation(
    acceptedTypeGroups: <XTypeGroup>[audioExportTypeGroup(normalizedExtension)],
    initialDirectory: initialDirectory,
    suggestedName: suggestedName,
    confirmButtonText: tr('workspace-file-export'),
  );
  if (location == null) return null;
  return withFileExtension(location.path, normalizedExtension);
}

/// Suggested file name for a template of the channel called [channelName].
///
/// Characters that file systems reject in a name are replaced.
String channelTemplateFileName(String channelName) {
  final name = channelName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  return '$name.$channelTemplateExtension';
}

/// Opens the save chooser for a channel template and returns a path ending in
/// `.effch`.
///
/// Returns `null` when the user cancels.
Future<String?> pickChannelTemplateFileToSave(String channelName) async {
  final suggestedName = channelTemplateFileName(channelName);
  if (!_usesDesktopTypeLabels) {
    final path = await picker.FilePicker.saveFile(
      fileName: suggestedName,
      type: picker.FileType.custom,
      allowedExtensions: const <String>[channelTemplateExtension],
    );
    return path == null
        ? null
        : withFileExtension(path, channelTemplateExtension);
  }

  final location = await getSaveLocation(
    acceptedTypeGroups: <XTypeGroup>[channelTemplateTypeGroup],
    suggestedName: suggestedName,
    confirmButtonText: tr('common-save'),
  );
  if (location == null) return null;
  return withFileExtension(location.path, channelTemplateExtension);
}

/// Opens the chooser for a channel template to load.
///
/// Returns `null` when the user cancels.
Future<String?> pickChannelTemplateFileToOpen() async {
  if (!_usesDesktopTypeLabels) {
    final result = await picker.FilePicker.pickFiles(
      type: picker.FileType.custom,
      allowedExtensions: const <String>[channelTemplateExtension],
    );
    return result?.files.single.path;
  }

  final file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[channelTemplateTypeGroup],
    confirmButtonText: tr('workspace-file-open'),
  );
  return file?.path;
}

/// [path] with exactly [extension] as its final extension.
///
/// An existing extension is replaced so a save dialog cannot leave the file
/// with a type the app did not offer.
String withFileExtension(String path, String extension) {
  final normalizedExtension = extension.toLowerCase();
  if (path.toLowerCase().endsWith('.$normalizedExtension')) return path;

  final lastSlash = path.lastIndexOf(RegExp(r'[/\\]'));
  final lastDot = path.lastIndexOf('.');
  if (lastDot > lastSlash + 1) {
    return '${path.substring(0, lastDot)}.$normalizedExtension';
  }
  return '$path.$normalizedExtension';
}
