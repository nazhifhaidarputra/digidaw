// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pattern.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiNote {

 int get id; int get startTick; int get duration; int get key; int get velocity; double get probability; int get microOffset; bool get mute;
/// Create a copy of UiNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiNoteCopyWith<UiNote> get copyWith => _$UiNoteCopyWithImpl<UiNote>(this as UiNote, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiNote&&(identical(other.id, id) || other.id == id)&&(identical(other.startTick, startTick) || other.startTick == startTick)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.key, key) || other.key == key)&&(identical(other.velocity, velocity) || other.velocity == velocity)&&(identical(other.probability, probability) || other.probability == probability)&&(identical(other.microOffset, microOffset) || other.microOffset == microOffset)&&(identical(other.mute, mute) || other.mute == mute));
}


@override
int get hashCode => Object.hash(runtimeType,id,startTick,duration,key,velocity,probability,microOffset,mute);

@override
String toString() {
  return 'UiNote(id: $id, startTick: $startTick, duration: $duration, key: $key, velocity: $velocity, probability: $probability, microOffset: $microOffset, mute: $mute)';
}


}

/// @nodoc
abstract mixin class $UiNoteCopyWith<$Res>  {
  factory $UiNoteCopyWith(UiNote value, $Res Function(UiNote) _then) = _$UiNoteCopyWithImpl;
@useResult
$Res call({
 int id, int startTick, int duration, int key, int velocity, double probability, int microOffset, bool mute
});




}
/// @nodoc
class _$UiNoteCopyWithImpl<$Res>
    implements $UiNoteCopyWith<$Res> {
  _$UiNoteCopyWithImpl(this._self, this._then);

  final UiNote _self;
  final $Res Function(UiNote) _then;

/// Create a copy of UiNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? startTick = null,Object? duration = null,Object? key = null,Object? velocity = null,Object? probability = null,Object? microOffset = null,Object? mute = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,startTick: null == startTick ? _self.startTick : startTick // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as int,velocity: null == velocity ? _self.velocity : velocity // ignore: cast_nullable_to_non_nullable
as int,probability: null == probability ? _self.probability : probability // ignore: cast_nullable_to_non_nullable
as double,microOffset: null == microOffset ? _self.microOffset : microOffset // ignore: cast_nullable_to_non_nullable
as int,mute: null == mute ? _self.mute : mute // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UiNote].
extension UiNotePatterns on UiNote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiNote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiNote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiNote value)  $default,){
final _that = this;
switch (_that) {
case _UiNote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiNote value)?  $default,){
final _that = this;
switch (_that) {
case _UiNote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int startTick,  int duration,  int key,  int velocity,  double probability,  int microOffset,  bool mute)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiNote() when $default != null:
return $default(_that.id,_that.startTick,_that.duration,_that.key,_that.velocity,_that.probability,_that.microOffset,_that.mute);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int startTick,  int duration,  int key,  int velocity,  double probability,  int microOffset,  bool mute)  $default,) {final _that = this;
switch (_that) {
case _UiNote():
return $default(_that.id,_that.startTick,_that.duration,_that.key,_that.velocity,_that.probability,_that.microOffset,_that.mute);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int startTick,  int duration,  int key,  int velocity,  double probability,  int microOffset,  bool mute)?  $default,) {final _that = this;
switch (_that) {
case _UiNote() when $default != null:
return $default(_that.id,_that.startTick,_that.duration,_that.key,_that.velocity,_that.probability,_that.microOffset,_that.mute);case _:
  return null;

}
}

}

/// @nodoc


class _UiNote implements UiNote {
  const _UiNote({required this.id, required this.startTick, required this.duration, required this.key, required this.velocity, required this.probability, required this.microOffset, required this.mute});
  

@override final  int id;
@override final  int startTick;
@override final  int duration;
@override final  int key;
@override final  int velocity;
@override final  double probability;
@override final  int microOffset;
@override final  bool mute;

/// Create a copy of UiNote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiNoteCopyWith<_UiNote> get copyWith => __$UiNoteCopyWithImpl<_UiNote>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiNote&&(identical(other.id, id) || other.id == id)&&(identical(other.startTick, startTick) || other.startTick == startTick)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.key, key) || other.key == key)&&(identical(other.velocity, velocity) || other.velocity == velocity)&&(identical(other.probability, probability) || other.probability == probability)&&(identical(other.microOffset, microOffset) || other.microOffset == microOffset)&&(identical(other.mute, mute) || other.mute == mute));
}


@override
int get hashCode => Object.hash(runtimeType,id,startTick,duration,key,velocity,probability,microOffset,mute);

@override
String toString() {
  return 'UiNote(id: $id, startTick: $startTick, duration: $duration, key: $key, velocity: $velocity, probability: $probability, microOffset: $microOffset, mute: $mute)';
}


}

