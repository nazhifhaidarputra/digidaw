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
mixin _$WorkspaceState {

 WorkspaceView get currentView; ToolSelection get selectedTool; ToolbarMenuContextGroup get currentToolbarContext; InteractionTarget? get interactionTarget; int? get editingPatternId; double get horizontalZoomLevel; MusicalBeatSize get horizontalClipShiftSizeDenom; GridSize get gridSize; bool get snapToGrid; bool get showExportPanel; bool get showFloatingMidiKeyboard;
/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceStateCopyWith<WorkspaceState> get copyWith => _$WorkspaceStateCopyWithImpl<WorkspaceState>(this as WorkspaceState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceState&&(identical(other.currentView, currentView) || other.currentView == currentView)&&(identical(other.selectedTool, selectedTool) || other.selectedTool == selectedTool)&&(identical(other.currentToolbarContext, currentToolbarContext) || other.currentToolbarContext == currentToolbarContext)&&(identical(other.interactionTarget, interactionTarget) || other.interactionTarget == interactionTarget)&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.horizontalZoomLevel, horizontalZoomLevel) || other.horizontalZoomLevel == horizontalZoomLevel)&&(identical(other.horizontalClipShiftSizeDenom, horizontalClipShiftSizeDenom) || other.horizontalClipShiftSizeDenom == horizontalClipShiftSizeDenom)&&(identical(other.gridSize, gridSize) || other.gridSize == gridSize)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&(identical(other.showExportPanel, showExportPanel) || other.showExportPanel == showExportPanel)&&(identical(other.showFloatingMidiKeyboard, showFloatingMidiKeyboard) || other.showFloatingMidiKeyboard == showFloatingMidiKeyboard));
}


@override
int get hashCode => Object.hash(runtimeType,currentView,selectedTool,currentToolbarContext,interactionTarget,editingPatternId,horizontalZoomLevel,horizontalClipShiftSizeDenom,gridSize,snapToGrid,showExportPanel,showFloatingMidiKeyboard);

@override
String toString() {
  return 'WorkspaceState(currentView: $currentView, selectedTool: $selectedTool, currentToolbarContext: $currentToolbarContext, interactionTarget: $interactionTarget, editingPatternId: $editingPatternId, horizontalZoomLevel: $horizontalZoomLevel, horizontalClipShiftSizeDenom: $horizontalClipShiftSizeDenom, gridSize: $gridSize, snapToGrid: $snapToGrid, showExportPanel: $showExportPanel, showFloatingMidiKeyboard: $showFloatingMidiKeyboard)';
}


}

/// @nodoc
abstract mixin class $WorkspaceStateCopyWith<$Res>  {
  factory $WorkspaceStateCopyWith(WorkspaceState value, $Res Function(WorkspaceState) _then) = _$WorkspaceStateCopyWithImpl;
@useResult
$Res call({
 WorkspaceView currentView, ToolSelection selectedTool, ToolbarMenuContextGroup currentToolbarContext, InteractionTarget? interactionTarget, int? editingPatternId, double horizontalZoomLevel, MusicalBeatSize horizontalClipShiftSizeDenom, GridSize gridSize, bool snapToGrid, bool showExportPanel, bool showFloatingMidiKeyboard
});




}
/// @nodoc
class _$WorkspaceStateCopyWithImpl<$Res>
    implements $WorkspaceStateCopyWith<$Res> {
  _$WorkspaceStateCopyWithImpl(this._self, this._then);

  final WorkspaceState _self;
  final $Res Function(WorkspaceState) _then;

/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentView = null,Object? selectedTool = null,Object? currentToolbarContext = null,Object? interactionTarget = freezed,Object? editingPatternId = freezed,Object? horizontalZoomLevel = null,Object? horizontalClipShiftSizeDenom = null,Object? gridSize = null,Object? snapToGrid = null,Object? showExportPanel = null,Object? showFloatingMidiKeyboard = null,}) {
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
as bool,showFloatingMidiKeyboard: null == showFloatingMidiKeyboard ? _self.showFloatingMidiKeyboard : showFloatingMidiKeyboard // ignore: cast_nullable_to_non_nullable
as bool,
  ));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkspaceView currentView,  ToolSelection selectedTool,  ToolbarMenuContextGroup currentToolbarContext,  InteractionTarget? interactionTarget,  int? editingPatternId,  double horizontalZoomLevel,  MusicalBeatSize horizontalClipShiftSizeDenom,  GridSize gridSize,  bool snapToGrid,  bool showExportPanel,  bool showFloatingMidiKeyboard)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceState() when $default != null:
