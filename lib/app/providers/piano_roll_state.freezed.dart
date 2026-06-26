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

 int? get editingPatternId; PianoRollToolSelection get tool; double get zoomLevelTick; bool get snapToGrid; ISet<int> get selectedNoteIds; int? get previewGeneratorId; GridSize get pianoRollGridDenom;
/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PianoRollStateDataCopyWith<PianoRollStateData> get copyWith => _$PianoRollStateDataCopyWithImpl<PianoRollStateData>(this as PianoRollStateData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PianoRollStateData&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.zoomLevelTick, zoomLevelTick) || other.zoomLevelTick == zoomLevelTick)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&const DeepCollectionEquality().equals(other.selectedNoteIds, selectedNoteIds)&&(identical(other.previewGeneratorId, previewGeneratorId) || other.previewGeneratorId == previewGeneratorId)&&(identical(other.pianoRollGridDenom, pianoRollGridDenom) || other.pianoRollGridDenom == pianoRollGridDenom));
}


@override
int get hashCode => Object.hash(runtimeType,editingPatternId,tool,zoomLevelTick,snapToGrid,const DeepCollectionEquality().hash(selectedNoteIds),previewGeneratorId,pianoRollGridDenom);

@override
String toString() {
  return 'PianoRollStateData(editingPatternId: $editingPatternId, tool: $tool, zoomLevelTick: $zoomLevelTick, snapToGrid: $snapToGrid, selectedNoteIds: $selectedNoteIds, previewGeneratorId: $previewGeneratorId, pianoRollGridDenom: $pianoRollGridDenom)';
}


}

/// @nodoc
abstract mixin class $PianoRollStateDataCopyWith<$Res>  {
  factory $PianoRollStateDataCopyWith(PianoRollStateData value, $Res Function(PianoRollStateData) _then) = _$PianoRollStateDataCopyWithImpl;
@useResult
$Res call({
 int? editingPatternId, PianoRollToolSelection tool, double zoomLevelTick, bool snapToGrid, ISet<int> selectedNoteIds, int? previewGeneratorId, GridSize pianoRollGridDenom
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
@pragma('vm:prefer-inline') @override $Res call({Object? editingPatternId = freezed,Object? tool = null,Object? zoomLevelTick = null,Object? snapToGrid = null,Object? selectedNoteIds = null,Object? previewGeneratorId = freezed,Object? pianoRollGridDenom = null,}) {
  return _then(_self.copyWith(
editingPatternId: freezed == editingPatternId ? _self.editingPatternId : editingPatternId // ignore: cast_nullable_to_non_nullable
as int?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as PianoRollToolSelection,zoomLevelTick: null == zoomLevelTick ? _self.zoomLevelTick : zoomLevelTick // ignore: cast_nullable_to_non_nullable
as double,snapToGrid: null == snapToGrid ? _self.snapToGrid : snapToGrid // ignore: cast_nullable_to_non_nullable
as bool,selectedNoteIds: null == selectedNoteIds ? _self.selectedNoteIds : selectedNoteIds // ignore: cast_nullable_to_non_nullable
as ISet<int>,previewGeneratorId: freezed == previewGeneratorId ? _self.previewGeneratorId : previewGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,pianoRollGridDenom: null == pianoRollGridDenom ? _self.pianoRollGridDenom : pianoRollGridDenom // ignore: cast_nullable_to_non_nullable
as GridSize,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  bool snapToGrid,  ISet<int> selectedNoteIds,  int? previewGeneratorId,  GridSize pianoRollGridDenom)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PianoRollStateData() when $default != null:
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId,_that.pianoRollGridDenom);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  bool snapToGrid,  ISet<int> selectedNoteIds,  int? previewGeneratorId,  GridSize pianoRollGridDenom)  $default,) {final _that = this;
switch (_that) {
case _PianoRollStateData():
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId,_that.pianoRollGridDenom);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  bool snapToGrid,  ISet<int> selectedNoteIds,  int? previewGeneratorId,  GridSize pianoRollGridDenom)?  $default,) {final _that = this;
switch (_that) {
case _PianoRollStateData() when $default != null:
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId,_that.pianoRollGridDenom);case _:
  return null;

}
}

}

