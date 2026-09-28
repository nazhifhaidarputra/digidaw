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
mixin _$PatternLoopRegion {

 int get startTick; int get endTick;
/// Create a copy of PatternLoopRegion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PatternLoopRegionCopyWith<PatternLoopRegion> get copyWith => _$PatternLoopRegionCopyWithImpl<PatternLoopRegion>(this as PatternLoopRegion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PatternLoopRegion&&(identical(other.startTick, startTick) || other.startTick == startTick)&&(identical(other.endTick, endTick) || other.endTick == endTick));
}


@override
int get hashCode => Object.hash(runtimeType,startTick,endTick);

@override
String toString() {
  return 'PatternLoopRegion(startTick: $startTick, endTick: $endTick)';
}


}

/// @nodoc
abstract mixin class $PatternLoopRegionCopyWith<$Res>  {
  factory $PatternLoopRegionCopyWith(PatternLoopRegion value, $Res Function(PatternLoopRegion) _then) = _$PatternLoopRegionCopyWithImpl;
@useResult
$Res call({
 int startTick, int endTick
});




}
/// @nodoc
class _$PatternLoopRegionCopyWithImpl<$Res>
    implements $PatternLoopRegionCopyWith<$Res> {
  _$PatternLoopRegionCopyWithImpl(this._self, this._then);

  final PatternLoopRegion _self;
  final $Res Function(PatternLoopRegion) _then;

/// Create a copy of PatternLoopRegion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startTick = null,Object? endTick = null,}) {
  return _then(_self.copyWith(
startTick: null == startTick ? _self.startTick : startTick // ignore: cast_nullable_to_non_nullable
as int,endTick: null == endTick ? _self.endTick : endTick // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PatternLoopRegion].
extension PatternLoopRegionPatterns on PatternLoopRegion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PatternLoopRegion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PatternLoopRegion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PatternLoopRegion value)  $default,){
final _that = this;
switch (_that) {
case _PatternLoopRegion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PatternLoopRegion value)?  $default,){
final _that = this;
switch (_that) {
case _PatternLoopRegion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startTick,  int endTick)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PatternLoopRegion() when $default != null:
return $default(_that.startTick,_that.endTick);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startTick,  int endTick)  $default,) {final _that = this;
switch (_that) {
case _PatternLoopRegion():
return $default(_that.startTick,_that.endTick);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startTick,  int endTick)?  $default,) {final _that = this;
switch (_that) {
case _PatternLoopRegion() when $default != null:
return $default(_that.startTick,_that.endTick);case _:
  return null;

}
}

}

/// @nodoc


class _PatternLoopRegion implements PatternLoopRegion {
  const _PatternLoopRegion({required this.startTick, required this.endTick});
  

@override final  int startTick;
@override final  int endTick;

/// Create a copy of PatternLoopRegion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PatternLoopRegionCopyWith<_PatternLoopRegion> get copyWith => __$PatternLoopRegionCopyWithImpl<_PatternLoopRegion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PatternLoopRegion&&(identical(other.startTick, startTick) || other.startTick == startTick)&&(identical(other.endTick, endTick) || other.endTick == endTick));
}


@override
int get hashCode => Object.hash(runtimeType,startTick,endTick);

@override
String toString() {
  return 'PatternLoopRegion(startTick: $startTick, endTick: $endTick)';
}


}

/// @nodoc
abstract mixin class _$PatternLoopRegionCopyWith<$Res> implements $PatternLoopRegionCopyWith<$Res> {
  factory _$PatternLoopRegionCopyWith(_PatternLoopRegion value, $Res Function(_PatternLoopRegion) _then) = __$PatternLoopRegionCopyWithImpl;
@override @useResult
$Res call({
 int startTick, int endTick
});




}
/// @nodoc
class __$PatternLoopRegionCopyWithImpl<$Res>
    implements _$PatternLoopRegionCopyWith<$Res> {
  __$PatternLoopRegionCopyWithImpl(this._self, this._then);

  final _PatternLoopRegion _self;
  final $Res Function(_PatternLoopRegion) _then;

/// Create a copy of PatternLoopRegion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startTick = null,Object? endTick = null,}) {
  return _then(_PatternLoopRegion(
startTick: null == startTick ? _self.startTick : startTick // ignore: cast_nullable_to_non_nullable
as int,endTick: null == endTick ? _self.endTick : endTick // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$PianoRollStateData {

 int? get editingPatternId; PianoRollToolSelection get tool; double get zoomLevelTick; bool get snapToGrid; ISet<int> get selectedNoteIds; int? get previewGeneratorId;/// Visual grid drawn behind the notes.
 GridSize get pianoRollGridDenom;/// Step that drawing, moving, and resizing snap to, or null to follow the
/// grid, so a one-beat grid can still place half-beat notes.
 GridSize? get drawStep;/// Height of one key row, in pixels.
 double get keyHeight;/// Loop region for pattern playback; the whole pattern loops when null.
 PatternLoopRegion? get loopRegion;/// Notes the draw tool stamps: the latest selection, like FL Studio.
 IList<UiNote> get drawTemplate;
/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PianoRollStateDataCopyWith<PianoRollStateData> get copyWith => _$PianoRollStateDataCopyWithImpl<PianoRollStateData>(this as PianoRollStateData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PianoRollStateData&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.zoomLevelTick, zoomLevelTick) || other.zoomLevelTick == zoomLevelTick)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&const DeepCollectionEquality().equals(other.selectedNoteIds, selectedNoteIds)&&(identical(other.previewGeneratorId, previewGeneratorId) || other.previewGeneratorId == previewGeneratorId)&&(identical(other.pianoRollGridDenom, pianoRollGridDenom) || other.pianoRollGridDenom == pianoRollGridDenom)&&(identical(other.drawStep, drawStep) || other.drawStep == drawStep)&&(identical(other.keyHeight, keyHeight) || other.keyHeight == keyHeight)&&(identical(other.loopRegion, loopRegion) || other.loopRegion == loopRegion)&&const DeepCollectionEquality().equals(other.drawTemplate, drawTemplate));
}


