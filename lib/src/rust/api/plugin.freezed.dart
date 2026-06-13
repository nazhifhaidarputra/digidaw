// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiEffectParameterSnapshot {

 UiEffectTarget get target; int get effectId; List<UiParameterValue> get parameters;
/// Create a copy of UiEffectParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEffectParameterSnapshotCopyWith<UiEffectParameterSnapshot> get copyWith => _$UiEffectParameterSnapshotCopyWithImpl<UiEffectParameterSnapshot>(this as UiEffectParameterSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEffectParameterSnapshot&&(identical(other.target, target) || other.target == target)&&(identical(other.effectId, effectId) || other.effectId == effectId)&&const DeepCollectionEquality().equals(other.parameters, parameters));
}


@override
int get hashCode => Object.hash(runtimeType,target,effectId,const DeepCollectionEquality().hash(parameters));

@override
String toString() {
  return 'UiEffectParameterSnapshot(target: $target, effectId: $effectId, parameters: $parameters)';
}


}

/// @nodoc
abstract mixin class $UiEffectParameterSnapshotCopyWith<$Res>  {
  factory $UiEffectParameterSnapshotCopyWith(UiEffectParameterSnapshot value, $Res Function(UiEffectParameterSnapshot) _then) = _$UiEffectParameterSnapshotCopyWithImpl;
@useResult
$Res call({
 UiEffectTarget target, int effectId, List<UiParameterValue> parameters
});


$UiEffectTargetCopyWith<$Res> get target;

}
/// @nodoc
class _$UiEffectParameterSnapshotCopyWithImpl<$Res>
    implements $UiEffectParameterSnapshotCopyWith<$Res> {
  _$UiEffectParameterSnapshotCopyWithImpl(this._self, this._then);

  final UiEffectParameterSnapshot _self;
  final $Res Function(UiEffectParameterSnapshot) _then;

/// Create a copy of UiEffectParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? effectId = null,Object? parameters = null,}) {
  return _then(_self.copyWith(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as UiEffectTarget,effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,parameters: null == parameters ? _self.parameters : parameters // ignore: cast_nullable_to_non_nullable
as List<UiParameterValue>,
  ));
}
/// Create a copy of UiEffectParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiEffectTargetCopyWith<$Res> get target {
  
  return $UiEffectTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiEffectParameterSnapshot].
extension UiEffectParameterSnapshotPatterns on UiEffectParameterSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiEffectParameterSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiEffectParameterSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiEffectParameterSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _UiEffectParameterSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiEffectParameterSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _UiEffectParameterSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiEffectTarget target,  int effectId,  List<UiParameterValue> parameters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiEffectParameterSnapshot() when $default != null:
return $default(_that.target,_that.effectId,_that.parameters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiEffectTarget target,  int effectId,  List<UiParameterValue> parameters)  $default,) {final _that = this;
switch (_that) {
case _UiEffectParameterSnapshot():
return $default(_that.target,_that.effectId,_that.parameters);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiEffectTarget target,  int effectId,  List<UiParameterValue> parameters)?  $default,) {final _that = this;
switch (_that) {
case _UiEffectParameterSnapshot() when $default != null:
return $default(_that.target,_that.effectId,_that.parameters);case _:
  return null;

}
}

}

/// @nodoc


class _UiEffectParameterSnapshot implements UiEffectParameterSnapshot {
  const _UiEffectParameterSnapshot({required this.target, required this.effectId, required final  List<UiParameterValue> parameters}): _parameters = parameters;
  

@override final  UiEffectTarget target;
@override final  int effectId;
 final  List<UiParameterValue> _parameters;
@override List<UiParameterValue> get parameters {
  if (_parameters is EqualUnmodifiableListView) return _parameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parameters);
}


/// Create a copy of UiEffectParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiEffectParameterSnapshotCopyWith<_UiEffectParameterSnapshot> get copyWith => __$UiEffectParameterSnapshotCopyWithImpl<_UiEffectParameterSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiEffectParameterSnapshot&&(identical(other.target, target) || other.target == target)&&(identical(other.effectId, effectId) || other.effectId == effectId)&&const DeepCollectionEquality().equals(other._parameters, _parameters));
}


@override
int get hashCode => Object.hash(runtimeType,target,effectId,const DeepCollectionEquality().hash(_parameters));

@override
String toString() {
  return 'UiEffectParameterSnapshot(target: $target, effectId: $effectId, parameters: $parameters)';
}


}

/// @nodoc
abstract mixin class _$UiEffectParameterSnapshotCopyWith<$Res> implements $UiEffectParameterSnapshotCopyWith<$Res> {
  factory _$UiEffectParameterSnapshotCopyWith(_UiEffectParameterSnapshot value, $Res Function(_UiEffectParameterSnapshot) _then) = __$UiEffectParameterSnapshotCopyWithImpl;
@override @useResult
$Res call({
 UiEffectTarget target, int effectId, List<UiParameterValue> parameters
});


@override $UiEffectTargetCopyWith<$Res> get target;

}
/// @nodoc
class __$UiEffectParameterSnapshotCopyWithImpl<$Res>
    implements _$UiEffectParameterSnapshotCopyWith<$Res> {
  __$UiEffectParameterSnapshotCopyWithImpl(this._self, this._then);

  final _UiEffectParameterSnapshot _self;
  final $Res Function(_UiEffectParameterSnapshot) _then;

/// Create a copy of UiEffectParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? effectId = null,Object? parameters = null,}) {
  return _then(_UiEffectParameterSnapshot(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as UiEffectTarget,effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,parameters: null == parameters ? _self._parameters : parameters // ignore: cast_nullable_to_non_nullable
as List<UiParameterValue>,
  ));
}

/// Create a copy of UiEffectParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiEffectTargetCopyWith<$Res> get target {
  
  return $UiEffectTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

/// @nodoc
mixin _$UiEffectTarget {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEffectTarget);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiEffectTarget()';
}


}

