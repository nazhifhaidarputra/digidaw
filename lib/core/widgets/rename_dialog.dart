import 'package:flutter/material.dart';

/// Asks for a new name and resolves with it trimmed, or null when cancelled,
/// left empty, or unchanged from [currentName].
Future<String?> showRenameDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String currentName,
}) async {
  var pendingName = currentName;
  final newName = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: currentName,
        autofocus: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => pendingName = value,
        onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, pendingName),
          child: const Text("Rename"),
        ),
      ],
    ),
  );

  final trimmed = newName?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == currentName) {
    return null;
  }
  return trimmed;
}
