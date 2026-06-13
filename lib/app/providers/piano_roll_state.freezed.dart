// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'piano_roll_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PianoRollStateData {

 int? get editingPatternId; PianoRollToolSelection get tool; double get zoomLevelTick; GridSize get gridSize; bool get snapToGrid; Set<int> get selectedNoteIds; int? get previewGeneratorId;
/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PianoRollStateDataCopyWith<PianoRollStateData> get copyWith => _$PianoRollStateDataCopyWithImpl<PianoRollStateData>(this as PianoRollStateData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PianoRollStateData&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.zoomLevelTick, zoomLevelTick) || other.zoomLevelTick == zoomLevelTick)&&(identical(other.gridSize, gridSize) || other.gridSize == gridSize)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&const DeepCollectionEquality().equals(other.selectedNoteIds, selectedNoteIds)&&(identical(other.previewGeneratorId, previewGeneratorId) || other.previewGeneratorId == previewGeneratorId));
}


@override
int get hashCode => Object.hash(runtimeType,editingPatternId,tool,zoomLevelTick,gridSize,snapToGrid,const DeepCollectionEquality().hash(selectedNoteIds),previewGeneratorId);

@override
String toString() {
  return 'PianoRollStateData(editingPatternId: $editingPatternId, tool: $tool, zoomLevelTick: $zoomLevelTick, gridSize: $gridSize, snapToGrid: $snapToGrid, selectedNoteIds: $selectedNoteIds, previewGeneratorId: $previewGeneratorId)';
}


}

/// @nodoc
abstract mixin class $PianoRollStateDataCopyWith<$Res>  {
  factory $PianoRollStateDataCopyWith(PianoRollStateData value, $Res Function(PianoRollStateData) _then) = _$PianoRollStateDataCopyWithImpl;
@useResult
$Res call({
 int? editingPatternId, PianoRollToolSelection tool, double zoomLevelTick, GridSize gridSize, bool snapToGrid, Set<int> selectedNoteIds, int? previewGeneratorId
});




}
/// @nodoc
class _$PianoRollStateDataCopyWithImpl<$Res>
    implements $PianoRollStateDataCopyWith<$Res> {
  _$PianoRollStateDataCopyWithImpl(this._self, this._then);

  final PianoRollStateData _self;
  final $Res Function(PianoRollStateData) _then;

/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? editingPatternId = freezed,Object? tool = null,Object? zoomLevelTick = null,Object? gridSize = null,Object? snapToGrid = null,Object? selectedNoteIds = null,Object? previewGeneratorId = freezed,}) {
  return _then(_self.copyWith(
editingPatternId: freezed == editingPatternId ? _self.editingPatternId : editingPatternId // ignore: cast_nullable_to_non_nullable
as int?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as PianoRollToolSelection,zoomLevelTick: null == zoomLevelTick ? _self.zoomLevelTick : zoomLevelTick // ignore: cast_nullable_to_non_nullable
as double,gridSize: null == gridSize ? _self.gridSize : gridSize // ignore: cast_nullable_to_non_nullable
as GridSize,snapToGrid: null == snapToGrid ? _self.snapToGrid : snapToGrid // ignore: cast_nullable_to_non_nullable
as bool,selectedNoteIds: null == selectedNoteIds ? _self.selectedNoteIds : selectedNoteIds // ignore: cast_nullable_to_non_nullable
as Set<int>,previewGeneratorId: freezed == previewGeneratorId ? _self.previewGeneratorId : previewGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PianoRollStateData].
extension PianoRollStateDataPatterns on PianoRollStateData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PianoRollStateData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PianoRollStateData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PianoRollStateData value)  $default,){
final _that = this;
switch (_that) {
case _PianoRollStateData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PianoRollStateData value)?  $default,){
final _that = this;
switch (_that) {
case _PianoRollStateData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  GridSize gridSize,  bool snapToGrid,  Set<int> selectedNoteIds,  int? previewGeneratorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PianoRollStateData() when $default != null:
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.gridSize,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  GridSize gridSize,  bool snapToGrid,  Set<int> selectedNoteIds,  int? previewGeneratorId)  $default,) {final _that = this;
switch (_that) {
case _PianoRollStateData():
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.gridSize,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  GridSize gridSize,  bool snapToGrid,  Set<int> selectedNoteIds,  int? previewGeneratorId)?  $default,) {final _that = this;
switch (_that) {
case _PianoRollStateData() when $default != null:
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.gridSize,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId);case _:
  return null;

}
}

}

