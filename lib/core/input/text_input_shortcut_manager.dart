import 'package:flutter/widgets.dart';

/// A [ShortcutManager] that yields every key to a focused text field.
///
/// App shortcuts include bare letter keys (such as `L` for loop), and a
/// shortcut that handles a key keeps the character from ever reaching the
/// field. While an [EditableText] holds focus, key events pass through
/// unhandled, so the field owns the keyboard. Editing keys still work because
/// `DefaultTextEditingShortcuts` sits below the app shortcuts and handles
/// them first. Shortcuts resume once the field loses focus, which desktop
/// platforms do on a click outside it.
class TextInputAwareShortcutManager extends ShortcutManager {
  TextInputAwareShortcutManager({super.shortcuts});

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (isTextInputFocused) return KeyEventResult.ignored;
    return super.handleKeypress(context, event);
  }

  /// Whether the primary focus belongs to a text input.
  static bool get isTextInputFocused {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null || !focusedContext.mounted) return false;
    return focusedContext.findAncestorStateOfType<EditableTextState>() != null;
  }
}
