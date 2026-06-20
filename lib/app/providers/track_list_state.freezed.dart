// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrackListState {

/// The track that currently "owns" the clip selection.
 int? get selectedTrackId;/// IDs of clips that are currently selected (always from [selectedTrackId]).
 IList<int> get selectedClipIds;/// The clip that should receive keyboard focus (last clicked).
 int? get focusClipId;/// Per-track pixel heights for the arranger rows, keyed by track ID.
 IMap<int, int> get trackIdHeightMap;
/// Create a copy of TrackListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackListStateCopyWith<TrackListState> get copyWith => _$TrackListStateCopyWithImpl<TrackListState>(this as TrackListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackListState&&(identical(other.selectedTrackId, selectedTrackId) || other.selectedTrackId == selectedTrackId)&&const DeepCollectionEquality().equals(other.selectedClipIds, selectedClipIds)&&(identical(other.focusClipId, focusClipId) || other.focusClipId == focusClipId)&&(identical(other.trackIdHeightMap, trackIdHeightMap) || other.trackIdHeightMap == trackIdHeightMap));
}


@override
int get hashCode => Object.hash(runtimeType,selectedTrackId,const DeepCollectionEquality().hash(selectedClipIds),focusClipId,trackIdHeightMap);

@override
String toString() {
  return 'TrackListState(selectedTrackId: $selectedTrackId, selectedClipIds: $selectedClipIds, focusClipId: $focusClipId, trackIdHeightMap: $trackIdHeightMap)';
}


}

/// @nodoc
abstract mixin class $TrackListStateCopyWith<$Res>  {
  factory $TrackListStateCopyWith(TrackListState value, $Res Function(TrackListState) _then) = _$TrackListStateCopyWithImpl;
@useResult
$Res call({
 int? selectedTrackId, IList<int> selectedClipIds, int? focusClipId, IMap<int, int> trackIdHeightMap
});




}
/// @nodoc
class _$TrackListStateCopyWithImpl<$Res>
    implements $TrackListStateCopyWith<$Res> {
  _$TrackListStateCopyWithImpl(this._self, this._then);

  final TrackListState _self;
  final $Res Function(TrackListState) _then;

/// Create a copy of TrackListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectedTrackId = freezed,Object? selectedClipIds = null,Object? focusClipId = freezed,Object? trackIdHeightMap = null,}) {
  return _then(_self.copyWith(
selectedTrackId: freezed == selectedTrackId ? _self.selectedTrackId : selectedTrackId // ignore: cast_nullable_to_non_nullable
as int?,selectedClipIds: null == selectedClipIds ? _self.selectedClipIds : selectedClipIds // ignore: cast_nullable_to_non_nullable
as IList<int>,focusClipId: freezed == focusClipId ? _self.focusClipId : focusClipId // ignore: cast_nullable_to_non_nullable
as int?,trackIdHeightMap: null == trackIdHeightMap ? _self.trackIdHeightMap : trackIdHeightMap // ignore: cast_nullable_to_non_nullable
as IMap<int, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackListState].
extension TrackListStatePatterns on TrackListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackListState value)  $default,){
final _that = this;
switch (_that) {
case _TrackListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackListState value)?  $default,){
final _that = this;
switch (_that) {
case _TrackListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? selectedTrackId,  IList<int> selectedClipIds,  int? focusClipId,  IMap<int, int> trackIdHeightMap)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackListState() when $default != null:
return $default(_that.selectedTrackId,_that.selectedClipIds,_that.focusClipId,_that.trackIdHeightMap);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? selectedTrackId,  IList<int> selectedClipIds,  int? focusClipId,  IMap<int, int> trackIdHeightMap)  $default,) {final _that = this;
switch (_that) {
case _TrackListState():
return $default(_that.selectedTrackId,_that.selectedClipIds,_that.focusClipId,_that.trackIdHeightMap);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? selectedTrackId,  IList<int> selectedClipIds,  int? focusClipId,  IMap<int, int> trackIdHeightMap)?  $default,) {final _that = this;
switch (_that) {
case _TrackListState() when $default != null:
return $default(_that.selectedTrackId,_that.selectedClipIds,_that.focusClipId,_that.trackIdHeightMap);case _:
  return null;

}
}

}

/// @nodoc


class _TrackListState implements TrackListState {
  const _TrackListState({this.selectedTrackId, this.selectedClipIds = const IListConst<int>([]), this.focusClipId, this.trackIdHeightMap = const IMapConst<int, int>({})});
  

/// The track that currently "owns" the clip selection.
@override final  int? selectedTrackId;
/// IDs of clips that are currently selected (always from [selectedTrackId]).
@override@JsonKey() final  IList<int> selectedClipIds;
/// The clip that should receive keyboard focus (last clicked).
@override final  int? focusClipId;
/// Per-track pixel heights for the arranger rows, keyed by track ID.
@override@JsonKey() final  IMap<int, int> trackIdHeightMap;

/// Create a copy of TrackListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackListStateCopyWith<_TrackListState> get copyWith => __$TrackListStateCopyWithImpl<_TrackListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackListState&&(identical(other.selectedTrackId, selectedTrackId) || other.selectedTrackId == selectedTrackId)&&const DeepCollectionEquality().equals(other.selectedClipIds, selectedClipIds)&&(identical(other.focusClipId, focusClipId) || other.focusClipId == focusClipId)&&(identical(other.trackIdHeightMap, trackIdHeightMap) || other.trackIdHeightMap == trackIdHeightMap));
}


@override
int get hashCode => Object.hash(runtimeType,selectedTrackId,const DeepCollectionEquality().hash(selectedClipIds),focusClipId,trackIdHeightMap);

@override
String toString() {
  return 'TrackListState(selectedTrackId: $selectedTrackId, selectedClipIds: $selectedClipIds, focusClipId: $focusClipId, trackIdHeightMap: $trackIdHeightMap)';
}


}

/// @nodoc
abstract mixin class _$TrackListStateCopyWith<$Res> implements $TrackListStateCopyWith<$Res> {
  factory _$TrackListStateCopyWith(_TrackListState value, $Res Function(_TrackListState) _then) = __$TrackListStateCopyWithImpl;
@override @useResult
$Res call({
 int? selectedTrackId, IList<int> selectedClipIds, int? focusClipId, IMap<int, int> trackIdHeightMap
});




}
/// @nodoc
class __$TrackListStateCopyWithImpl<$Res>
    implements _$TrackListStateCopyWith<$Res> {
  __$TrackListStateCopyWithImpl(this._self, this._then);

  final _TrackListState _self;
  final $Res Function(_TrackListState) _then;

/// Create a copy of TrackListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectedTrackId = freezed,Object? selectedClipIds = null,Object? focusClipId = freezed,Object? trackIdHeightMap = null,}) {
  return _then(_TrackListState(
selectedTrackId: freezed == selectedTrackId ? _self.selectedTrackId : selectedTrackId // ignore: cast_nullable_to_non_nullable
as int?,selectedClipIds: null == selectedClipIds ? _self.selectedClipIds : selectedClipIds // ignore: cast_nullable_to_non_nullable
as IList<int>,focusClipId: freezed == focusClipId ? _self.focusClipId : focusClipId // ignore: cast_nullable_to_non_nullable
as int?,trackIdHeightMap: null == trackIdHeightMap ? _self.trackIdHeightMap : trackIdHeightMap // ignore: cast_nullable_to_non_nullable
as IMap<int, int>,
  ));
}


}

// dart format on