@override
int get hashCode => Object.hash(runtimeType,editingPatternId,tool,zoomLevelTick,snapToGrid,const DeepCollectionEquality().hash(selectedNoteIds),previewGeneratorId,pianoRollGridDenom,drawStep,keyHeight,loopRegion,const DeepCollectionEquality().hash(drawTemplate));

@override
String toString() {
  return 'PianoRollStateData(editingPatternId: $editingPatternId, tool: $tool, zoomLevelTick: $zoomLevelTick, snapToGrid: $snapToGrid, selectedNoteIds: $selectedNoteIds, previewGeneratorId: $previewGeneratorId, pianoRollGridDenom: $pianoRollGridDenom, drawStep: $drawStep, keyHeight: $keyHeight, loopRegion: $loopRegion, drawTemplate: $drawTemplate)';
}


}

/// @nodoc
abstract mixin class $PianoRollStateDataCopyWith<$Res>  {
  factory $PianoRollStateDataCopyWith(PianoRollStateData value, $Res Function(PianoRollStateData) _then) = _$PianoRollStateDataCopyWithImpl;
@useResult
$Res call({
 int? editingPatternId, PianoRollToolSelection tool, double zoomLevelTick, bool snapToGrid, ISet<int> selectedNoteIds, int? previewGeneratorId, GridSize pianoRollGridDenom, GridSize? drawStep, double keyHeight, PatternLoopRegion? loopRegion, IList<UiNote> drawTemplate
});


$PatternLoopRegionCopyWith<$Res>? get loopRegion;

}
/// @nodoc
class _$PianoRollStateDataCopyWithImpl<$Res>
    implements $PianoRollStateDataCopyWith<$Res> {
  _$PianoRollStateDataCopyWithImpl(this._self, this._then);

  final PianoRollStateData _self;
  final $Res Function(PianoRollStateData) _then;

/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? editingPatternId = freezed,Object? tool = null,Object? zoomLevelTick = null,Object? snapToGrid = null,Object? selectedNoteIds = null,Object? previewGeneratorId = freezed,Object? pianoRollGridDenom = null,Object? drawStep = freezed,Object? keyHeight = null,Object? loopRegion = freezed,Object? drawTemplate = null,}) {
  return _then(_self.copyWith(
editingPatternId: freezed == editingPatternId ? _self.editingPatternId : editingPatternId // ignore: cast_nullable_to_non_nullable
as int?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as PianoRollToolSelection,zoomLevelTick: null == zoomLevelTick ? _self.zoomLevelTick : zoomLevelTick // ignore: cast_nullable_to_non_nullable
as double,snapToGrid: null == snapToGrid ? _self.snapToGrid : snapToGrid // ignore: cast_nullable_to_non_nullable
as bool,selectedNoteIds: null == selectedNoteIds ? _self.selectedNoteIds : selectedNoteIds // ignore: cast_nullable_to_non_nullable
as ISet<int>,previewGeneratorId: freezed == previewGeneratorId ? _self.previewGeneratorId : previewGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,pianoRollGridDenom: null == pianoRollGridDenom ? _self.pianoRollGridDenom : pianoRollGridDenom // ignore: cast_nullable_to_non_nullable
as GridSize,drawStep: freezed == drawStep ? _self.drawStep : drawStep // ignore: cast_nullable_to_non_nullable
as GridSize?,keyHeight: null == keyHeight ? _self.keyHeight : keyHeight // ignore: cast_nullable_to_non_nullable
as double,loopRegion: freezed == loopRegion ? _self.loopRegion : loopRegion // ignore: cast_nullable_to_non_nullable
as PatternLoopRegion?,drawTemplate: null == drawTemplate ? _self.drawTemplate : drawTemplate // ignore: cast_nullable_to_non_nullable
as IList<UiNote>,
  ));
}
/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PatternLoopRegionCopyWith<$Res>? get loopRegion {
    if (_self.loopRegion == null) {
    return null;
  }

  return $PatternLoopRegionCopyWith<$Res>(_self.loopRegion!, (value) {
    return _then(_self.copyWith(loopRegion: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  bool snapToGrid,  ISet<int> selectedNoteIds,  int? previewGeneratorId,  GridSize pianoRollGridDenom,  GridSize? drawStep,  double keyHeight,  PatternLoopRegion? loopRegion,  IList<UiNote> drawTemplate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PianoRollStateData() when $default != null:
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId,_that.pianoRollGridDenom,_that.drawStep,_that.keyHeight,_that.loopRegion,_that.drawTemplate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  bool snapToGrid,  ISet<int> selectedNoteIds,  int? previewGeneratorId,  GridSize pianoRollGridDenom,  GridSize? drawStep,  double keyHeight,  PatternLoopRegion? loopRegion,  IList<UiNote> drawTemplate)  $default,) {final _that = this;
switch (_that) {
case _PianoRollStateData():
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId,_that.pianoRollGridDenom,_that.drawStep,_that.keyHeight,_that.loopRegion,_that.drawTemplate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? editingPatternId,  PianoRollToolSelection tool,  double zoomLevelTick,  bool snapToGrid,  ISet<int> selectedNoteIds,  int? previewGeneratorId,  GridSize pianoRollGridDenom,  GridSize? drawStep,  double keyHeight,  PatternLoopRegion? loopRegion,  IList<UiNote> drawTemplate)?  $default,) {final _that = this;
switch (_that) {
case _PianoRollStateData() when $default != null:
return $default(_that.editingPatternId,_that.tool,_that.zoomLevelTick,_that.snapToGrid,_that.selectedNoteIds,_that.previewGeneratorId,_that.pianoRollGridDenom,_that.drawStep,_that.keyHeight,_that.loopRegion,_that.drawTemplate);case _:
  return null;

}
}

}

/// @nodoc


class _PianoRollStateData extends PianoRollStateData {
  const _PianoRollStateData({this.editingPatternId = null, this.tool = PianoRollToolSelection.grab, this.zoomLevelTick = defaultPianoRollZoom, this.snapToGrid = false, this.selectedNoteIds = const ISetConst<int>({}), this.previewGeneratorId = null, this.pianoRollGridDenom = GridSize.quarter, this.drawStep = null, this.keyHeight = 20.0, this.loopRegion = null, this.drawTemplate = const IListConst<UiNote>([])}): super._();
  

@override@JsonKey() final  int? editingPatternId;
@override@JsonKey() final  PianoRollToolSelection tool;
@override@JsonKey() final  double zoomLevelTick;
@override@JsonKey() final  bool snapToGrid;
@override@JsonKey() final  ISet<int> selectedNoteIds;
@override@JsonKey() final  int? previewGeneratorId;
/// Visual grid drawn behind the notes.
@override@JsonKey() final  GridSize pianoRollGridDenom;
/// Step that drawing, moving, and resizing snap to, or null to follow the
/// grid, so a one-beat grid can still place half-beat notes.
@override@JsonKey() final  GridSize? drawStep;
/// Height of one key row, in pixels.
@override@JsonKey() final  double keyHeight;
/// Loop region for pattern playback; the whole pattern loops when null.
@override@JsonKey() final  PatternLoopRegion? loopRegion;
/// Notes the draw tool stamps: the latest selection, like FL Studio.
@override@JsonKey() final  IList<UiNote> drawTemplate;

/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PianoRollStateDataCopyWith<_PianoRollStateData> get copyWith => __$PianoRollStateDataCopyWithImpl<_PianoRollStateData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PianoRollStateData&&(identical(other.editingPatternId, editingPatternId) || other.editingPatternId == editingPatternId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.zoomLevelTick, zoomLevelTick) || other.zoomLevelTick == zoomLevelTick)&&(identical(other.snapToGrid, snapToGrid) || other.snapToGrid == snapToGrid)&&const DeepCollectionEquality().equals(other.selectedNoteIds, selectedNoteIds)&&(identical(other.previewGeneratorId, previewGeneratorId) || other.previewGeneratorId == previewGeneratorId)&&(identical(other.pianoRollGridDenom, pianoRollGridDenom) || other.pianoRollGridDenom == pianoRollGridDenom)&&(identical(other.drawStep, drawStep) || other.drawStep == drawStep)&&(identical(other.keyHeight, keyHeight) || other.keyHeight == keyHeight)&&(identical(other.loopRegion, loopRegion) || other.loopRegion == loopRegion)&&const DeepCollectionEquality().equals(other.drawTemplate, drawTemplate));
}