/// @nodoc
class $UiEffectTargetCopyWith<$Res>  {
$UiEffectTargetCopyWith(UiEffectTarget _, $Res Function(UiEffectTarget) __);
}


/// Adds pattern-matching-related methods to [UiEffectTarget].
extension UiEffectTargetPatterns on UiEffectTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiEffectTarget_Track value)?  track,TResult Function( UiEffectTarget_Master value)?  master,TResult Function( UiEffectTarget_Bus value)?  bus,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiEffectTarget_Track() when track != null:
return track(_that);case UiEffectTarget_Master() when master != null:
return master(_that);case UiEffectTarget_Bus() when bus != null:
return bus(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiEffectTarget_Track value)  track,required TResult Function( UiEffectTarget_Master value)  master,required TResult Function( UiEffectTarget_Bus value)  bus,}){
final _that = this;
switch (_that) {
case UiEffectTarget_Track():
return track(_that);case UiEffectTarget_Master():
return master(_that);case UiEffectTarget_Bus():
return bus(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiEffectTarget_Track value)?  track,TResult? Function( UiEffectTarget_Master value)?  master,TResult? Function( UiEffectTarget_Bus value)?  bus,}){
final _that = this;
switch (_that) {
case UiEffectTarget_Track() when track != null:
return track(_that);case UiEffectTarget_Master() when master != null:
return master(_that);case UiEffectTarget_Bus() when bus != null:
return bus(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int field0)?  track,TResult Function()?  master,TResult Function( int field0)?  bus,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiEffectTarget_Track() when track != null:
return track(_that.field0);case UiEffectTarget_Master() when master != null:
return master();case UiEffectTarget_Bus() when bus != null:
return bus(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int field0)  track,required TResult Function()  master,required TResult Function( int field0)  bus,}) {final _that = this;
switch (_that) {
case UiEffectTarget_Track():
return track(_that.field0);case UiEffectTarget_Master():
return master();case UiEffectTarget_Bus():
return bus(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int field0)?  track,TResult? Function()?  master,TResult? Function( int field0)?  bus,}) {final _that = this;
switch (_that) {
case UiEffectTarget_Track() when track != null:
return track(_that.field0);case UiEffectTarget_Master() when master != null:
return master();case UiEffectTarget_Bus() when bus != null:
return bus(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class UiEffectTarget_Track extends UiEffectTarget {
  const UiEffectTarget_Track(this.field0): super._();
  

 final  int field0;

/// Create a copy of UiEffectTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEffectTarget_TrackCopyWith<UiEffectTarget_Track> get copyWith => _$UiEffectTarget_TrackCopyWithImpl<UiEffectTarget_Track>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEffectTarget_Track&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiEffectTarget.track(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiEffectTarget_TrackCopyWith<$Res> implements $UiEffectTargetCopyWith<$Res> {
  factory $UiEffectTarget_TrackCopyWith(UiEffectTarget_Track value, $Res Function(UiEffectTarget_Track) _then) = _$UiEffectTarget_TrackCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiEffectTarget_TrackCopyWithImpl<$Res>
    implements $UiEffectTarget_TrackCopyWith<$Res> {
  _$UiEffectTarget_TrackCopyWithImpl(this._self, this._then);

  final UiEffectTarget_Track _self;
  final $Res Function(UiEffectTarget_Track) _then;

/// Create a copy of UiEffectTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiEffectTarget_Track(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiEffectTarget_Master extends UiEffectTarget {
  const UiEffectTarget_Master(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEffectTarget_Master);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiEffectTarget.master()';
}


}




/// @nodoc


class UiEffectTarget_Bus extends UiEffectTarget {
  const UiEffectTarget_Bus(this.field0): super._();
  

 final  int field0;

/// Create a copy of UiEffectTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEffectTarget_BusCopyWith<UiEffectTarget_Bus> get copyWith => _$UiEffectTarget_BusCopyWithImpl<UiEffectTarget_Bus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEffectTarget_Bus&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiEffectTarget.bus(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiEffectTarget_BusCopyWith<$Res> implements $UiEffectTargetCopyWith<$Res> {
  factory $UiEffectTarget_BusCopyWith(UiEffectTarget_Bus value, $Res Function(UiEffectTarget_Bus) _then) = _$UiEffectTarget_BusCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiEffectTarget_BusCopyWithImpl<$Res>
    implements $UiEffectTarget_BusCopyWith<$Res> {
  _$UiEffectTarget_BusCopyWithImpl(this._self, this._then);

  final UiEffectTarget_Bus _self;
  final $Res Function(UiEffectTarget_Bus) _then;

/// Create a copy of UiEffectTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiEffectTarget_Bus(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UiGeneratorParameterSnapshot {

 int get generatorId; List<UiParameterValue> get parameters;
/// Create a copy of UiGeneratorParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiGeneratorParameterSnapshotCopyWith<UiGeneratorParameterSnapshot> get copyWith => _$UiGeneratorParameterSnapshotCopyWithImpl<UiGeneratorParameterSnapshot>(this as UiGeneratorParameterSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiGeneratorParameterSnapshot&&(identical(other.generatorId, generatorId) || other.generatorId == generatorId)&&const DeepCollectionEquality().equals(other.parameters, parameters));
}


@override
int get hashCode => Object.hash(runtimeType,generatorId,const DeepCollectionEquality().hash(parameters));

@override
String toString() {
  return 'UiGeneratorParameterSnapshot(generatorId: $generatorId, parameters: $parameters)';
}


}

/// @nodoc
abstract mixin class $UiGeneratorParameterSnapshotCopyWith<$Res>  {
  factory $UiGeneratorParameterSnapshotCopyWith(UiGeneratorParameterSnapshot value, $Res Function(UiGeneratorParameterSnapshot) _then) = _$UiGeneratorParameterSnapshotCopyWithImpl;
@useResult
$Res call({
 int generatorId, List<UiParameterValue> parameters
});




}
/// @nodoc
class _$UiGeneratorParameterSnapshotCopyWithImpl<$Res>
    implements $UiGeneratorParameterSnapshotCopyWith<$Res> {
  _$UiGeneratorParameterSnapshotCopyWithImpl(this._self, this._then);

  final UiGeneratorParameterSnapshot _self;
  final $Res Function(UiGeneratorParameterSnapshot) _then;

/// Create a copy of UiGeneratorParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generatorId = null,Object? parameters = null,}) {
  return _then(_self.copyWith(
generatorId: null == generatorId ? _self.generatorId : generatorId // ignore: cast_nullable_to_non_nullable
as int,parameters: null == parameters ? _self.parameters : parameters // ignore: cast_nullable_to_non_nullable
as List<UiParameterValue>,
  ));
}

}


/// Adds pattern-matching-related methods to [UiGeneratorParameterSnapshot].
extension UiGeneratorParameterSnapshotPatterns on UiGeneratorParameterSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiGeneratorParameterSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiGeneratorParameterSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiGeneratorParameterSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _UiGeneratorParameterSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiGeneratorParameterSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _UiGeneratorParameterSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int generatorId,  List<UiParameterValue> parameters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiGeneratorParameterSnapshot() when $default != null:
return $default(_that.generatorId,_that.parameters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int generatorId,  List<UiParameterValue> parameters)  $default,) {final _that = this;
switch (_that) {
case _UiGeneratorParameterSnapshot():
return $default(_that.generatorId,_that.parameters);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int generatorId,  List<UiParameterValue> parameters)?  $default,) {final _that = this;
switch (_that) {
case _UiGeneratorParameterSnapshot() when $default != null:
return $default(_that.generatorId,_that.parameters);case _:
  return null;

}
}

}

