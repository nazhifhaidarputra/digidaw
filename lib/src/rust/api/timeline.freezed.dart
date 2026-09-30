// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'timeline.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiCueMarker {

 int get id; String get name; int get tick; String get color;
/// Create a copy of UiCueMarker
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiCueMarkerCopyWith<UiCueMarker> get copyWith => _$UiCueMarkerCopyWithImpl<UiCueMarker>(this as UiCueMarker, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiCueMarker&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.tick, tick) || other.tick == tick)&&(identical(other.color, color) || other.color == color));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,tick,color);

@override
String toString() {
  return 'UiCueMarker(id: $id, name: $name, tick: $tick, color: $color)';
}


}

/// @nodoc
abstract mixin class $UiCueMarkerCopyWith<$Res>  {
  factory $UiCueMarkerCopyWith(UiCueMarker value, $Res Function(UiCueMarker) _then) = _$UiCueMarkerCopyWithImpl;
@useResult
$Res call({
 int id, String name, int tick, String color
});




}
/// @nodoc
class _$UiCueMarkerCopyWithImpl<$Res>
    implements $UiCueMarkerCopyWith<$Res> {
  _$UiCueMarkerCopyWithImpl(this._self, this._then);

  final UiCueMarker _self;
  final $Res Function(UiCueMarker) _then;

/// Create a copy of UiCueMarker
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? tick = null,Object? color = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tick: null == tick ? _self.tick : tick // ignore: cast_nullable_to_non_nullable
as int,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiCueMarker].
extension UiCueMarkerPatterns on UiCueMarker {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiCueMarker value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiCueMarker() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiCueMarker value)  $default,){
final _that = this;
switch (_that) {
case _UiCueMarker():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiCueMarker value)?  $default,){
final _that = this;
switch (_that) {
case _UiCueMarker() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int tick,  String color)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiCueMarker() when $default != null:
return $default(_that.id,_that.name,_that.tick,_that.color);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int tick,  String color)  $default,) {final _that = this;
switch (_that) {
case _UiCueMarker():
return $default(_that.id,_that.name,_that.tick,_that.color);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int tick,  String color)?  $default,) {final _that = this;
switch (_that) {
case _UiCueMarker() when $default != null:
return $default(_that.id,_that.name,_that.tick,_that.color);case _:
  return null;

}
}

}

/// @nodoc


class _UiCueMarker implements UiCueMarker {
  const _UiCueMarker({required this.id, required this.name, required this.tick, required this.color});
  

@override final  int id;
@override final  String name;
@override final  int tick;
@override final  String color;

/// Create a copy of UiCueMarker
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiCueMarkerCopyWith<_UiCueMarker> get copyWith => __$UiCueMarkerCopyWithImpl<_UiCueMarker>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiCueMarker&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.tick, tick) || other.tick == tick)&&(identical(other.color, color) || other.color == color));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,tick,color);

@override
String toString() {
  return 'UiCueMarker(id: $id, name: $name, tick: $tick, color: $color)';
}


}

