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
mixin _$ShortcutKey implements DiagnosticableTreeMixin {

/// Stored id of the user's binding, e.g. `trackList.tool.delete`.
 String get id;/// Message id of the command's name, shown in menus and key bindings.
 String get titleId;/// Message id of the group the command is listed under.
 String get categoryId;
/// Create a copy of ShortcutKey
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShortcutKeyCopyWith<ShortcutKey> get copyWith => _$ShortcutKeyCopyWithImpl<ShortcutKey>(this as ShortcutKey, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShortcutKey'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('titleId', titleId))..add(DiagnosticsProperty('categoryId', categoryId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShortcutKey&&(identical(other.id, id) || other.id == id)&&(identical(other.titleId, titleId) || other.titleId == titleId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId));
}


@override
int get hashCode => Object.hash(runtimeType,id,titleId,categoryId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShortcutKey(id: $id, titleId: $titleId, categoryId: $categoryId)';
}


}

/// @nodoc
abstract mixin class $ShortcutKeyCopyWith<$Res>  {
  factory $ShortcutKeyCopyWith(ShortcutKey value, $Res Function(ShortcutKey) _then) = _$ShortcutKeyCopyWithImpl;
@useResult
$Res call({
 String id, String titleId, String categoryId
});




}
/// @nodoc
class _$ShortcutKeyCopyWithImpl<$Res>
    implements $ShortcutKeyCopyWith<$Res> {
  _$ShortcutKeyCopyWithImpl(this._self, this._then);

  final ShortcutKey _self;
  final $Res Function(ShortcutKey) _then;

/// Create a copy of ShortcutKey
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? titleId = null,Object? categoryId = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,titleId: null == titleId ? _self.titleId : titleId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ShortcutKey].
extension ShortcutKeyPatterns on ShortcutKey {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShortcutKey value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShortcutKey() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShortcutKey value)  $default,){
final _that = this;
switch (_that) {
case _ShortcutKey():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShortcutKey value)?  $default,){
final _that = this;
switch (_that) {
case _ShortcutKey() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String titleId,  String categoryId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShortcutKey() when $default != null:
return $default(_that.id,_that.titleId,_that.categoryId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String titleId,  String categoryId)  $default,) {final _that = this;
switch (_that) {
case _ShortcutKey():
return $default(_that.id,_that.titleId,_that.categoryId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String titleId,  String categoryId)?  $default,) {final _that = this;
switch (_that) {
case _ShortcutKey() when $default != null:
return $default(_that.id,_that.titleId,_that.categoryId);case _:
  return null;

}
}

}

/// @nodoc


class _ShortcutKey with DiagnosticableTreeMixin implements ShortcutKey {
  const _ShortcutKey({required this.id, required this.titleId, required this.categoryId});
  

/// Stored id of the user's binding, e.g. `trackList.tool.delete`.
@override final  String id;
/// Message id of the command's name, shown in menus and key bindings.
@override final  String titleId;
/// Message id of the group the command is listed under.
@override final  String categoryId;

/// Create a copy of ShortcutKey
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShortcutKeyCopyWith<_ShortcutKey> get copyWith => __$ShortcutKeyCopyWithImpl<_ShortcutKey>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShortcutKey'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('titleId', titleId))..add(DiagnosticsProperty('categoryId', categoryId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShortcutKey&&(identical(other.id, id) || other.id == id)&&(identical(other.titleId, titleId) || other.titleId == titleId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId));
}


@override
int get hashCode => Object.hash(runtimeType,id,titleId,categoryId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ShortcutKey(id: $id, titleId: $titleId, categoryId: $categoryId)';
}


}