/// @nodoc
abstract mixin class _$UiNoteCopyWith<$Res> implements $UiNoteCopyWith<$Res> {
  factory _$UiNoteCopyWith(_UiNote value, $Res Function(_UiNote) _then) = __$UiNoteCopyWithImpl;
@override @useResult
$Res call({
 int id, int startTick, int duration, int key, int velocity, double probability, int microOffset, bool mute
});




}
/// @nodoc
class __$UiNoteCopyWithImpl<$Res>
    implements _$UiNoteCopyWith<$Res> {
  __$UiNoteCopyWithImpl(this._self, this._then);

  final _UiNote _self;
  final $Res Function(_UiNote) _then;

/// Create a copy of UiNote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? startTick = null,Object? duration = null,Object? key = null,Object? velocity = null,Object? probability = null,Object? microOffset = null,Object? mute = null,}) {
  return _then(_UiNote(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,startTick: null == startTick ? _self.startTick : startTick // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as int,velocity: null == velocity ? _self.velocity : velocity // ignore: cast_nullable_to_non_nullable
as int,probability: null == probability ? _self.probability : probability // ignore: cast_nullable_to_non_nullable
as double,microOffset: null == microOffset ? _self.microOffset : microOffset // ignore: cast_nullable_to_non_nullable
as int,mute: null == mute ? _self.mute : mute // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$UiPattern {

 int get id; String get name; int get lengthTicks; List<UiNote> get notes;
/// Create a copy of UiPattern
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPatternCopyWith<UiPattern> get copyWith => _$UiPatternCopyWithImpl<UiPattern>(this as UiPattern, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPattern&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.lengthTicks, lengthTicks) || other.lengthTicks == lengthTicks)&&const DeepCollectionEquality().equals(other.notes, notes));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,lengthTicks,const DeepCollectionEquality().hash(notes));

@override
String toString() {
  return 'UiPattern(id: $id, name: $name, lengthTicks: $lengthTicks, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $UiPatternCopyWith<$Res>  {
  factory $UiPatternCopyWith(UiPattern value, $Res Function(UiPattern) _then) = _$UiPatternCopyWithImpl;
@useResult
$Res call({
 int id, String name, int lengthTicks, List<UiNote> notes
});




}
/// @nodoc
class _$UiPatternCopyWithImpl<$Res>
    implements $UiPatternCopyWith<$Res> {
  _$UiPatternCopyWithImpl(this._self, this._then);

  final UiPattern _self;
  final $Res Function(UiPattern) _then;

/// Create a copy of UiPattern
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? lengthTicks = null,Object? notes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lengthTicks: null == lengthTicks ? _self.lengthTicks : lengthTicks // ignore: cast_nullable_to_non_nullable
as int,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as List<UiNote>,
  ));
}

}


/// Adds pattern-matching-related methods to [UiPattern].
extension UiPatternPatterns on UiPattern {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiPattern value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiPattern() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiPattern value)  $default,){
final _that = this;
switch (_that) {
case _UiPattern():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiPattern value)?  $default,){
final _that = this;
switch (_that) {
case _UiPattern() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int lengthTicks,  List<UiNote> notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiPattern() when $default != null:
return $default(_that.id,_that.name,_that.lengthTicks,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int lengthTicks,  List<UiNote> notes)  $default,) {final _that = this;
switch (_that) {
case _UiPattern():
return $default(_that.id,_that.name,_that.lengthTicks,_that.notes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int lengthTicks,  List<UiNote> notes)?  $default,) {final _that = this;
switch (_that) {
case _UiPattern() when $default != null:
return $default(_that.id,_that.name,_that.lengthTicks,_that.notes);case _:
  return null;

}
}

}

/// @nodoc


class _UiPattern implements UiPattern {
  const _UiPattern({required this.id, required this.name, required this.lengthTicks, required final  List<UiNote> notes}): _notes = notes;
  

@override final  int id;
@override final  String name;
@override final  int lengthTicks;
 final  List<UiNote> _notes;
@override List<UiNote> get notes {
  if (_notes is EqualUnmodifiableListView) return _notes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notes);
}


/// Create a copy of UiPattern
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiPatternCopyWith<_UiPattern> get copyWith => __$UiPatternCopyWithImpl<_UiPattern>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiPattern&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.lengthTicks, lengthTicks) || other.lengthTicks == lengthTicks)&&const DeepCollectionEquality().equals(other._notes, _notes));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,lengthTicks,const DeepCollectionEquality().hash(_notes));

@override
String toString() {
  return 'UiPattern(id: $id, name: $name, lengthTicks: $lengthTicks, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$UiPatternCopyWith<$Res> implements $UiPatternCopyWith<$Res> {
  factory _$UiPatternCopyWith(_UiPattern value, $Res Function(_UiPattern) _then) = __$UiPatternCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int lengthTicks, List<UiNote> notes
});




}
/// @nodoc
class __$UiPatternCopyWithImpl<$Res>
    implements _$UiPatternCopyWith<$Res> {
  __$UiPatternCopyWithImpl(this._self, this._then);

  final _UiPattern _self;
  final $Res Function(_UiPattern) _then;

/// Create a copy of UiPattern
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? lengthTicks = null,Object? notes = null,}) {
  return _then(_UiPattern(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lengthTicks: null == lengthTicks ? _self.lengthTicks : lengthTicks // ignore: cast_nullable_to_non_nullable
as int,notes: null == notes ? _self._notes : notes // ignore: cast_nullable_to_non_nullable
as List<UiNote>,
  ));
}


}

// dart format on
