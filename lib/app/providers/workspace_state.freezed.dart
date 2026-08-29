// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FloatingMidiKeyboardFieldState {

 int? get selectedGeneratorId; int get baseKey; int get keyRange; bool get showed;
/// Create a copy of FloatingMidiKeyboardFieldState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FloatingMidiKeyboardFieldStateCopyWith<FloatingMidiKeyboardFieldState> get copyWith => _$FloatingMidiKeyboardFieldStateCopyWithImpl<FloatingMidiKeyboardFieldState>(this as FloatingMidiKeyboardFieldState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FloatingMidiKeyboardFieldState&&(identical(other.selectedGeneratorId, selectedGeneratorId) || other.selectedGeneratorId == selectedGeneratorId)&&(identical(other.baseKey, baseKey) || other.baseKey == baseKey)&&(identical(other.keyRange, keyRange) || other.keyRange == keyRange)&&(identical(other.showed, showed) || other.showed == showed));
}


@override
int get hashCode => Object.hash(runtimeType,selectedGeneratorId,baseKey,keyRange,showed);

@override
String toString() {
  return 'FloatingMidiKeyboardFieldState(selectedGeneratorId: $selectedGeneratorId, baseKey: $baseKey, keyRange: $keyRange, showed: $showed)';
}


}

/// @nodoc
abstract mixin class $FloatingMidiKeyboardFieldStateCopyWith<$Res>  {
  factory $FloatingMidiKeyboardFieldStateCopyWith(FloatingMidiKeyboardFieldState value, $Res Function(FloatingMidiKeyboardFieldState) _then) = _$FloatingMidiKeyboardFieldStateCopyWithImpl;
@useResult
$Res call({
 int? selectedGeneratorId, int baseKey, int keyRange, bool showed
});




}
/// @nodoc
class _$FloatingMidiKeyboardFieldStateCopyWithImpl<$Res>
    implements $FloatingMidiKeyboardFieldStateCopyWith<$Res> {
  _$FloatingMidiKeyboardFieldStateCopyWithImpl(this._self, this._then);

  final FloatingMidiKeyboardFieldState _self;
  final $Res Function(FloatingMidiKeyboardFieldState) _then;

/// Create a copy of FloatingMidiKeyboardFieldState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedGeneratorId = freezed,Object? baseKey = null,Object? keyRange = null,Object? showed = null,}) {
  return _then(_self.copyWith(
selectedGeneratorId: freezed == selectedGeneratorId ? _self.selectedGeneratorId : selectedGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,baseKey: null == baseKey ? _self.baseKey : baseKey // ignore: cast_nullable_to_non_nullable
as int,keyRange: null == keyRange ? _self.keyRange : keyRange // ignore: cast_nullable_to_non_nullable
as int,showed: null == showed ? _self.showed : showed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FloatingMidiKeyboardFieldState].
extension FloatingMidiKeyboardFieldStatePatterns on FloatingMidiKeyboardFieldState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FloatingMidiKeyboardFieldState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FloatingMidiKeyboardFieldState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FloatingMidiKeyboardFieldState value)  $default,){
final _that = this;
switch (_that) {
case _FloatingMidiKeyboardFieldState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FloatingMidiKeyboardFieldState value)?  $default,){
final _that = this;
switch (_that) {
case _FloatingMidiKeyboardFieldState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? selectedGeneratorId,  int baseKey,  int keyRange,  bool showed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FloatingMidiKeyboardFieldState() when $default != null:
return $default(_that.selectedGeneratorId,_that.baseKey,_that.keyRange,_that.showed);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? selectedGeneratorId,  int baseKey,  int keyRange,  bool showed)  $default,) {final _that = this;
switch (_that) {
case _FloatingMidiKeyboardFieldState():
return $default(_that.selectedGeneratorId,_that.baseKey,_that.keyRange,_that.showed);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? selectedGeneratorId,  int baseKey,  int keyRange,  bool showed)?  $default,) {final _that = this;
switch (_that) {
case _FloatingMidiKeyboardFieldState() when $default != null:
return $default(_that.selectedGeneratorId,_that.baseKey,_that.keyRange,_that.showed);case _:
  return null;

}
}

}

