import 'package:file_picker/file_picker.dart' as picker;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// Native file extension for DigiDAW projects.
const dgdawProjectExtension = 'dgdaw';

/// Extension used by projects saved before the `.dgdaw` format.
const karbeatProjectExtension = 'karbeat';

/// Project save filter. The description is shown by the desktop file dialog.
const dgdawProjectTypeGroup = XTypeGroup(
  label: 'Digidaw Project (.dgdaw)',
  extensions: <String>[dgdawProjectExtension],
);

/// Legacy project filter, kept so old `.karbeat` projects can still be opened.
const karbeatProjectTypeGroup = XTypeGroup(
  label: 'Karbeat Project (.karbeat)',
  extensions: <String>[karbeatProjectExtension],
);

const _projectOpenTypeGroups = <XTypeGroup>[
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

/// Opens the project chooser, restricted to supported project files.
///
/// Returns `null` when the user cancels.
Future<String?> pickProjectFileToOpen() async {
  if (!_usesDesktopTypeLabels) {
    final result = await picker.FilePicker.pickFiles(
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
    confirmButtonText: 'Open',
  );
  if (file == null) return null;
  final path = file.path;
  return isSupportedProjectFile(path) ? path : null;
}

/// Opens the save chooser and returns a path ending in `.dgdaw`.
///
/// Returns `null` when the user cancels.
Future<String?> pickProjectFileToSave() async {
  if (!_usesDesktopTypeLabels) {
    final path = await picker.FilePicker.saveFile(
      fileName: 'untitled.$dgdawProjectExtension',
      type: picker.FileType.custom,
      allowedExtensions: const <String>[dgdawProjectExtension],
    );
    return path == null ? null : withFileExtension(path, dgdawProjectExtension);
  }

  final location = await getSaveLocation(
    acceptedTypeGroups: const <XTypeGroup>[dgdawProjectTypeGroup],
    suggestedName: 'untitled.$dgdawProjectExtension',
    confirmButtonText: 'Save',
  );
  if (location == null) return null;
  return withFileExtension(location.path, dgdawProjectExtension);
}

/// File dialog filter for an audio export format.
XTypeGroup audioExportTypeGroup(String extension) {
  final normalizedExtension = extension.toLowerCase();
  return XTypeGroup(
    label:
        '${normalizedExtension.toUpperCase()} Audio '
        '(.$normalizedExtension)',
    extensions: <String>[normalizedExtension],
  );
}

/// Opens the export save chooser locked to [extension] and returns a matching
/// path.
///
/// Returns `null` when the user cancels.
Future<String?> pickAudioExportFileToSave({
  required String fileName,
  required String extension,
}) async {
  final normalizedExtension = extension.toLowerCase();
  final suggestedName = withFileExtension(fileName, normalizedExtension);
  if (!_usesDesktopTypeLabels) {
    final path = await picker.FilePicker.saveFile(
      fileName: suggestedName,
      type: picker.FileType.custom,
      allowedExtensions: <String>[normalizedExtension],
    );
    return path == null ? null : withFileExtension(path, normalizedExtension);
  }

  final location = await getSaveLocation(
    acceptedTypeGroups: <XTypeGroup>[audioExportTypeGroup(normalizedExtension)],
    suggestedName: suggestedName,
    confirmButtonText: 'Export',
  );
  if (location == null) return null;
  return withFileExtension(location.path, normalizedExtension);
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
