import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/utils/log_models.dart';
import 'package:karbeat/core/utils/result_type.dart';

class LogExportService {
  Future<Result<String?>> export(IList<AppLogEntry> entries) {
    return attemptAsync(() async {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export DigiDAW logs',
        fileName: 'digidaw.log',
        type: FileType.custom,
        allowedExtensions: const ['log', 'txt'],
      );
      if (path == null) return null;
      await File(path).writeAsString(format(entries));
      return path;
    });
  }

  static String format(Iterable<AppLogEntry> entries) {
    return entries
        .map((entry) {
          final error = entry.errorSummary;
          return '${entry.timestamp.toIso8601String()} '
              '[${entry.level.name.toUpperCase()}] ${entry.message}'
              '${error == null ? '' : ' | $error'}';
        })
        .join('\n');
  }
}

final logExportServiceProvider = Provider<LogExportService>((ref) {
  return LogExportService();
});
