import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:karbeat/core/input/intents/workspace/export_intent.dart';
import 'package:karbeat/core/input/intents/workspace/save_intent.dart';
import 'package:karbeat/core/input/intents/workspace/action_history_intent.dart';
import 'package:karbeat/core/input/shortcut_models.dart';

const workspaceShortcuts = IListConst<DawShortcut>([
  DawShortcut(
    id: "workspace.save",
    title: "Save Project",
    category: "Workspace",
    intent: SaveIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyS, control: true),
  ),
  DawShortcut(
    id: "workspace.undo",
    title: "Undo",
    category: "Workspace",
    intent: UndoIntent(),
    defaultKey: SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  ),
  DawShortcut(
    id: "workspace.redo",
    title: "Redo",
    category: "Workspace",
    intent: RedoIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: true,
      alt: true,
    ),
  ),
  DawShortcut(
    id: "workspace.saveAs",
    title: "Save As",
    category: "Workspace",
    intent: SaveAsIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyS,
      control: true,
      shift: true,
    ),
  ),
  DawShortcut(
    id: "workspace.export",
    title: "Export",
    category: "Workspace",
    intent: ExportIntent(),
    defaultKey: SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      shift: true,
    ),
  ),
]);