return $default(_that.currentView,_that.selectedTool,_that.currentToolbarContext,_that.interactionTarget,_that.editingPatternId,_that.horizontalZoomLevel,_that.horizontalClipShiftSizeDenom,_that.gridSize,_that.snapToGrid,_that.showExportPanel,_that.showFloatingMidiKeyboard);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkspaceView currentView,  ToolSelection selectedTool,  ToolbarMenuContextGroup currentToolbarContext,  InteractionTarget? interactionTarget,  int? editingPatternId,  double horizontalZoomLevel,  MusicalBeatSize horizontalClipShiftSizeDenom,  GridSize gridSize,  bool snapToGrid,  bool showExportPanel,  bool showFloatingMidiKeyboard)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceState():
return $default(_that.currentView,_that.selectedTool,_that.currentToolbarContext,_that.interactionTarget,_that.editingPatternId,_that.horizontalZoomLevel,_that.horizontalClipShiftSizeDenom,_that.gridSize,_that.snapToGrid,_that.showExportPanel,_that.showFloatingMidiKeyboard);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkspaceView currentView,  ToolSelection selectedTool,  ToolbarMenuContextGroup currentToolbarContext,  InteractionTarget? interactionTarget,  int? editingPatternId,  double horizontalZoomLevel,  MusicalBeatSize horizontalClipShiftSizeDenom,  GridSize gridSize,  bool snapToGrid,  bool showExportPanel,  bool showFloatingMidiKeyboard)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceState() when $default != null:
return $default(_that.currentView,_that.selectedTool,_that.currentToolbarContext,_that.interactionTarget,_that.editingPatternId,_that.horizontalZoomLevel,_that.horizontalClipShiftSizeDenom,_that.gridSize,_that.snapToGrid,_that.showExportPanel,_that.showFloatingMidiKeyboard);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceState extends WorkspaceState {
  const _WorkspaceState({this.currentView = WorkspaceView.trackList, this.selectedTool = ToolSelection.pointer, this.currentToolbarContext = ToolbarMenuContextGroup.none, this.interactionTarget, this.editingPatternId, this.horizontalZoomLevel = 100.0, this.horizontalClipShiftSizeDenom = MusicalBeatSize.none, this.gridSize = GridSize.quarter, this.snapToGrid = false, this.showExportPanel = false, this.showFloatingMidiKeyboard = false}): super._();
  

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
@override@JsonKey() final  bool showFloatingMidiKeyboard;

/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceStateCopyWith<_WorkspaceState> get copyWith => __$WorkspaceStateCopyWithImpl<_WorkspaceState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceState&&(identical(other.currentView, currentView) || other.currentView == currentView)&&(identical(other.selectedTool, selectedTool) || other.selectedTool == selectedTool)&&(identical(other.currentToolbarContext, currentToolbarContext) || other.currentToolbarContext == currentToolbarContext)&&(identical(other.interactionTarget, interactionTarget) || other.interactionTarget == interactionTarget)&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.horizontalZoomLevel, horizontalZoomLevel) || other.horizontalZoomLevel == horizontalZoomLevel)&&(identical(other.horizontalClipShiftSizeDenom, horizontalClipShiftSizeDenom) || other.horizontalClipShiftSizeDenom == horizontalClipShiftSizeDenom)&&(identical(other.gridSize, gridSize) || other.gridSize == gridSize)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&(identical(other.showExportPanel, showExportPanel) || other.showExportPanel == showExportPanel)&&(identical(other.showFloatingMidiKeyboard, showFloatingMidiKeyboard) || other.showFloatingMidiKeyboard == showFloatingMidiKeyboard));
}


@override
int get hashCode => Object.hash(runtimeType,currentView,selectedTool,currentToolbarContext,interactionTarget,editingPatternId,horizontalZoomLevel,horizontalClipShiftSizeDenom,gridSize,snapToGrid,showExportPanel,showFloatingMidiKeyboard);

@override
String toString() {
  return 'WorkspaceState(currentView: $currentView, selectedTool: $selectedTool, currentToolbarContext: $currentToolbarContext, interactionTarget: $interactionTarget, editingPatternId: $editingPatternId, horizontalZoomLevel: $horizontalZoomLevel, horizontalClipShiftSizeDenom: $horizontalClipShiftSizeDenom, gridSize: $gridSize, snapToGrid: $snapToGrid, showExportPanel: $showExportPanel, showFloatingMidiKeyboard: $showFloatingMidiKeyboard)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceStateCopyWith<$Res> implements $WorkspaceStateCopyWith<$Res> {
  factory _$WorkspaceStateCopyWith(_WorkspaceState value, $Res Function(_WorkspaceState) _then) = __$WorkspaceStateCopyWithImpl;
@override @useResult
$Res call({
 WorkspaceView currentView, ToolSelection selectedTool, ToolbarMenuContextGroup currentToolbarContext, InteractionTarget? interactionTarget, int? editingPatternId, double horizontalZoomLevel, MusicalBeatSize horizontalClipShiftSizeDenom, GridSize gridSize, bool snapToGrid, bool showExportPanel, bool showFloatingMidiKeyboard
});




}
/// @nodoc
class __$WorkspaceStateCopyWithImpl<$Res>
    implements _$WorkspaceStateCopyWith<$Res> {
  __$WorkspaceStateCopyWithImpl(this._self, this._then);

  final _WorkspaceState _self;
  final $Res Function(_WorkspaceState) _then;

/// Create a copy of WorkspaceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentView = null,Object? selectedTool = null,Object? currentToolbarContext = null,Object? interactionTarget = freezed,Object? editingPatternId = freezed,Object? horizontalZoomLevel = null,Object? horizontalClipShiftSizeDenom = null,Object? gridSize = null,Object? snapToGrid = null,Object? showExportPanel = null,Object? showFloatingMidiKeyboard = null,}) {
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
as bool,showFloatingMidiKeyboard: null == showFloatingMidiKeyboard ? _self.showFloatingMidiKeyboard : showFloatingMidiKeyboard // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
