import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:karbeat/core/input/input.dart';
import 'package:karbeat/core/input/intents/workspace/export_intent.dart';
import 'package:karbeat/core/input/intents/workspace/save_intent.dart';
import 'package:karbeat/core/input/intents/workspace/action_history_intent.dart';

final workspaceShortcuts = [
  const DawShortcut(
    id: "workspace.save",
    title: "Save Project",
    category: "Workspace",
    intent: SaveIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyS, control: true),
  ),
  const DawShortcut(
    id: "workspace.undo",
    title: "Undo",
    category: "Workspace",
    intent: UndoIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  ),
  const DawShortcut(
    id: "workspace.redo",
    title: "Redo",
    category: "Workspace",
    intent: RedoIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyZ, control: true, alt: true),
  ),
  const DawShortcut(
    id: "workspace.saveAs",
    title: "Save As",
    category: "Workspace",
    intent: SaveAsIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true),
  ),
  const DawShortcut(
    id: "workspace.export",
    title: "Export",
    category: "Workspace",
    intent: ExportIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true),
  ),
];