/// @nodoc
abstract mixin class _$UiCueMarkerCopyWith<$Res> implements $UiCueMarkerCopyWith<$Res> {
  factory _$UiCueMarkerCopyWith(_UiCueMarker value, $Res Function(_UiCueMarker) _then) = __$UiCueMarkerCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int tick, String color
});




}
/// @nodoc
class __$UiCueMarkerCopyWithImpl<$Res>
    implements _$UiCueMarkerCopyWith<$Res> {
  __$UiCueMarkerCopyWithImpl(this._self, this._then);

  final _UiCueMarker _self;
  final $Res Function(_UiCueMarker) _then;

/// Create a copy of UiCueMarker
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? tick = null,Object? color = null,}) {
  return _then(_UiCueMarker(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tick: null == tick ? _self.tick : tick // ignore: cast_nullable_to_non_nullable
as int,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiLoopRegion {

 int get startTick; int get endTick;
/// Create a copy of UiLoopRegion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiLoopRegionCopyWith<UiLoopRegion> get copyWith => _$UiLoopRegionCopyWithImpl<UiLoopRegion>(this as UiLoopRegion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiLoopRegion&&(identical(other.startTick, startTick) || other.startTick == startTick)&&(identical(other.endTick, endTick) || other.endTick == endTick));
}


@override
int get hashCode => Object.hash(runtimeType,startTick,endTick);

@override
String toString() {
  return 'UiLoopRegion(startTick: $startTick, endTick: $endTick)';
}


}

/// @nodoc
abstract mixin class $UiLoopRegionCopyWith<$Res>  {
  factory $UiLoopRegionCopyWith(UiLoopRegion value, $Res Function(UiLoopRegion) _then) = _$UiLoopRegionCopyWithImpl;
@useResult
$Res call({
 int startTick, int endTick
});




}
/// @nodoc
class _$UiLoopRegionCopyWithImpl<$Res>
    implements $UiLoopRegionCopyWith<$Res> {
  _$UiLoopRegionCopyWithImpl(this._self, this._then);

  final UiLoopRegion _self;
  final $Res Function(UiLoopRegion) _then;

/// Create a copy of UiLoopRegion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startTick = null,Object? endTick = null,}) {
  return _then(_self.copyWith(
startTick: null == startTick ? _self.startTick : startTick // ignore: cast_nullable_to_non_nullable
as int,endTick: null == endTick ? _self.endTick : endTick // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiLoopRegion].
extension UiLoopRegionPatterns on UiLoopRegion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiLoopRegion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiLoopRegion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiLoopRegion value)  $default,){
final _that = this;
switch (_that) {
case _UiLoopRegion():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiLoopRegion value)?  $default,){
final _that = this;
switch (_that) {
case _UiLoopRegion() when $default != null:
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
case _UiLoopRegion() when $default != null:
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
case _UiLoopRegion():
return $default(_that.startTick,_that.endTick);}
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
case _UiLoopRegion() when $default != null:
return $default(_that.startTick,_that.endTick);case _:
  return null;

}
}

}

/// @nodoc


class _UiLoopRegion implements UiLoopRegion {
  const _UiLoopRegion({required this.startTick, required this.endTick});
  

@override final  int startTick;
@override final  int endTick;

/// Create a copy of UiLoopRegion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiLoopRegionCopyWith<_UiLoopRegion> get copyWith => __$UiLoopRegionCopyWithImpl<_UiLoopRegion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiLoopRegion&&(identical(other.startTick, startTick) || other.startTick == startTick)&&(identical(other.endTick, endTick) || other.endTick == endTick));
}


@override
int get hashCode => Object.hash(runtimeType,startTick,endTick);

@override
String toString() {
  return 'UiLoopRegion(startTick: $startTick, endTick: $endTick)';
}


}