/// @nodoc


class _PianoRollStateData implements PianoRollStateData {
  const _PianoRollStateData({this.editingPatternId = null, this.tool = PianoRollToolSelection.grab, this.zoomLevelTick = 0.67, this.gridSize = GridSize.quarter, this.snapToGrid = false, final  Set<int> selectedNoteIds = const {}, this.previewGeneratorId = null}): _selectedNoteIds = selectedNoteIds;
  

@override@JsonKey() final  int? editingPatternId;
@override@JsonKey() final  PianoRollToolSelection tool;
@override@JsonKey() final  double zoomLevelTick;
@override@JsonKey() final  GridSize gridSize;
@override@JsonKey() final  bool snapToGrid;
 final  Set<int> _selectedNoteIds;
@override@JsonKey() Set<int> get selectedNoteIds {
  if (_selectedNoteIds is EqualUnmodifiableSetView) return _selectedNoteIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedNoteIds);
}

@override@JsonKey() final  int? previewGeneratorId;

/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PianoRollStateDataCopyWith<_PianoRollStateData> get copyWith => __$PianoRollStateDataCopyWithImpl<_PianoRollStateData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PianoRollStateData&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.zoomLevelTick, zoomLevelTick) || other.zoomLevelTick == zoomLevelTick)&&(identical(other.gridSize, gridSize) || other.gridSize == gridSize)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&const DeepCollectionEquality().equals(other._selectedNoteIds, _selectedNoteIds)&&(identical(other.previewGeneratorId, previewGeneratorId) || other.previewGeneratorId == previewGeneratorId));
}


@override
int get hashCode => Object.hash(runtimeType,editingPatternId,tool,zoomLevelTick,gridSize,snapToGrid,const DeepCollectionEquality().hash(_selectedNoteIds),previewGeneratorId);

@override
String toString() {
  return 'PianoRollStateData(editingPatternId: $editingPatternId, tool: $tool, zoomLevelTick: $zoomLevelTick, gridSize: $gridSize, snapToGrid: $snapToGrid, selectedNoteIds: $selectedNoteIds, previewGeneratorId: $previewGeneratorId)';
}


}

/// @nodoc
abstract mixin class _$PianoRollStateDataCopyWith<$Res> implements $PianoRollStateDataCopyWith<$Res> {
  factory _$PianoRollStateDataCopyWith(_PianoRollStateData value, $Res Function(_PianoRollStateData) _then) = __$PianoRollStateDataCopyWithImpl;
@override @useResult
$Res call({
 int? editingPatternId, PianoRollToolSelection tool, double zoomLevelTick, GridSize gridSize, bool snapToGrid, Set<int> selectedNoteIds, int? previewGeneratorId
});




}
/// @nodoc
class __$PianoRollStateDataCopyWithImpl<$Res>
    implements _$PianoRollStateDataCopyWith<$Res> {
  __$PianoRollStateDataCopyWithImpl(this._self, this._then);

  final _PianoRollStateData _self;
  final $Res Function(_PianoRollStateData) _then;

/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? editingPatternId = freezed,Object? tool = null,Object? zoomLevelTick = null,Object? gridSize = null,Object? snapToGrid = null,Object? selectedNoteIds = null,Object? previewGeneratorId = freezed,}) {
  return _then(_PianoRollStateData(
editingPatternId: freezed == editingPatternId ? _self.editingPatternId : editingPatternId // ignore: cast_nullable_to_non_nullable
as int?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as PianoRollToolSelection,zoomLevelTick: null == zoomLevelTick ? _self.zoomLevelTick : zoomLevelTick // ignore: cast_nullable_to_non_nullable
as double,gridSize: null == gridSize ? _self.gridSize : gridSize // ignore: cast_nullable_to_non_nullable
as GridSize,snapToGrid: null == snapToGrid ? _self.snapToGrid : snapToGrid // ignore: cast_nullable_to_non_nullable
as bool,selectedNoteIds: null == selectedNoteIds ? _self._selectedNoteIds : selectedNoteIds // ignore: cast_nullable_to_non_nullable
as Set<int>,previewGeneratorId: freezed == previewGeneratorId ? _self.previewGeneratorId : previewGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