/// @nodoc
abstract mixin class _$ShortcutKeyCopyWith<$Res> implements $ShortcutKeyCopyWith<$Res> {
  factory _$ShortcutKeyCopyWith(_ShortcutKey value, $Res Function(_ShortcutKey) _then) = __$ShortcutKeyCopyWithImpl;
@override @useResult
$Res call({
 String id, String titleId, String categoryId
});




}
/// @nodoc
class __$ShortcutKeyCopyWithImpl<$Res>
    implements _$ShortcutKeyCopyWith<$Res> {
  __$ShortcutKeyCopyWithImpl(this._self, this._then);

  final _ShortcutKey _self;
  final $Res Function(_ShortcutKey) _then;

/// Create a copy of ShortcutKey
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? titleId = null,Object? categoryId = null,}) {
  return _then(_ShortcutKey(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,titleId: null == titleId ? _self.titleId : titleId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ShortcutChord implements DiagnosticableTreeMixin {

 int get logicalKeyId; bool get control; bool get shift; bool get alt; bool get meta;
/// Create a copy of ShortcutChord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShortcutChordCopyWith<ShortcutChord> get copyWith => _$ShortcutChordCopyWithImpl<ShortcutChord>(this as ShortcutChord, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShortcutChord'))
    ..add(DiagnosticsProperty('logicalKeyId', logicalKeyId))..add(DiagnosticsProperty('control', control))..add(DiagnosticsProperty('shift', shift))..add(DiagnosticsProperty('alt', alt))..add(DiagnosticsProperty('meta', meta));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShortcutChord&&(identical(other.logicalKeyId, logicalKeyId) || other.logicalKeyId == logicalKeyId)&&(identical(other.control, control) || other.control == control)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.alt, alt) || other.alt == alt)&&(identical(other.meta, meta) || other.meta == meta));
}


@override
int get hashCode => Object.hash(runtimeType,logicalKeyId,control,shift,alt,meta);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
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


class _ShortcutChord extends ShortcutChord with DiagnosticableTreeMixin {
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
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShortcutChord'))
    ..add(DiagnosticsProperty('logicalKeyId', logicalKeyId))..add(DiagnosticsProperty('control', control))..add(DiagnosticsProperty('shift', shift))..add(DiagnosticsProperty('alt', alt))..add(DiagnosticsProperty('meta', meta));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShortcutChord&&(identical(other.logicalKeyId, logicalKeyId) || other.logicalKeyId == logicalKeyId)&&(identical(other.control, control) || other.control == control)&&(identical(other.shift, shift) || other.shift == shift)&&(identical(other.alt, alt) || other.alt == alt)&&(identical(other.meta, meta) || other.meta == meta));
}


@override
int get hashCode => Object.hash(runtimeType,logicalKeyId,control,shift,alt,meta);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
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
mixin _$ShortcutManagerState implements DiagnosticableTreeMixin {

 IMap<String, ShortcutChord> get overrides; bool get isInitialized;
/// Create a copy of ShortcutManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShortcutManagerStateCopyWith<ShortcutManagerState> get copyWith => _$ShortcutManagerStateCopyWithImpl<ShortcutManagerState>(this as ShortcutManagerState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShortcutManagerState'))
    ..add(DiagnosticsProperty('overrides', overrides))..add(DiagnosticsProperty('isInitialized', isInitialized));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShortcutManagerState&&(identical(other.overrides, overrides) || other.overrides == overrides)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,overrides,isInitialized);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
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


class _ShortcutManagerState with DiagnosticableTreeMixin implements ShortcutManagerState {
  const _ShortcutManagerState({this.overrides = const IMapConst<String, ShortcutChord>({}), this.isInitialized = false});
  

@override@JsonKey() final  IMap<String, ShortcutChord> overrides;
@override@JsonKey() final  bool isInitialized;

/// Create a copy of ShortcutManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShortcutManagerStateCopyWith<_ShortcutManagerState> get copyWith => __$ShortcutManagerStateCopyWithImpl<_ShortcutManagerState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ShortcutManagerState'))
    ..add(DiagnosticsProperty('overrides', overrides))..add(DiagnosticsProperty('isInitialized', isInitialized));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShortcutManagerState&&(identical(other.overrides, overrides) || other.overrides == overrides)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,overrides,isInitialized);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
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
