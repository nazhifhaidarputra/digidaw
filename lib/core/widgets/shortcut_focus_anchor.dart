import 'package:flutter/widgets.dart';

/// Holds keyboard focus for a page whose [Actions] serve the app shortcuts.
///
/// Controls such as `DropdownButton` take focus when used and keep it after
/// their menu closes, so Space re-activates the control instead of reaching
/// the shortcut map. Focus that falls back to a route scope, or anywhere else
/// above the page, is just as lost, because key events no longer pass through
/// the page's [Actions].
///
/// Whenever focus settles while this page's route is current, focus left on a
/// control, a route scope, or an ancestor of the page returns to the anchor.
/// Text fields, open popups and dialogs, and [KeyboardFocusRegion]s keep it.
class ShortcutFocusAnchor extends StatefulWidget {
  const ShortcutFocusAnchor({super.key, required this.child});

  final Widget child;

  @override
  State<ShortcutFocusAnchor> createState() => _ShortcutFocusAnchorState();
}

class _ShortcutFocusAnchorState extends State<ShortcutFocusAnchor> {
  final FocusNode _anchor = FocusNode(
    debugLabel: 'ShortcutFocusAnchor',
    skipTraversal: true,
  );
  ModalRoute<Object?>? _route;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_scheduleCheck);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depending on the route also rebuilds this state when navigation lands
    // back on the page, which is when focus is brought home.
    _route = ModalRoute.of(context);
    _scheduleCheck();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleCheck);
    _anchor.dispose();
    super.dispose();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    // Judge focus after the frame, once pushed or popped routes have settled
    // and their scopes have restored a focused child.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _reclaimStrayFocus();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _reclaimStrayFocus() {
    final route = _route;
    if (route != null && !route.isCurrent) return;

    final focused = FocusManager.instance.primaryFocus;
    if (focused == _anchor) return;
    final target = focused == null ? _anchor : _returnTargetFor(focused);
    if (target == null || target == focused) return;
    target.requestFocus();
  }

  /// The node that focus on [focused] belongs to, or null to leave it there.
  FocusNode? _returnTargetFor(FocusNode focused) {
    // Key events starting above the anchor never reach the page's Actions.
    if (_anchor.ancestors.contains(focused)) return _anchor;

    // Overlays above the navigator and other routes manage their own focus.
    // The anchor's enclosing scope is the page route's scope.
    final pageScope = _anchor.enclosingScope;
    if (pageScope == null || !focused.ancestors.contains(pageScope)) {
      return null;
    }

    final focusedContext = focused.context;
    if (focusedContext == null || !focusedContext.mounted) return null;

    // Open menus, dropdowns, and dialogs keep focus until they close.
    final focusedRoute = ModalRoute.of(focusedContext);
    if (focusedRoute is PopupRoute || focusedRoute?.isCurrent == false) {
      return null;
    }
    if (focusedContext.findAncestorStateOfType<EditableTextState>() != null) {
      return null;
    }

    final region = focusedContext
        .findAncestorWidgetOfExactType<KeyboardFocusRegion>();
    if (region != null && region.focusNode.canRequestFocus) {
      return region.focusNode;
    }
    return _anchor;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(focusNode: _anchor, autofocus: true, child: widget.child);
  }
}

/// A [Focus] that is a deliberate keyboard target, such as a playable piano
/// keyboard, so [ShortcutFocusAnchor] leaves focus on it.
///
/// Controls inside the region hand focus back to [focusNode] instead of the
/// anchor once they are done with it. [onKeyEvent] should ignore keys it does
/// not use, so that shortcuts still reach the page.
class KeyboardFocusRegion extends StatelessWidget {
  const KeyboardFocusRegion({
    super.key,
    required this.focusNode,
    this.onKeyEvent,
    this.onFocusChange,
    required this.child,
  });

  final FocusNode focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final ValueChanged<bool>? onFocusChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      onFocusChange: onFocusChange,
      child: child,
    );
  }
}