/// @nodoc


class _FloatingMidiKeyboardFieldState extends FloatingMidiKeyboardFieldState {
  const _FloatingMidiKeyboardFieldState({this.selectedGeneratorId, this.baseKey = 48, this.keyRange = 15, this.showed = false}): super._();
  

@override final  int? selectedGeneratorId;
@override@JsonKey() final  int baseKey;
@override@JsonKey() final  int keyRange;
@override@JsonKey() final  bool showed;

/// Create a copy of FloatingMidiKeyboardFieldState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FloatingMidiKeyboardFieldStateCopyWith<_FloatingMidiKeyboardFieldState> get copyWith => __$FloatingMidiKeyboardFieldStateCopyWithImpl<_FloatingMidiKeyboardFieldState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FloatingMidiKeyboardFieldState&&(identical(other.selectedGeneratorId, selectedGeneratorId) || other.selectedGeneratorId == selectedGeneratorId)&&(identical(other.baseKey, baseKey) || other.baseKey == baseKey)&&(identical(other.keyRange, keyRange) || other.keyRange == keyRange)&&(identical(other.showed, showed) || other.showed == showed));
}


@override
int get hashCode => Object.hash(runtimeType,selectedGeneratorId,baseKey,keyRange,showed);

@override
String toString() {
  return 'FloatingMidiKeyboardFieldState(selectedGeneratorId: $selectedGeneratorId, baseKey: $baseKey, keyRange: $keyRange, showed: $showed)';
}


}

/// @nodoc
abstract mixin class _$FloatingMidiKeyboardFieldStateCopyWith<$Res> implements $FloatingMidiKeyboardFieldStateCopyWith<$Res> {
  factory _$FloatingMidiKeyboardFieldStateCopyWith(_FloatingMidiKeyboardFieldState value, $Res Function(_FloatingMidiKeyboardFieldState) _then) = __$FloatingMidiKeyboardFieldStateCopyWithImpl;
@override @useResult
$Res call({
 int? selectedGeneratorId, int baseKey, int keyRange, bool showed
});




}
/// @nodoc
class __$FloatingMidiKeyboardFieldStateCopyWithImpl<$Res>
    implements _$FloatingMidiKeyboardFieldStateCopyWith<$Res> {
  __$FloatingMidiKeyboardFieldStateCopyWithImpl(this._self, this._then);

  final _FloatingMidiKeyboardFieldState _self;
  final $Res Function(_FloatingMidiKeyboardFieldState) _then;

/// Create a copy of FloatingMidiKeyboardFieldState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedGeneratorId = freezed,Object? baseKey = null,Object? keyRange = null,Object? showed = null,}) {
  return _then(_FloatingMidiKeyboardFieldState(
selectedGeneratorId: freezed == selectedGeneratorId ? _self.selectedGeneratorId : selectedGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,baseKey: null == baseKey ? _self.baseKey : baseKey // ignore: cast_nullable_to_non_nullable
as int,keyRange: null == keyRange ? _self.keyRange : keyRange // ignore: cast_nullable_to_non_nullable
as int,showed: null == showed ? _self.showed : showed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$WorkspaceState {

 WorkspaceView get currentView; ToolSelection get selectedTool; ToolbarMenuContextGroup get currentToolbarContext; InteractionTarget? get interactionTarget; int? get editingPatternId; double get horizontalZoomLevel; MusicalBeatSize get horizontalClipShiftSizeDenom; GridSize get gridSize; bool get snapToGrid; bool get showExportPanel; BrowserPanelState get browserPanelState; FloatingMidiKeyboardFieldState get floatingMidiKeyboardState;
/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceStateCopyWith<WorkspaceState> get copyWith => _$WorkspaceStateCopyWithImpl<WorkspaceState>(this as WorkspaceState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceState&&(identical(other.currentView, currentView) || other.currentView == currentView)&&(identical(other.selectedTool, selectedTool) || other.selectedTool == selectedTool)&&(identical(other.currentToolbarContext, currentToolbarContext) || other.currentToolbarContext == currentToolbarContext)&&(identical(other.interactionTarget, interactionTarget) || other.interactionTarget == interactionTarget)&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.horizontalZoomLevel, horizontalZoomLevel) || other.horizontalZoomLevel == horizontalZoomLevel)&&(identical(other.horizontalClipShiftSizeDenom, horizontalClipShiftSizeDenom) || other.horizontalClipShiftSizeDenom == horizontalClipShiftSizeDenom)&&(identical(other.gridSize, gridSize) || other.gridSize == gridSize)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&(identical(other.showExportPanel, showExportPanel) || other.showExportPanel == showExportPanel)&&(identical(other.browserPanelState, browserPanelState) || other.browserPanelState == browserPanelState)&&(identical(other.floatingMidiKeyboardState, floatingMidiKeyboardState) || other.floatingMidiKeyboardState == floatingMidiKeyboardState));
}


@override
int get hashCode => Object.hash(runtimeType,currentView,selectedTool,currentToolbarContext,interactionTarget,editingPatternId,horizontalZoomLevel,horizontalClipShiftSizeDenom,gridSize,snapToGrid,showExportPanel,browserPanelState,floatingMidiKeyboardState);

@override
String toString() {
  return 'WorkspaceState(currentView: $currentView, selectedTool: $selectedTool, currentToolbarContext: $currentToolbarContext, interactionTarget: $interactionTarget, editingPatternId: $editingPatternId, horizontalZoomLevel: $horizontalZoomLevel, horizontalClipShiftSizeDenom: $horizontalClipShiftSizeDenom, gridSize: $gridSize, snapToGrid: $snapToGrid, showExportPanel: $showExportPanel, browserPanelState: $browserPanelState, floatingMidiKeyboardState: $floatingMidiKeyboardState)';
}


}