/// @nodoc
abstract mixin class _$UiLoopRegionCopyWith<$Res> implements $UiLoopRegionCopyWith<$Res> {
  factory _$UiLoopRegionCopyWith(_UiLoopRegion value, $Res Function(_UiLoopRegion) _then) = __$UiLoopRegionCopyWithImpl;
@override @useResult
$Res call({
 int startTick, int endTick
});




}
/// @nodoc
class __$UiLoopRegionCopyWithImpl<$Res>
    implements _$UiLoopRegionCopyWith<$Res> {
  __$UiLoopRegionCopyWithImpl(this._self, this._then);

  final _UiLoopRegion _self;
  final $Res Function(_UiLoopRegion) _then;

/// Create a copy of UiLoopRegion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startTick = null,Object? endTick = null,}) {
  return _then(_UiLoopRegion(
startTick: null == startTick ? _self.startTick : startTick // ignore: cast_nullable_to_non_nullable
as int,endTick: null == endTick ? _self.endTick : endTick // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiTimelineState {

 UiLoopRegion? get loopRegion; List<UiCueMarker> get markers;
/// Create a copy of UiTimelineState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiTimelineStateCopyWith<UiTimelineState> get copyWith => _$UiTimelineStateCopyWithImpl<UiTimelineState>(this as UiTimelineState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiTimelineState&&(identical(other.loopRegion, loopRegion) || other.loopRegion == loopRegion)&&const DeepCollectionEquality().equals(other.markers, markers));
}


@override
int get hashCode => Object.hash(runtimeType,loopRegion,const DeepCollectionEquality().hash(markers));

@override
String toString() {
  return 'UiTimelineState(loopRegion: $loopRegion, markers: $markers)';
}


}

/// @nodoc
abstract mixin class $UiTimelineStateCopyWith<$Res>  {
  factory $UiTimelineStateCopyWith(UiTimelineState value, $Res Function(UiTimelineState) _then) = _$UiTimelineStateCopyWithImpl;
@useResult
$Res call({
 UiLoopRegion? loopRegion, List<UiCueMarker> markers
});


$UiLoopRegionCopyWith<$Res>? get loopRegion;

}
/// @nodoc
class _$UiTimelineStateCopyWithImpl<$Res>
    implements $UiTimelineStateCopyWith<$Res> {
  _$UiTimelineStateCopyWithImpl(this._self, this._then);

  final UiTimelineState _self;
  final $Res Function(UiTimelineState) _then;

/// Create a copy of UiTimelineState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loopRegion = freezed,Object? markers = null,}) {
  return _then(_self.copyWith(
loopRegion: freezed == loopRegion ? _self.loopRegion : loopRegion // ignore: cast_nullable_to_non_nullable
as UiLoopRegion?,markers: null == markers ? _self.markers : markers // ignore: cast_nullable_to_non_nullable
as List<UiCueMarker>,
  ));
}
/// Create a copy of UiTimelineState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLoopRegionCopyWith<$Res>? get loopRegion {
    if (_self.loopRegion == null) {
    return null;
  }

  return $UiLoopRegionCopyWith<$Res>(_self.loopRegion!, (value) {
    return _then(_self.copyWith(loopRegion: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiTimelineState].
extension UiTimelineStatePatterns on UiTimelineState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiTimelineState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiTimelineState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiTimelineState value)  $default,){
final _that = this;
switch (_that) {
case _UiTimelineState():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiTimelineState value)?  $default,){
final _that = this;
switch (_that) {
case _UiTimelineState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiLoopRegion? loopRegion,  List<UiCueMarker> markers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiTimelineState() when $default != null:
return $default(_that.loopRegion,_that.markers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiLoopRegion? loopRegion,  List<UiCueMarker> markers)  $default,) {final _that = this;
switch (_that) {
case _UiTimelineState():
return $default(_that.loopRegion,_that.markers);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiLoopRegion? loopRegion,  List<UiCueMarker> markers)?  $default,) {final _that = this;
switch (_that) {
case _UiTimelineState() when $default != null:
return $default(_that.loopRegion,_that.markers);case _:
  return null;

}
}

}

/// @nodoc


class _UiTimelineState extends UiTimelineState {
  const _UiTimelineState({this.loopRegion, required final  List<UiCueMarker> markers}): _markers = markers,super._();
  

@override final  UiLoopRegion? loopRegion;
 final  List<UiCueMarker> _markers;
@override List<UiCueMarker> get markers {
  if (_markers is EqualUnmodifiableListView) return _markers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_markers);
}


/// Create a copy of UiTimelineState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiTimelineStateCopyWith<_UiTimelineState> get copyWith => __$UiTimelineStateCopyWithImpl<_UiTimelineState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiTimelineState&&(identical(other.loopRegion, loopRegion) || other.loopRegion == loopRegion)&&const DeepCollectionEquality().equals(other._markers, _markers));
}


@override
int get hashCode => Object.hash(runtimeType,loopRegion,const DeepCollectionEquality().hash(_markers));

@override
String toString() {
  return 'UiTimelineState(loopRegion: $loopRegion, markers: $markers)';
}


}

/// @nodoc
abstract mixin class _$UiTimelineStateCopyWith<$Res> implements $UiTimelineStateCopyWith<$Res> {
  factory _$UiTimelineStateCopyWith(_UiTimelineState value, $Res Function(_UiTimelineState) _then) = __$UiTimelineStateCopyWithImpl;
@override @useResult
$Res call({
 UiLoopRegion? loopRegion, List<UiCueMarker> markers
});


@override $UiLoopRegionCopyWith<$Res>? get loopRegion;

}
/// @nodoc
class __$UiTimelineStateCopyWithImpl<$Res>
    implements _$UiTimelineStateCopyWith<$Res> {
  __$UiTimelineStateCopyWithImpl(this._self, this._then);

  final _UiTimelineState _self;
  final $Res Function(_UiTimelineState) _then;

/// Create a copy of UiTimelineState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loopRegion = freezed,Object? markers = null,}) {
  return _then(_UiTimelineState(
loopRegion: freezed == loopRegion ? _self.loopRegion : loopRegion // ignore: cast_nullable_to_non_nullable
as UiLoopRegion?,markers: null == markers ? _self._markers : markers // ignore: cast_nullable_to_non_nullable
as List<UiCueMarker>,
  ));
}

/// Create a copy of UiTimelineState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLoopRegionCopyWith<$Res>? get loopRegion {
    if (_self.loopRegion == null) {
    return null;
  }

  return $UiLoopRegionCopyWith<$Res>(_self.loopRegion!, (value) {
    return _then(_self.copyWith(loopRegion: value));
  });
}
}

// dart format on