/// @nodoc


class _PianoRollStateData implements PianoRollStateData {
  const _PianoRollStateData({this.editingPatternId = null, this.tool = PianoRollToolSelection.grab, this.zoomLevelTick = 0.67, this.snapToGrid = false, this.selectedNoteIds = const ISetConst<int>({}), this.previewGeneratorId = null, this.pianoRollGridDenom = GridSize.quarter});
  

@override@JsonKey() final  int? editingPatternId;
@override@JsonKey() final  PianoRollToolSelection tool;
@override@JsonKey() final  double zoomLevelTick;
@override@JsonKey() final  bool snapToGrid;
@override@JsonKey() final  ISet<int> selectedNoteIds;
@override@JsonKey() final  int? previewGeneratorId;
@override@JsonKey() final  GridSize pianoRollGridDenom;

/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PianoRollStateDataCopyWith<_PianoRollStateData> get copyWith => __$PianoRollStateDataCopyWithImpl<_PianoRollStateData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PianoRollStateData&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.zoomLevelTick, zoomLevelTick) || other.zoomLevelTick == zoomLevelTick)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&const DeepCollectionEquality().equals(other.selectedNoteIds, selectedNoteIds)&&(identical(other.previewGeneratorId, previewGeneratorId) || other.previewGeneratorId == previewGeneratorId)&&(identical(other.pianoRollGridDenom, pianoRollGridDenom) || other.pianoRollGridDenom == pianoRollGridDenom));
}


@override
int get hashCode => Object.hash(runtimeType,editingPatternId,tool,zoomLevelTick,snapToGrid,const DeepCollectionEquality().hash(selectedNoteIds),previewGeneratorId,pianoRollGridDenom);

@override
String toString() {
  return 'PianoRollStateData(editingPatternId: $editingPatternId, tool: $tool, zoomLevelTick: $zoomLevelTick, snapToGrid: $snapToGrid, selectedNoteIds: $selectedNoteIds, previewGeneratorId: $previewGeneratorId, pianoRollGridDenom: $pianoRollGridDenom)';
}


}

/// @nodoc
abstract mixin class _$PianoRollStateDataCopyWith<$Res> implements $PianoRollStateDataCopyWith<$Res> {
  factory _$PianoRollStateDataCopyWith(_PianoRollStateData value, $Res Function(_PianoRollStateData) _then) = __$PianoRollStateDataCopyWithImpl;
@override @useResult
$Res call({
 int? editingPatternId, PianoRollToolSelection tool, double zoomLevelTick, bool snapToGrid, ISet<int> selectedNoteIds, int? previewGeneratorId, GridSize pianoRollGridDenom
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
@override @pragma('vm:prefer-inline') $Res call({Object? editingPatternId = freezed,Object? tool = null,Object? zoomLevelTick = null,Object? snapToGrid = null,Object? selectedNoteIds = null,Object? previewGeneratorId = freezed,Object? pianoRollGridDenom = null,}) {
  return _then(_PianoRollStateData(
editingPatternId: freezed == editingPatternId ? _self.editingPatternId : editingPatternId // ignore: cast_nullable_to_non_nullable
as int?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as PianoRollToolSelection,zoomLevelTick: null == zoomLevelTick ? _self.zoomLevelTick : zoomLevelTick // ignore: cast_nullable_to_non_nullable
as double,snapToGrid: null == snapToGrid ? _self.snapToGrid : snapToGrid // ignore: cast_nullable_to_non_nullable
as bool,selectedNoteIds: null == selectedNoteIds ? _self.selectedNoteIds : selectedNoteIds // ignore: cast_nullable_to_non_nullable
as ISet<int>,previewGeneratorId: freezed == previewGeneratorId ? _self.previewGeneratorId : previewGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,pianoRollGridDenom: null == pianoRollGridDenom ? _self.pianoRollGridDenom : pianoRollGridDenom // ignore: cast_nullable_to_non_nullable
as GridSize,
  ));
}


}

// dart format on