/// @nodoc


class _UiGeneratorParameterSnapshot implements UiGeneratorParameterSnapshot {
  const _UiGeneratorParameterSnapshot({required this.generatorId, required final  List<UiParameterValue> parameters}): _parameters = parameters;
  

@override final  int generatorId;
 final  List<UiParameterValue> _parameters;
@override List<UiParameterValue> get parameters {
  if (_parameters is EqualUnmodifiableListView) return _parameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parameters);
}


/// Create a copy of UiGeneratorParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiGeneratorParameterSnapshotCopyWith<_UiGeneratorParameterSnapshot> get copyWith => __$UiGeneratorParameterSnapshotCopyWithImpl<_UiGeneratorParameterSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiGeneratorParameterSnapshot&&(identical(other.generatorId, generatorId) || other.generatorId == generatorId)&&const DeepCollectionEquality().equals(other._parameters, _parameters));
}


@override
int get hashCode => Object.hash(runtimeType,generatorId,const DeepCollectionEquality().hash(_parameters));

@override
String toString() {
  return 'UiGeneratorParameterSnapshot(generatorId: $generatorId, parameters: $parameters)';
}


}

/// @nodoc
abstract mixin class _$UiGeneratorParameterSnapshotCopyWith<$Res> implements $UiGeneratorParameterSnapshotCopyWith<$Res> {
  factory _$UiGeneratorParameterSnapshotCopyWith(_UiGeneratorParameterSnapshot value, $Res Function(_UiGeneratorParameterSnapshot) _then) = __$UiGeneratorParameterSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int generatorId, List<UiParameterValue> parameters
});




}
/// @nodoc
class __$UiGeneratorParameterSnapshotCopyWithImpl<$Res>
    implements _$UiGeneratorParameterSnapshotCopyWith<$Res> {
  __$UiGeneratorParameterSnapshotCopyWithImpl(this._self, this._then);

  final _UiGeneratorParameterSnapshot _self;
  final $Res Function(_UiGeneratorParameterSnapshot) _then;

/// Create a copy of UiGeneratorParameterSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generatorId = null,Object? parameters = null,}) {
  return _then(_UiGeneratorParameterSnapshot(
generatorId: null == generatorId ? _self.generatorId : generatorId // ignore: cast_nullable_to_non_nullable
as int,parameters: null == parameters ? _self._parameters : parameters // ignore: cast_nullable_to_non_nullable
as List<UiParameterValue>,
  ));
}


}

/// @nodoc
mixin _$UiParamId {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiParamId&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'UiParamId(field0: $field0)';
}


}

/// @nodoc
class $UiParamIdCopyWith<$Res>  {
$UiParamIdCopyWith(UiParamId _, $Res Function(UiParamId) __);
}