/// @nodoc
abstract mixin class $WorkspaceStateCopyWith<$Res>  {
  factory $WorkspaceStateCopyWith(WorkspaceState value, $Res Function(WorkspaceState) _then) = _$WorkspaceStateCopyWithImpl;
@useResult
$Res call({
 WorkspaceView currentView, ToolSelection selectedTool, ToolbarMenuContextGroup currentToolbarContext, InteractionTarget? interactionTarget, int? editingPatternId, double horizontalZoomLevel, MusicalBeatSize horizontalClipShiftSizeDenom, GridSize gridSize, bool snapToGrid, bool showExportPanel, BrowserPanelState browserPanelState, FloatingMidiKeyboardFieldState floatingMidiKeyboardState
});


$BrowserPanelStateCopyWith<$Res> get browserPanelState;$FloatingMidiKeyboardFieldStateCopyWith<$Res> get floatingMidiKeyboardState;

}
/// @nodoc
class _$WorkspaceStateCopyWithImpl<$Res>
    implements $WorkspaceStateCopyWith<$Res> {
  _$WorkspaceStateCopyWithImpl(this._self, this._then);

  final WorkspaceState _self;
  final $Res Function(WorkspaceState) _then;

/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentView = null,Object? selectedTool = null,Object? currentToolbarContext = null,Object? interactionTarget = freezed,Object? editingPatternId = freezed,Object? horizontalZoomLevel = null,Object? horizontalClipShiftSizeDenom = null,Object? gridSize = null,Object? snapToGrid = null,Object? showExportPanel = null,Object? browserPanelState = null,Object? floatingMidiKeyboardState = null,}) {
  return _then(_self.copyWith(
currentView: null == currentView ? _self.currentView : currentView // ignore: cast_nullable_to_non_nullable
as WorkspaceView,selectedTool: null == selectedTool ? _self.selectedTool : selectedTool // ignore: cast_nullable_to_non_nullable
as ToolSelection,currentToolbarContext: null == currentToolbarContext ? _self.currentToolbarContext : currentToolbarContext // ignore: cast_nullable_to_non_nullable
as ToolbarMenuContextGroup,interactionTarget: freezed == interactionTarget ? _self.interactionTarget : interactionTarget // ignore: cast_nullable_to_non_nullable
as InteractionTarget?,editingPatternId: freezed == editingPatternId ? _self.editingPatternId : editingPatternId // ignore: cast_nullable_to_non_nullable
as int?,horizontalZoomLevel: null == horizontalZoomLevel ? _self.horizontalZoomLevel : horizontalZoomLevel // ignore: cast_nullable_to_non_nullable
as double,horizontalClipShiftSizeDenom: null == horizontalClipShiftSizeDenom ? _self.horizontalClipShiftSizeDenom : horizontalClipShiftSizeDenom // ignore: cast_nullable_to_non_nullable
as MusicalBeatSize,gridSize: null == gridSize ? _self.gridSize : gridSize // ignore: cast_nullable_to_non_nullable
as GridSize,snapToGrid: null == snapToGrid ? _self.snapToGrid : snapToGrid // ignore: cast_nullable_to_non_nullable
as bool,showExportPanel: null == showExportPanel ? _self.showExportPanel : showExportPanel // ignore: cast_nullable_to_non_nullable
as bool,browserPanelState: null == browserPanelState ? _self.browserPanelState : browserPanelState // ignore: cast_nullable_to_non_nullable
as BrowserPanelState,floatingMidiKeyboardState: null == floatingMidiKeyboardState ? _self.floatingMidiKeyboardState : floatingMidiKeyboardState // ignore: cast_nullable_to_non_nullable
as FloatingMidiKeyboardFieldState,
  ));
}
/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BrowserPanelStateCopyWith<$Res> get browserPanelState {
  
  return $BrowserPanelStateCopyWith<$Res>(_self.browserPanelState, (value) {
    return _then(_self.copyWith(browserPanelState: value));
  });
}/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FloatingMidiKeyboardFieldStateCopyWith<$Res> get floatingMidiKeyboardState {
  
  return $FloatingMidiKeyboardFieldStateCopyWith<$Res>(_self.floatingMidiKeyboardState, (value) {
    return _then(_self.copyWith(floatingMidiKeyboardState: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkspaceState].
extension WorkspaceStatePatterns on WorkspaceState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceState value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceState value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkspaceView currentView,  ToolSelection selectedTool,  ToolbarMenuContextGroup currentToolbarContext,  InteractionTarget? interactionTarget,  int? editingPatternId,  double horizontalZoomLevel,  MusicalBeatSize horizontalClipShiftSizeDenom,  GridSize gridSize,  bool snapToGrid,  bool showExportPanel,  BrowserPanelState browserPanelState,  FloatingMidiKeyboardFieldState floatingMidiKeyboardState)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceState() when $default != null:
return $default(_that.currentView,_that.selectedTool,_that.currentToolbarContext,_that.interactionTarget,_that.editingPatternId,_that.horizontalZoomLevel,_that.horizontalClipShiftSizeDenom,_that.gridSize,_that.snapToGrid,_that.showExportPanel,_that.browserPanelState,_that.floatingMidiKeyboardState);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkspaceView currentView,  ToolSelection selectedTool,  ToolbarMenuContextGroup currentToolbarContext,  InteractionTarget? interactionTarget,  int? editingPatternId,  double horizontalZoomLevel,  MusicalBeatSize horizontalClipShiftSizeDenom,  GridSize gridSize,  bool snapToGrid,  bool showExportPanel,  BrowserPanelState browserPanelState,  FloatingMidiKeyboardFieldState floatingMidiKeyboardState)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceState():
return $default(_that.currentView,_that.selectedTool,_that.currentToolbarContext,_that.interactionTarget,_that.editingPatternId,_that.horizontalZoomLevel,_that.horizontalClipShiftSizeDenom,_that.gridSize,_that.snapToGrid,_that.showExportPanel,_that.browserPanelState,_that.floatingMidiKeyboardState);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkspaceView currentView,  ToolSelection selectedTool,  ToolbarMenuContextGroup currentToolbarContext,  InteractionTarget? interactionTarget,  int? editingPatternId,  double horizontalZoomLevel,  MusicalBeatSize horizontalClipShiftSizeDenom,  GridSize gridSize,  bool snapToGrid,  bool showExportPanel,  BrowserPanelState browserPanelState,  FloatingMidiKeyboardFieldState floatingMidiKeyboardState)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceState() when $default != null:
return $default(_that.currentView,_that.selectedTool,_that.currentToolbarContext,_that.interactionTarget,_that.editingPatternId,_that.horizontalZoomLevel,_that.horizontalClipShiftSizeDenom,_that.gridSize,_that.snapToGrid,_that.showExportPanel,_that.browserPanelState,_that.floatingMidiKeyboardState);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceState extends WorkspaceState {
  const _WorkspaceState({this.currentView = WorkspaceView.trackList, this.selectedTool = ToolSelection.pointer, this.currentToolbarContext = ToolbarMenuContextGroup.none, this.interactionTarget, this.editingPatternId, this.horizontalZoomLevel = 100.0, this.horizontalClipShiftSizeDenom = MusicalBeatSize.none, this.gridSize = GridSize.quarter, this.snapToGrid = false, this.showExportPanel = false, this.browserPanelState = const BrowserPanelState(), this.floatingMidiKeyboardState = const FloatingMidiKeyboardFieldState()}): super._();
  

@override@JsonKey() final  WorkspaceView currentView;
@override@JsonKey() final  ToolSelection selectedTool;
@override@JsonKey() final  ToolbarMenuContextGroup currentToolbarContext;
@override final  InteractionTarget? interactionTarget;
@override final  int? editingPatternId;
@override@JsonKey() final  double horizontalZoomLevel;
@override@JsonKey() final  MusicalBeatSize horizontalClipShiftSizeDenom;
@override@JsonKey() final  GridSize gridSize;
@override@JsonKey() final  bool snapToGrid;
@override@JsonKey() final  bool showExportPanel;
@override@JsonKey() final  BrowserPanelState browserPanelState;
@override@JsonKey() final  FloatingMidiKeyboardFieldState floatingMidiKeyboardState;

/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceStateCopyWith<_WorkspaceState> get copyWith => __$WorkspaceStateCopyWithImpl<_WorkspaceState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceState&&(identical(other.currentView, currentView) || other.currentView == currentView)&&(identical(other.selectedTool, selectedTool) || other.selectedTool == selectedTool)&&(identical(other.currentToolbarContext, currentToolbarContext) || other.currentToolbarContext == currentToolbarContext)&&(identical(other.interactionTarget, interactionTarget) || other.interactionTarget == interactionTarget)&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.horizontalZoomLevel, horizontalZoomLevel) || other.horizontalZoomLevel == horizontalZoomLevel)&&(identical(other.horizontalClipShiftSizeDenom, horizontalClipShiftSizeDenom) || other.horizontalClipShiftSizeDenom == horizontalClipShiftSizeDenom)&&(identical(other.gridSize, gridSize) || other.gridSize == gridSize)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&(identical(other.showExportPanel, showExportPanel) || other.showExportPanel == showExportPanel)&&(identical(other.browserPanelState, browserPanelState) || other.browserPanelState == browserPanelState)&&(identical(other.floatingMidiKeyboardState, floatingMidiKeyboardState) || other.floatingMidiKeyboardState == floatingMidiKeyboardState));
}