@override
int get hashCode => Object.hash(runtimeType,editingPatternId,tool,zoomLevelTick,snapToGrid,const DeepCollectionEquality().hash(selectedNoteIds),previewGeneratorId,pianoRollGridDenom,drawStep,keyHeight,loopRegion,const DeepCollectionEquality().hash(drawTemplate));

@override
String toString() {
  return 'PianoRollStateData(editingPatternId: $editingPatternId, tool: $tool, zoomLevelTick: $zoomLevelTick, snapToGrid: $snapToGrid, selectedNoteIds: $selectedNoteIds, previewGeneratorId: $previewGeneratorId, pianoRollGridDenom: $pianoRollGridDenom, drawStep: $drawStep, keyHeight: $keyHeight, loopRegion: $loopRegion, drawTemplate: $drawTemplate)';
}


}

/// @nodoc
abstract mixin class _$PianoRollStateDataCopyWith<$Res> implements $PianoRollStateDataCopyWith<$Res> {
  factory _$PianoRollStateDataCopyWith(_PianoRollStateData value, $Res Function(_PianoRollStateData) _then) = __$PianoRollStateDataCopyWithImpl;
@override @useResult
$Res call({
 int? editingPatternId, PianoRollToolSelection tool, double zoomLevelTick, bool snapToGrid, ISet<int> selectedNoteIds, int? previewGeneratorId, GridSize pianoRollGridDenom, GridSize? drawStep, double keyHeight, PatternLoopRegion? loopRegion, IList<UiNote> drawTemplate
});


@override $PatternLoopRegionCopyWith<$Res>? get loopRegion;

}
/// @nodoc
class __$PianoRollStateDataCopyWithImpl<$Res>
    implements _$PianoRollStateDataCopyWith<$Res> {
  __$PianoRollStateDataCopyWithImpl(this._self, this._then);

  final _PianoRollStateData _self;
  final $Res Function(_PianoRollStateData) _then;

/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? editingPatternId = freezed,Object? tool = null,Object? zoomLevelTick = null,Object? snapToGrid = null,Object? selectedNoteIds = null,Object? previewGeneratorId = freezed,Object? pianoRollGridDenom = null,Object? drawStep = freezed,Object? keyHeight = null,Object? loopRegion = freezed,Object? drawTemplate = null,}) {
  return _then(_PianoRollStateData(
editingPatternId: freezed == editingPatternId ? _self.editingPatternId : editingPatternId // ignore: cast_nullable_to_non_nullable
as int?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as PianoRollToolSelection,zoomLevelTick: null == zoomLevelTick ? _self.zoomLevelTick : zoomLevelTick // ignore: cast_nullable_to_non_nullable
as double,snapToGrid: null == snapToGrid ? _self.snapToGrid : snapToGrid // ignore: cast_nullable_to_non_nullable
as bool,selectedNoteIds: null == selectedNoteIds ? _self.selectedNoteIds : selectedNoteIds // ignore: cast_nullable_to_non_nullable
as ISet<int>,previewGeneratorId: freezed == previewGeneratorId ? _self.previewGeneratorId : previewGeneratorId // ignore: cast_nullable_to_non_nullable
as int?,pianoRollGridDenom: null == pianoRollGridDenom ? _self.pianoRollGridDenom : pianoRollGridDenom // ignore: cast_nullable_to_non_nullable
as GridSize,drawStep: freezed == drawStep ? _self.drawStep : drawStep // ignore: cast_nullable_to_non_nullable
as GridSize?,keyHeight: null == keyHeight ? _self.keyHeight : keyHeight // ignore: cast_nullable_to_non_nullable
as double,loopRegion: freezed == loopRegion ? _self.loopRegion : loopRegion // ignore: cast_nullable_to_non_nullable
as PatternLoopRegion?,drawTemplate: null == drawTemplate ? _self.drawTemplate : drawTemplate // ignore: cast_nullable_to_non_nullable
as IList<UiNote>,
  ));
}

/// Create a copy of PianoRollStateData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PatternLoopRegionCopyWith<$Res>? get loopRegion {
    if (_self.loopRegion == null) {
    return null;
  }

  return $PatternLoopRegionCopyWith<$Res>(_self.loopRegion!, (value) {
    return _then(_self.copyWith(loopRegion: value));
  });
}
}

// dart format on