/// Adds pattern-matching-related methods to [UiParamId].
extension UiParamIdPatterns on UiParamId {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiParamId_Id value)?  id,TResult Function( UiParamId_Path value)?  path,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiParamId_Id() when id != null:
return id(_that);case UiParamId_Path() when path != null:
return path(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiParamId_Id value)  id,required TResult Function( UiParamId_Path value)  path,}){
final _that = this;
switch (_that) {
case UiParamId_Id():
return id(_that);case UiParamId_Path():
return path(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiParamId_Id value)?  id,TResult? Function( UiParamId_Path value)?  path,}){
final _that = this;
switch (_that) {
case UiParamId_Id() when id != null:
return id(_that);case UiParamId_Path() when path != null:
return path(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int field0)?  id,TResult Function( String field0)?  path,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiParamId_Id() when id != null:
return id(_that.field0);case UiParamId_Path() when path != null:
return path(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int field0)  id,required TResult Function( String field0)  path,}) {final _that = this;
switch (_that) {
case UiParamId_Id():
return id(_that.field0);case UiParamId_Path():
return path(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int field0)?  id,TResult? Function( String field0)?  path,}) {final _that = this;
switch (_that) {
case UiParamId_Id() when id != null:
return id(_that.field0);case UiParamId_Path() when path != null:
return path(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class UiParamId_Id extends UiParamId {
  const UiParamId_Id(this.field0): super._();
  

@override final  int field0;

/// Create a copy of UiParamId
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiParamId_IdCopyWith<UiParamId_Id> get copyWith => _$UiParamId_IdCopyWithImpl<UiParamId_Id>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiParamId_Id&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiParamId.id(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiParamId_IdCopyWith<$Res> implements $UiParamIdCopyWith<$Res> {
  factory $UiParamId_IdCopyWith(UiParamId_Id value, $Res Function(UiParamId_Id) _then) = _$UiParamId_IdCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiParamId_IdCopyWithImpl<$Res>
    implements $UiParamId_IdCopyWith<$Res> {
  _$UiParamId_IdCopyWithImpl(this._self, this._then);

  final UiParamId_Id _self;
  final $Res Function(UiParamId_Id) _then;

/// Create a copy of UiParamId
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiParamId_Id(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiParamId_Path extends UiParamId {
  const UiParamId_Path(this.field0): super._();
  

@override final  String field0;

/// Create a copy of UiParamId
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiParamId_PathCopyWith<UiParamId_Path> get copyWith => _$UiParamId_PathCopyWithImpl<UiParamId_Path>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiParamId_Path&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiParamId.path(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiParamId_PathCopyWith<$Res> implements $UiParamIdCopyWith<$Res> {
  factory $UiParamId_PathCopyWith(UiParamId_Path value, $Res Function(UiParamId_Path) _then) = _$UiParamId_PathCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$UiParamId_PathCopyWithImpl<$Res>
    implements $UiParamId_PathCopyWith<$Res> {
  _$UiParamId_PathCopyWithImpl(this._self, this._then);

  final UiParamId_Path _self;
  final $Res Function(UiParamId_Path) _then;

/// Create a copy of UiParamId
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiParamId_Path(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiParameterValue {

 int get paramId; double get value;
/// Create a copy of UiParameterValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiParameterValueCopyWith<UiParameterValue> get copyWith => _$UiParameterValueCopyWithImpl<UiParameterValue>(this as UiParameterValue, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiParameterValue&&(identical(other.paramId, paramId) || other.paramId == paramId)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,paramId,value);

@override
String toString() {
  return 'UiParameterValue(paramId: $paramId, value: $value)';
}


}

/// @nodoc
abstract mixin class $UiParameterValueCopyWith<$Res>  {
  factory $UiParameterValueCopyWith(UiParameterValue value, $Res Function(UiParameterValue) _then) = _$UiParameterValueCopyWithImpl;
@useResult
$Res call({
 int paramId, double value
});




}
/// @nodoc
class _$UiParameterValueCopyWithImpl<$Res>
    implements $UiParameterValueCopyWith<$Res> {
  _$UiParameterValueCopyWithImpl(this._self, this._then);

  final UiParameterValue _self;
  final $Res Function(UiParameterValue) _then;

/// Create a copy of UiParameterValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paramId = null,Object? value = null,}) {
  return _then(_self.copyWith(
paramId: null == paramId ? _self.paramId : paramId // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [UiParameterValue].
extension UiParameterValuePatterns on UiParameterValue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiParameterValue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiParameterValue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiParameterValue value)  $default,){
final _that = this;
switch (_that) {
case _UiParameterValue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiParameterValue value)?  $default,){
final _that = this;
switch (_that) {
case _UiParameterValue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int paramId,  double value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiParameterValue() when $default != null:
return $default(_that.paramId,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int paramId,  double value)  $default,) {final _that = this;
switch (_that) {
case _UiParameterValue():
return $default(_that.paramId,_that.value);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int paramId,  double value)?  $default,) {final _that = this;
switch (_that) {
case _UiParameterValue() when $default != null:
return $default(_that.paramId,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _UiParameterValue implements UiParameterValue {
  const _UiParameterValue({required this.paramId, required this.value});
  

@override final  int paramId;
@override final  double value;

/// Create a copy of UiParameterValue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiParameterValueCopyWith<_UiParameterValue> get copyWith => __$UiParameterValueCopyWithImpl<_UiParameterValue>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiParameterValue&&(identical(other.paramId, paramId) || other.paramId == paramId)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,paramId,value);

@override
String toString() {
  return 'UiParameterValue(paramId: $paramId, value: $value)';
}


}

/// @nodoc
abstract mixin class _$UiParameterValueCopyWith<$Res> implements $UiParameterValueCopyWith<$Res> {
  factory _$UiParameterValueCopyWith(_UiParameterValue value, $Res Function(_UiParameterValue) _then) = __$UiParameterValueCopyWithImpl;
@override @useResult
$Res call({
 int paramId, double value
});




}
/// @nodoc
class __$UiParameterValueCopyWithImpl<$Res>
    implements _$UiParameterValueCopyWith<$Res> {
  __$UiParameterValueCopyWithImpl(this._self, this._then);

  final _UiParameterValue _self;
  final $Res Function(_UiParameterValue) _then;

/// Create a copy of UiParameterValue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paramId = null,Object? value = null,}) {
  return _then(_UiParameterValue(
paramId: null == paramId ? _self.paramId : paramId // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$UiPluginCommandResponse {

 int get requestId; String get responseJson;
/// Create a copy of UiPluginCommandResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginCommandResponseCopyWith<UiPluginCommandResponse> get copyWith => _$UiPluginCommandResponseCopyWithImpl<UiPluginCommandResponse>(this as UiPluginCommandResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginCommandResponse&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.responseJson, responseJson) || other.responseJson == responseJson));
}


@override
int get hashCode => Object.hash(runtimeType,requestId,responseJson);

@override
String toString() {
  return 'UiPluginCommandResponse(requestId: $requestId, responseJson: $responseJson)';
}


}

/// @nodoc
abstract mixin class $UiPluginCommandResponseCopyWith<$Res>  {
  factory $UiPluginCommandResponseCopyWith(UiPluginCommandResponse value, $Res Function(UiPluginCommandResponse) _then) = _$UiPluginCommandResponseCopyWithImpl;
@useResult
$Res call({
 int requestId, String responseJson
});




}
/// @nodoc
class _$UiPluginCommandResponseCopyWithImpl<$Res>
    implements $UiPluginCommandResponseCopyWith<$Res> {
  _$UiPluginCommandResponseCopyWithImpl(this._self, this._then);

  final UiPluginCommandResponse _self;
  final $Res Function(UiPluginCommandResponse) _then;

/// Create a copy of UiPluginCommandResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? responseJson = null,}) {
  return _then(_self.copyWith(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as int,responseJson: null == responseJson ? _self.responseJson : responseJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiPluginCommandResponse].
extension UiPluginCommandResponsePatterns on UiPluginCommandResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiPluginCommandResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiPluginCommandResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiPluginCommandResponse value)  $default,){
final _that = this;
switch (_that) {
case _UiPluginCommandResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiPluginCommandResponse value)?  $default,){
final _that = this;
switch (_that) {
case _UiPluginCommandResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int requestId,  String responseJson)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiPluginCommandResponse() when $default != null:
return $default(_that.requestId,_that.responseJson);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int requestId,  String responseJson)  $default,) {final _that = this;
switch (_that) {
case _UiPluginCommandResponse():
return $default(_that.requestId,_that.responseJson);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int requestId,  String responseJson)?  $default,) {final _that = this;
switch (_that) {
case _UiPluginCommandResponse() when $default != null:
return $default(_that.requestId,_that.responseJson);case _:
  return null;

}
}

}

/// @nodoc


class _UiPluginCommandResponse implements UiPluginCommandResponse {
  const _UiPluginCommandResponse({required this.requestId, required this.responseJson});
  

@override final  int requestId;
@override final  String responseJson;

/// Create a copy of UiPluginCommandResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiPluginCommandResponseCopyWith<_UiPluginCommandResponse> get copyWith => __$UiPluginCommandResponseCopyWithImpl<_UiPluginCommandResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiPluginCommandResponse&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.responseJson, responseJson) || other.responseJson == responseJson));
}


@override
int get hashCode => Object.hash(runtimeType,requestId,responseJson);

@override
String toString() {
  return 'UiPluginCommandResponse(requestId: $requestId, responseJson: $responseJson)';
}


}

/// @nodoc
abstract mixin class _$UiPluginCommandResponseCopyWith<$Res> implements $UiPluginCommandResponseCopyWith<$Res> {
  factory _$UiPluginCommandResponseCopyWith(_UiPluginCommandResponse value, $Res Function(_UiPluginCommandResponse) _then) = __$UiPluginCommandResponseCopyWithImpl;
@override @useResult
$Res call({
 int requestId, String responseJson
});




}
/// @nodoc
class __$UiPluginCommandResponseCopyWithImpl<$Res>
    implements _$UiPluginCommandResponseCopyWith<$Res> {
  __$UiPluginCommandResponseCopyWithImpl(this._self, this._then);

  final _UiPluginCommandResponse _self;
  final $Res Function(_UiPluginCommandResponse) _then;

/// Create a copy of UiPluginCommandResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? responseJson = null,}) {
  return _then(_UiPluginCommandResponse(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as int,responseJson: null == responseJson ? _self.responseJson : responseJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiPluginInfo {

 int get id; String get name; KarbeatPluginType get pluginType;
/// Create a copy of UiPluginInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginInfoCopyWith<UiPluginInfo> get copyWith => _$UiPluginInfoCopyWithImpl<UiPluginInfo>(this as UiPluginInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.pluginType, pluginType) || other.pluginType == pluginType));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,pluginType);

@override
String toString() {
  return 'UiPluginInfo(id: $id, name: $name, pluginType: $pluginType)';
}


}

/// @nodoc
abstract mixin class $UiPluginInfoCopyWith<$Res>  {
  factory $UiPluginInfoCopyWith(UiPluginInfo value, $Res Function(UiPluginInfo) _then) = _$UiPluginInfoCopyWithImpl;
@useResult
$Res call({
 int id, String name, KarbeatPluginType pluginType
});




}
/// @nodoc
class _$UiPluginInfoCopyWithImpl<$Res>
    implements $UiPluginInfoCopyWith<$Res> {
  _$UiPluginInfoCopyWithImpl(this._self, this._then);

  final UiPluginInfo _self;
  final $Res Function(UiPluginInfo) _then;

/// Create a copy of UiPluginInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? pluginType = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,pluginType: null == pluginType ? _self.pluginType : pluginType // ignore: cast_nullable_to_non_nullable
as KarbeatPluginType,
  ));
}

}


/// Adds pattern-matching-related methods to [UiPluginInfo].
extension UiPluginInfoPatterns on UiPluginInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiPluginInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiPluginInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiPluginInfo value)  $default,){
final _that = this;
switch (_that) {
case _UiPluginInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiPluginInfo value)?  $default,){
final _that = this;
switch (_that) {
case _UiPluginInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  KarbeatPluginType pluginType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiPluginInfo() when $default != null:
return $default(_that.id,_that.name,_that.pluginType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  KarbeatPluginType pluginType)  $default,) {final _that = this;
switch (_that) {
case _UiPluginInfo():
return $default(_that.id,_that.name,_that.pluginType);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  KarbeatPluginType pluginType)?  $default,) {final _that = this;
switch (_that) {
case _UiPluginInfo() when $default != null:
return $default(_that.id,_that.name,_that.pluginType);case _:
  return null;

}
}

}

/// @nodoc


class _UiPluginInfo implements UiPluginInfo {
  const _UiPluginInfo({required this.id, required this.name, required this.pluginType});
  

@override final  int id;
@override final  String name;
@override final  KarbeatPluginType pluginType;

/// Create a copy of UiPluginInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiPluginInfoCopyWith<_UiPluginInfo> get copyWith => __$UiPluginInfoCopyWithImpl<_UiPluginInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiPluginInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.pluginType, pluginType) || other.pluginType == pluginType));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,pluginType);

@override
String toString() {
  return 'UiPluginInfo(id: $id, name: $name, pluginType: $pluginType)';
}


}

/// @nodoc
abstract mixin class _$UiPluginInfoCopyWith<$Res> implements $UiPluginInfoCopyWith<$Res> {
  factory _$UiPluginInfoCopyWith(_UiPluginInfo value, $Res Function(_UiPluginInfo) _then) = __$UiPluginInfoCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, KarbeatPluginType pluginType
});




}
/// @nodoc
class __$UiPluginInfoCopyWithImpl<$Res>
    implements _$UiPluginInfoCopyWith<$Res> {
  __$UiPluginInfoCopyWithImpl(this._self, this._then);

  final _UiPluginInfo _self;
  final $Res Function(_UiPluginInfo) _then;

/// Create a copy of UiPluginInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? pluginType = null,}) {
  return _then(_UiPluginInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,pluginType: null == pluginType ? _self.pluginType : pluginType // ignore: cast_nullable_to_non_nullable
as KarbeatPluginType,
  ));
}


}

/// @nodoc
mixin _$UiPluginParameter {

 int get id; String get path; String get name; String get group; double get value; double get min; double get max; double get defaultValue; double get step; UiParameterType get paramType; List<String> get choices;
/// Create a copy of UiPluginParameter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginParameterCopyWith<UiPluginParameter> get copyWith => _$UiPluginParameterCopyWithImpl<UiPluginParameter>(this as UiPluginParameter, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginParameter&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.group, group) || other.group == group)&&(identical(other.value, value) || other.value == value)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.step, step) || other.step == step)&&(identical(other.paramType, paramType) || other.paramType == paramType)&&const DeepCollectionEquality().equals(other.choices, choices));
}


@override
int get hashCode => Object.hash(runtimeType,id,path,name,group,value,min,max,defaultValue,step,paramType,const DeepCollectionEquality().hash(choices));

@override
String toString() {
  return 'UiPluginParameter(id: $id, path: $path, name: $name, group: $group, value: $value, min: $min, max: $max, defaultValue: $defaultValue, step: $step, paramType: $paramType, choices: $choices)';
}


}

/// @nodoc
abstract mixin class $UiPluginParameterCopyWith<$Res>  {
  factory $UiPluginParameterCopyWith(UiPluginParameter value, $Res Function(UiPluginParameter) _then) = _$UiPluginParameterCopyWithImpl;
@useResult
$Res call({
 int id, String path, String name, String group, double value, double min, double max, double defaultValue, double step, UiParameterType paramType, List<String> choices
});




}
/// @nodoc
class _$UiPluginParameterCopyWithImpl<$Res>
    implements $UiPluginParameterCopyWith<$Res> {
  _$UiPluginParameterCopyWithImpl(this._self, this._then);

  final UiPluginParameter _self;
  final $Res Function(UiPluginParameter) _then;

/// Create a copy of UiPluginParameter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? path = null,Object? name = null,Object? group = null,Object? value = null,Object? min = null,Object? max = null,Object? defaultValue = null,Object? step = null,Object? paramType = null,Object? choices = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as double,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as double,paramType: null == paramType ? _self.paramType : paramType // ignore: cast_nullable_to_non_nullable
as UiParameterType,choices: null == choices ? _self.choices : choices // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [UiPluginParameter].
extension UiPluginParameterPatterns on UiPluginParameter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiPluginParameter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiPluginParameter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiPluginParameter value)  $default,){
final _that = this;
switch (_that) {
case _UiPluginParameter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiPluginParameter value)?  $default,){
final _that = this;
switch (_that) {
case _UiPluginParameter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String path,  String name,  String group,  double value,  double min,  double max,  double defaultValue,  double step,  UiParameterType paramType,  List<String> choices)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiPluginParameter() when $default != null:
return $default(_that.id,_that.path,_that.name,_that.group,_that.value,_that.min,_that.max,_that.defaultValue,_that.step,_that.paramType,_that.choices);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String path,  String name,  String group,  double value,  double min,  double max,  double defaultValue,  double step,  UiParameterType paramType,  List<String> choices)  $default,) {final _that = this;
switch (_that) {
case _UiPluginParameter():
return $default(_that.id,_that.path,_that.name,_that.group,_that.value,_that.min,_that.max,_that.defaultValue,_that.step,_that.paramType,_that.choices);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String path,  String name,  String group,  double value,  double min,  double max,  double defaultValue,  double step,  UiParameterType paramType,  List<String> choices)?  $default,) {final _that = this;
switch (_that) {
case _UiPluginParameter() when $default != null:
return $default(_that.id,_that.path,_that.name,_that.group,_that.value,_that.min,_that.max,_that.defaultValue,_that.step,_that.paramType,_that.choices);case _:
  return null;

}
}

}

/// @nodoc


class _UiPluginParameter implements UiPluginParameter {
  const _UiPluginParameter({required this.id, required this.path, required this.name, required this.group, required this.value, required this.min, required this.max, required this.defaultValue, required this.step, required this.paramType, required final  List<String> choices}): _choices = choices;
  

@override final  int id;
@override final  String path;
@override final  String name;
@override final  String group;
@override final  double value;
@override final  double min;
@override final  double max;
@override final  double defaultValue;
@override final  double step;
@override final  UiParameterType paramType;
 final  List<String> _choices;
@override List<String> get choices {
  if (_choices is EqualUnmodifiableListView) return _choices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_choices);
}


/// Create a copy of UiPluginParameter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiPluginParameterCopyWith<_UiPluginParameter> get copyWith => __$UiPluginParameterCopyWithImpl<_UiPluginParameter>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiPluginParameter&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.group, group) || other.group == group)&&(identical(other.value, value) || other.value == value)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.step, step) || other.step == step)&&(identical(other.paramType, paramType) || other.paramType == paramType)&&const DeepCollectionEquality().equals(other._choices, _choices));
}


@override
int get hashCode => Object.hash(runtimeType,id,path,name,group,value,min,max,defaultValue,step,paramType,const DeepCollectionEquality().hash(_choices));

@override
String toString() {
  return 'UiPluginParameter(id: $id, path: $path, name: $name, group: $group, value: $value, min: $min, max: $max, defaultValue: $defaultValue, step: $step, paramType: $paramType, choices: $choices)';
}


}

/// @nodoc
abstract mixin class _$UiPluginParameterCopyWith<$Res> implements $UiPluginParameterCopyWith<$Res> {
  factory _$UiPluginParameterCopyWith(_UiPluginParameter value, $Res Function(_UiPluginParameter) _then) = __$UiPluginParameterCopyWithImpl;
@override @useResult
$Res call({
 int id, String path, String name, String group, double value, double min, double max, double defaultValue, double step, UiParameterType paramType, List<String> choices
});




}
/// @nodoc
class __$UiPluginParameterCopyWithImpl<$Res>
    implements _$UiPluginParameterCopyWith<$Res> {
  __$UiPluginParameterCopyWithImpl(this._self, this._then);

  final _UiPluginParameter _self;
  final $Res Function(_UiPluginParameter) _then;

/// Create a copy of UiPluginParameter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? path = null,Object? name = null,Object? group = null,Object? value = null,Object? min = null,Object? max = null,Object? defaultValue = null,Object? step = null,Object? paramType = null,Object? choices = null,}) {
  return _then(_UiPluginParameter(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as double,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as double,paramType: null == paramType ? _self.paramType : paramType // ignore: cast_nullable_to_non_nullable
as UiParameterType,choices: null == choices ? _self._choices : choices // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$UiPluginTarget {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginTarget);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiPluginTarget()';
}


}

/// @nodoc
class $UiPluginTargetCopyWith<$Res>  {
$UiPluginTargetCopyWith(UiPluginTarget _, $Res Function(UiPluginTarget) __);
}


/// Adds pattern-matching-related methods to [UiPluginTarget].
extension UiPluginTargetPatterns on UiPluginTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiPluginTarget_Generator value)?  generator,TResult Function( UiPluginTarget_TrackEffect value)?  trackEffect,TResult Function( UiPluginTarget_BusEffect value)?  busEffect,TResult Function( UiPluginTarget_MasterEffect value)?  masterEffect,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiPluginTarget_Generator() when generator != null:
return generator(_that);case UiPluginTarget_TrackEffect() when trackEffect != null:
return trackEffect(_that);case UiPluginTarget_BusEffect() when busEffect != null:
return busEffect(_that);case UiPluginTarget_MasterEffect() when masterEffect != null:
return masterEffect(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiPluginTarget_Generator value)  generator,required TResult Function( UiPluginTarget_TrackEffect value)  trackEffect,required TResult Function( UiPluginTarget_BusEffect value)  busEffect,required TResult Function( UiPluginTarget_MasterEffect value)  masterEffect,}){
final _that = this;
switch (_that) {
case UiPluginTarget_Generator():
return generator(_that);case UiPluginTarget_TrackEffect():
return trackEffect(_that);case UiPluginTarget_BusEffect():
return busEffect(_that);case UiPluginTarget_MasterEffect():
return masterEffect(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiPluginTarget_Generator value)?  generator,TResult? Function( UiPluginTarget_TrackEffect value)?  trackEffect,TResult? Function( UiPluginTarget_BusEffect value)?  busEffect,TResult? Function( UiPluginTarget_MasterEffect value)?  masterEffect,}){
final _that = this;
switch (_that) {
case UiPluginTarget_Generator() when generator != null:
return generator(_that);case UiPluginTarget_TrackEffect() when trackEffect != null:
return trackEffect(_that);case UiPluginTarget_BusEffect() when busEffect != null:
return busEffect(_that);case UiPluginTarget_MasterEffect() when masterEffect != null:
return masterEffect(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int field0)?  generator,TResult Function( int trackId,  int effectId)?  trackEffect,TResult Function( int busId,  int effectId)?  busEffect,TResult Function( int field0)?  masterEffect,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiPluginTarget_Generator() when generator != null:
return generator(_that.field0);case UiPluginTarget_TrackEffect() when trackEffect != null:
return trackEffect(_that.trackId,_that.effectId);case UiPluginTarget_BusEffect() when busEffect != null:
return busEffect(_that.busId,_that.effectId);case UiPluginTarget_MasterEffect() when masterEffect != null:
return masterEffect(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int field0)  generator,required TResult Function( int trackId,  int effectId)  trackEffect,required TResult Function( int busId,  int effectId)  busEffect,required TResult Function( int field0)  masterEffect,}) {final _that = this;
switch (_that) {
case UiPluginTarget_Generator():
return generator(_that.field0);case UiPluginTarget_TrackEffect():
return trackEffect(_that.trackId,_that.effectId);case UiPluginTarget_BusEffect():
return busEffect(_that.busId,_that.effectId);case UiPluginTarget_MasterEffect():
return masterEffect(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int field0)?  generator,TResult? Function( int trackId,  int effectId)?  trackEffect,TResult? Function( int busId,  int effectId)?  busEffect,TResult? Function( int field0)?  masterEffect,}) {final _that = this;
switch (_that) {
case UiPluginTarget_Generator() when generator != null:
return generator(_that.field0);case UiPluginTarget_TrackEffect() when trackEffect != null:
return trackEffect(_that.trackId,_that.effectId);case UiPluginTarget_BusEffect() when busEffect != null:
return busEffect(_that.busId,_that.effectId);case UiPluginTarget_MasterEffect() when masterEffect != null:
return masterEffect(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class UiPluginTarget_Generator extends UiPluginTarget {
  const UiPluginTarget_Generator(this.field0): super._();
  

 final  int field0;

/// Create a copy of UiPluginTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginTarget_GeneratorCopyWith<UiPluginTarget_Generator> get copyWith => _$UiPluginTarget_GeneratorCopyWithImpl<UiPluginTarget_Generator>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginTarget_Generator&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiPluginTarget.generator(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiPluginTarget_GeneratorCopyWith<$Res> implements $UiPluginTargetCopyWith<$Res> {
  factory $UiPluginTarget_GeneratorCopyWith(UiPluginTarget_Generator value, $Res Function(UiPluginTarget_Generator) _then) = _$UiPluginTarget_GeneratorCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiPluginTarget_GeneratorCopyWithImpl<$Res>
    implements $UiPluginTarget_GeneratorCopyWith<$Res> {
  _$UiPluginTarget_GeneratorCopyWithImpl(this._self, this._then);

  final UiPluginTarget_Generator _self;
  final $Res Function(UiPluginTarget_Generator) _then;

/// Create a copy of UiPluginTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiPluginTarget_Generator(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiPluginTarget_TrackEffect extends UiPluginTarget {
  const UiPluginTarget_TrackEffect({required this.trackId, required this.effectId}): super._();
  

 final  int trackId;
 final  int effectId;

/// Create a copy of UiPluginTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginTarget_TrackEffectCopyWith<UiPluginTarget_TrackEffect> get copyWith => _$UiPluginTarget_TrackEffectCopyWithImpl<UiPluginTarget_TrackEffect>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginTarget_TrackEffect&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.effectId, effectId) || other.effectId == effectId));
}


@override
int get hashCode => Object.hash(runtimeType,trackId,effectId);

@override
String toString() {
  return 'UiPluginTarget.trackEffect(trackId: $trackId, effectId: $effectId)';
}


}

/// @nodoc
abstract mixin class $UiPluginTarget_TrackEffectCopyWith<$Res> implements $UiPluginTargetCopyWith<$Res> {
  factory $UiPluginTarget_TrackEffectCopyWith(UiPluginTarget_TrackEffect value, $Res Function(UiPluginTarget_TrackEffect) _then) = _$UiPluginTarget_TrackEffectCopyWithImpl;
@useResult
$Res call({
 int trackId, int effectId
});




}
/// @nodoc
class _$UiPluginTarget_TrackEffectCopyWithImpl<$Res>
    implements $UiPluginTarget_TrackEffectCopyWith<$Res> {
  _$UiPluginTarget_TrackEffectCopyWithImpl(this._self, this._then);

  final UiPluginTarget_TrackEffect _self;
  final $Res Function(UiPluginTarget_TrackEffect) _then;

/// Create a copy of UiPluginTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? effectId = null,}) {
  return _then(UiPluginTarget_TrackEffect(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiPluginTarget_BusEffect extends UiPluginTarget {
  const UiPluginTarget_BusEffect({required this.busId, required this.effectId}): super._();
  

 final  int busId;
 final  int effectId;

/// Create a copy of UiPluginTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginTarget_BusEffectCopyWith<UiPluginTarget_BusEffect> get copyWith => _$UiPluginTarget_BusEffectCopyWithImpl<UiPluginTarget_BusEffect>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginTarget_BusEffect&&(identical(other.busId, busId) || other.busId == busId)&&(identical(other.effectId, effectId) || other.effectId == effectId));
}


@override
int get hashCode => Object.hash(runtimeType,busId,effectId);

@override
String toString() {
  return 'UiPluginTarget.busEffect(busId: $busId, effectId: $effectId)';
}


}

/// @nodoc
abstract mixin class $UiPluginTarget_BusEffectCopyWith<$Res> implements $UiPluginTargetCopyWith<$Res> {
  factory $UiPluginTarget_BusEffectCopyWith(UiPluginTarget_BusEffect value, $Res Function(UiPluginTarget_BusEffect) _then) = _$UiPluginTarget_BusEffectCopyWithImpl;
@useResult
$Res call({
 int busId, int effectId
});




}
/// @nodoc
class _$UiPluginTarget_BusEffectCopyWithImpl<$Res>
    implements $UiPluginTarget_BusEffectCopyWith<$Res> {
  _$UiPluginTarget_BusEffectCopyWithImpl(this._self, this._then);

  final UiPluginTarget_BusEffect _self;
  final $Res Function(UiPluginTarget_BusEffect) _then;

/// Create a copy of UiPluginTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? busId = null,Object? effectId = null,}) {
  return _then(UiPluginTarget_BusEffect(
busId: null == busId ? _self.busId : busId // ignore: cast_nullable_to_non_nullable
as int,effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiPluginTarget_MasterEffect extends UiPluginTarget {
  const UiPluginTarget_MasterEffect(this.field0): super._();
  

 final  int field0;

/// Create a copy of UiPluginTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginTarget_MasterEffectCopyWith<UiPluginTarget_MasterEffect> get copyWith => _$UiPluginTarget_MasterEffectCopyWithImpl<UiPluginTarget_MasterEffect>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginTarget_MasterEffect&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiPluginTarget.masterEffect(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiPluginTarget_MasterEffectCopyWith<$Res> implements $UiPluginTargetCopyWith<$Res> {
  factory $UiPluginTarget_MasterEffectCopyWith(UiPluginTarget_MasterEffect value, $Res Function(UiPluginTarget_MasterEffect) _then) = _$UiPluginTarget_MasterEffectCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiPluginTarget_MasterEffectCopyWithImpl<$Res>
    implements $UiPluginTarget_MasterEffectCopyWith<$Res> {
  _$UiPluginTarget_MasterEffectCopyWithImpl(this._self, this._then);

  final UiPluginTarget_MasterEffect _self;
  final $Res Function(UiPluginTarget_MasterEffect) _then;

/// Create a copy of UiPluginTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiPluginTarget_MasterEffect(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