@override
int get hashCode => Object.hash(runtimeType,currentView,selectedTool,currentToolbarContext,interactionTarget,editingPatternId,horizontalZoomLevel,horizontalClipShiftSizeDenom,gridSize,snapToGrid,showExportPanel,browserPanelState,floatingMidiKeyboardState);

@override
String toString() {
  return 'WorkspaceState(currentView: $currentView, selectedTool: $selectedTool, currentToolbarContext: $currentToolbarContext, interactionTarget: $interactionTarget, editingPatternId: $editingPatternId, horizontalZoomLevel: $horizontalZoomLevel, horizontalClipShiftSizeDenom: $horizontalClipShiftSizeDenom, gridSize: $gridSize, snapToGrid: $snapToGrid, showExportPanel: $showExportPanel, browserPanelState: $browserPanelState, floatingMidiKeyboardState: $floatingMidiKeyboardState)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceStateCopyWith<$Res> implements $WorkspaceStateCopyWith<$Res> {
  factory _$WorkspaceStateCopyWith(_WorkspaceState value, $Res Function(_WorkspaceState) _then) = __$WorkspaceStateCopyWithImpl;
@override @useResult
$Res call({
 WorkspaceView currentView, ToolSelection selectedTool, ToolbarMenuContextGroup currentToolbarContext, InteractionTarget? interactionTarget, int? editingPatternId, double horizontalZoomLevel, MusicalBeatSize horizontalClipShiftSizeDenom, GridSize gridSize, bool snapToGrid, bool showExportPanel, BrowserPanelState browserPanelState, FloatingMidiKeyboardFieldState floatingMidiKeyboardState
});


@override $BrowserPanelStateCopyWith<$Res> get browserPanelState;@override $FloatingMidiKeyboardFieldStateCopyWith<$Res> get floatingMidiKeyboardState;

}
/// @nodoc
class __$WorkspaceStateCopyWithImpl<$Res>
    implements _$WorkspaceStateCopyWith<$Res> {
  __$WorkspaceStateCopyWithImpl(this._self, this._then);

  final _WorkspaceState _self;
  final $Res Function(_WorkspaceState) _then;

/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentView = null,Object? selectedTool = null,Object? currentToolbarContext = null,Object? interactionTarget = freezed,Object? editingPatternId = freezed,Object? horizontalZoomLevel = null,Object? horizontalClipShiftSizeDenom = null,Object? gridSize = null,Object? snapToGrid = null,Object? showExportPanel = null,Object? browserPanelState = null,Object? floatingMidiKeyboardState = null,}) {
  return _then(_WorkspaceState(
currentView: null == currentView ? _self.currentView : currentView // ignore: cast_nullable_to_non_nullable
as WorkspaceView,selectedTool: null == selectedTool ? _self.selectedTool : selectedTool // ignore: cast_nullable_to_non_nullable
as ToolSelection,currentToolbarContext: null == currentToolbarContext ? _self.currentToolbarContext : currentToolbarContext // ignore: cast_nullable_to_non_nullable
as ToolbarMenuContextGroup,interactionTarget: freezed == interactionTarget ? _self.interactionTarget : interactionTarget // ignore: cast_nullable_to_non_nullable
as InteractionTarget?,editingPatternId: freezed == editingPatternId ? _self.editingPatternId : editingPatternId // ignore: cast_nullable_to_non_nullable
as int?,horizontalZoomLevel: null == horizontalZoomLevel ? _self.horizontalZoomLevel : horizontalZoomLevel // ignore: cast_nullable_to_non_nullable
as double,horizontalClipShiftSizeDenom: null == horizontalClipShiftSizeDenom ? _self.horizontalClipShiftSizeDenom : horizontalClipShiftSizeDenom // ignore: cast_nullable_to_non_nullable
as MusicalBeatSize,gridSize: null == gridSize ? _self.gridSize : gridSize // ignore: cast_nullable_to_non_nullable
as GridSize,snapToGrid: null == snapToGrid ? _self.snapToGrid : snapToGrid // ignore: cast_nullable_to_non_nullable
as bool,showExportPanel: null == showExportPanel ? _self.showExportPanel : showExportPanel // ignore: cast_nullable_to_non_nullable
as bool,browserPanelState: null == browserPanelState ? _self.browserPanelState : browserPanelState // ignore: cast_nullable_to_non_nullable
as BrowserPanelState,floatingMidiKeyboardState: null == floatingMidiKeyboardState ? _self.floatingMidiKeyboardState : floatingMidiKeyboardState // ignore: cast_nullable_to_non_nullable
as FloatingMidiKeyboardFieldState,
  ));
}

/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BrowserPanelStateCopyWith<$Res> get browserPanelState {
  
  return $BrowserPanelStateCopyWith<$Res>(_self.browserPanelState, (value) {
    return _then(_self.copyWith(browserPanelState: value));
  });
}/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FloatingMidiKeyboardFieldStateCopyWith<$Res> get floatingMidiKeyboardState {
  
  return $FloatingMidiKeyboardFieldStateCopyWith<$Res>(_self.floatingMidiKeyboardState, (value) {
    return _then(_self.copyWith(floatingMidiKeyboardState: value));
  });
}
}

// dart format on
