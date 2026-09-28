// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shortcut_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ShortcutChord {

 int get logicalKeyId; bool get control; bool get shift; bool get alt; bool get meta;
/// Create a copy of ShortcutChord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShortcutChordCopyWith<ShortcutChord> get copyWith => _$ShortcutChordCopyWithImpl<ShortcutChord>(this as ShortcutChord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShortcutChord&&(identical(other.logicalKeyId, logicalKeyId) || other.logicalKeyId == logicalKeyId)&&(identical(other.control, control) || other.control == control)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.alt, alt) || other.alt == alt)&&(identical(other.meta, meta) || other.meta == meta));
}


@override
int get hashCode => Object.hash(runtimeType,logicalKeyId,control,shift,alt,meta);

@override
String toString() {
  return 'ShortcutChord(logicalKeyId: $logicalKeyId, control: $control, shift: $shift, alt: $alt, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $ShortcutChordCopyWith<$Res>  {
  factory $ShortcutChordCopyWith(ShortcutChord value, $Res Function(ShortcutChord) _then) = _$ShortcutChordCopyWithImpl;
@useResult
$Res call({
 int logicalKeyId, bool control, bool shift, bool alt, bool meta
});




}
/// @nodoc
class _$ShortcutChordCopyWithImpl<$Res>
    implements $ShortcutChordCopyWith<$Res> {
  _$ShortcutChordCopyWithImpl(this._self, this._then);

  final ShortcutChord _self;
  final $Res Function(ShortcutChord) _then;

/// Create a copy of ShortcutChord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? logicalKeyId = null,Object? control = null,Object? shift = null,Object? alt = null,Object? meta = null,}) {
  return _then(_self.copyWith(
logicalKeyId: null == logicalKeyId ? _self.logicalKeyId : logicalKeyId // ignore: cast_nullable_to_non_nullable
as int,control: null == control ? _self.control : control // ignore: cast_nullable_to_non_nullable
as bool,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as bool,alt: null == alt ? _self.alt : alt // ignore: cast_nullable_to_non_nullable
as bool,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ShortcutChord].
extension ShortcutChordPatterns on ShortcutChord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShortcutChord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShortcutChord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShortcutChord value)  $default,){
final _that = this;
switch (_that) {
case _ShortcutChord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShortcutChord value)?  $default,){
final _that = this;
switch (_that) {
case _ShortcutChord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int logicalKeyId,  bool control,  bool shift,  bool alt,  bool meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShortcutChord() when $default != null:
return $default(_that.logicalKeyId,_that.control,_that.shift,_that.alt,_that.meta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int logicalKeyId,  bool control,  bool shift,  bool alt,  bool meta)  $default,) {final _that = this;
switch (_that) {
case _ShortcutChord():
return $default(_that.logicalKeyId,_that.control,_that.shift,_that.alt,_that.meta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int logicalKeyId,  bool control,  bool shift,  bool alt,  bool meta)?  $default,) {final _that = this;
switch (_that) {
case _ShortcutChord() when $default != null:
return $default(_that.logicalKeyId,_that.control,_that.shift,_that.alt,_that.meta);case _:
  return null;

}
}

}

/// @nodoc


class _ShortcutChord extends ShortcutChord {
  const _ShortcutChord({required this.logicalKeyId, this.control = false, this.shift = false, this.alt = false, this.meta = false}): super._();
  

@override final  int logicalKeyId;
@override@JsonKey() final  bool control;
@override@JsonKey() final  bool shift;
@override@JsonKey() final  bool alt;
@override@JsonKey() final  bool meta;

/// Create a copy of ShortcutChord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShortcutChordCopyWith<_ShortcutChord> get copyWith => __$ShortcutChordCopyWithImpl<_ShortcutChord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShortcutChord&&(identical(other.logicalKeyId, logicalKeyId) || other.logicalKeyId == logicalKeyId)&&(identical(other.control, control) || other.control == control)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.alt, alt) || other.alt == alt)&&(identical(other.meta, meta) || other.meta == meta));
}


@override
int get hashCode => Object.hash(runtimeType,logicalKeyId,control,shift,alt,meta);

@override
String toString() {
  return 'ShortcutChord(logicalKeyId: $logicalKeyId, control: $control, shift: $shift, alt: $alt, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$ShortcutChordCopyWith<$Res> implements $ShortcutChordCopyWith<$Res> {
  factory _$ShortcutChordCopyWith(_ShortcutChord value, $Res Function(_ShortcutChord) _then) = __$ShortcutChordCopyWithImpl;
@override @useResult
$Res call({
 int logicalKeyId, bool control, bool shift, bool alt, bool meta
});




}
/// @nodoc
class __$ShortcutChordCopyWithImpl<$Res>
    implements _$ShortcutChordCopyWith<$Res> {
  __$ShortcutChordCopyWithImpl(this._self, this._then);

  final _ShortcutChord _self;
  final $Res Function(_ShortcutChord) _then;

/// Create a copy of ShortcutChord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? logicalKeyId = null,Object? control = null,Object? shift = null,Object? alt = null,Object? meta = null,}) {
  return _then(_ShortcutChord(
logicalKeyId: null == logicalKeyId ? _self.logicalKeyId : logicalKeyId // ignore: cast_nullable_to_non_nullable
as int,control: null == control ? _self.control : control // ignore: cast_nullable_to_non_nullable
as bool,shift: null == shift ? _self.shift : shift // ignore: cast_nullable_to_non_nullable
as bool,alt: null == alt ? _self.alt : alt // ignore: cast_nullable_to_non_nullable
as bool,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ShortcutManagerState {

 IMap<String, ShortcutChord> get overrides; bool get isInitialized;
/// Create a copy of ShortcutManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShortcutManagerStateCopyWith<ShortcutManagerState> get copyWith => _$ShortcutManagerStateCopyWithImpl<ShortcutManagerState>(this as ShortcutManagerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShortcutManagerState&&(identical(other.overrides, overrides) || other.overrides == overrides)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,overrides,isInitialized);

@override
String toString() {
  return 'ShortcutManagerState(overrides: $overrides, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class $ShortcutManagerStateCopyWith<$Res>  {
  factory $ShortcutManagerStateCopyWith(ShortcutManagerState value, $Res Function(ShortcutManagerState) _then) = _$ShortcutManagerStateCopyWithImpl;
@useResult
$Res call({
 IMap<String, ShortcutChord> overrides, bool isInitialized
});




}
/// @nodoc
class _$ShortcutManagerStateCopyWithImpl<$Res>
    implements $ShortcutManagerStateCopyWith<$Res> {
  _$ShortcutManagerStateCopyWithImpl(this._self, this._then);

  final ShortcutManagerState _self;
  final $Res Function(ShortcutManagerState) _then;

/// Create a copy of ShortcutManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? overrides = null,Object? isInitialized = null,}) {
  return _then(_self.copyWith(
overrides: null == overrides ? _self.overrides : overrides // ignore: cast_nullable_to_non_nullable
as IMap<String, ShortcutChord>,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ShortcutManagerState].
extension ShortcutManagerStatePatterns on ShortcutManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShortcutManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShortcutManagerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShortcutManagerState value)  $default,){
final _that = this;
switch (_that) {
case _ShortcutManagerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShortcutManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _ShortcutManagerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IMap<String, ShortcutChord> overrides,  bool isInitialized)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShortcutManagerState() when $default != null:
return $default(_that.overrides,_that.isInitialized);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IMap<String, ShortcutChord> overrides,  bool isInitialized)  $default,) {final _that = this;
switch (_that) {
case _ShortcutManagerState():
return $default(_that.overrides,_that.isInitialized);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IMap<String, ShortcutChord> overrides,  bool isInitialized)?  $default,) {final _that = this;
switch (_that) {
case _ShortcutManagerState() when $default != null:
return $default(_that.overrides,_that.isInitialized);case _:
  return null;

}
}

}

/// @nodoc


class _ShortcutManagerState implements ShortcutManagerState {
  const _ShortcutManagerState({this.overrides = const IMapConst<String, ShortcutChord>({}), this.isInitialized = false});
  

@override@JsonKey() final  IMap<String, ShortcutChord> overrides;
@override@JsonKey() final  bool isInitialized;

/// Create a copy of ShortcutManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShortcutManagerStateCopyWith<_ShortcutManagerState> get copyWith => __$ShortcutManagerStateCopyWithImpl<_ShortcutManagerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShortcutManagerState&&(identical(other.overrides, overrides) || other.overrides == overrides)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,overrides,isInitialized);

@override
String toString() {
  return 'ShortcutManagerState(overrides: $overrides, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class _$ShortcutManagerStateCopyWith<$Res> implements $ShortcutManagerStateCopyWith<$Res> {
  factory _$ShortcutManagerStateCopyWith(_ShortcutManagerState value, $Res Function(_ShortcutManagerState) _then) = __$ShortcutManagerStateCopyWithImpl;
@override @useResult
$Res call({
 IMap<String, ShortcutChord> overrides, bool isInitialized
});




}
/// @nodoc
class __$ShortcutManagerStateCopyWithImpl<$Res>
    implements _$ShortcutManagerStateCopyWith<$Res> {
  __$ShortcutManagerStateCopyWithImpl(this._self, this._then);

  final _ShortcutManagerState _self;
  final $Res Function(_ShortcutManagerState) _then;

/// Create a copy of ShortcutManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? overrides = null,Object? isInitialized = null,}) {
  return _then(_ShortcutManagerState(
overrides: null == overrides ? _self.overrides : overrides // ignore: cast_nullable_to_non_nullable
as IMap<String, ShortcutChord>,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
