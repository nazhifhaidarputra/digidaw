// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'blocking_task_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BlockingTaskEvent {

 int get id; String get label;/// `null` when the task was submitted with an unbounded timeout.
 Duration? get timeout;
/// Create a copy of BlockingTaskEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlockingTaskEventCopyWith<BlockingTaskEvent> get copyWith => _$BlockingTaskEventCopyWithImpl<BlockingTaskEvent>(this as BlockingTaskEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlockingTaskEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.timeout, timeout) || other.timeout == timeout));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,timeout);

@override
String toString() {
  return 'BlockingTaskEvent(id: $id, label: $label, timeout: $timeout)';
}


}

/// @nodoc
abstract mixin class $BlockingTaskEventCopyWith<$Res>  {
  factory $BlockingTaskEventCopyWith(BlockingTaskEvent value, $Res Function(BlockingTaskEvent) _then) = _$BlockingTaskEventCopyWithImpl;
@useResult
$Res call({
 int id, String label, Duration? timeout
});




}
/// @nodoc
class _$BlockingTaskEventCopyWithImpl<$Res>
    implements $BlockingTaskEventCopyWith<$Res> {
  _$BlockingTaskEventCopyWithImpl(this._self, this._then);

  final BlockingTaskEvent _self;
  final $Res Function(BlockingTaskEvent) _then;

/// Create a copy of BlockingTaskEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? timeout = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,timeout: freezed == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}

}


/// Adds pattern-matching-related methods to [BlockingTaskEvent].
extension BlockingTaskEventPatterns on BlockingTaskEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlockingTaskEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlockingTaskEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlockingTaskEvent value)  $default,){
final _that = this;
switch (_that) {
case _BlockingTaskEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlockingTaskEvent value)?  $default,){
final _that = this;
switch (_that) {
case _BlockingTaskEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String label,  Duration? timeout)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlockingTaskEvent() when $default != null:
return $default(_that.id,_that.label,_that.timeout);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String label,  Duration? timeout)  $default,) {final _that = this;
switch (_that) {
case _BlockingTaskEvent():
return $default(_that.id,_that.label,_that.timeout);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String label,  Duration? timeout)?  $default,) {final _that = this;
switch (_that) {
case _BlockingTaskEvent() when $default != null:
return $default(_that.id,_that.label,_that.timeout);case _:
  return null;

}
}

}

/// @nodoc


class _BlockingTaskEvent implements BlockingTaskEvent {
  const _BlockingTaskEvent({required this.id, required this.label, this.timeout});
  

@override final  int id;
@override final  String label;
/// `null` when the task was submitted with an unbounded timeout.
@override final  Duration? timeout;

/// Create a copy of BlockingTaskEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlockingTaskEventCopyWith<_BlockingTaskEvent> get copyWith => __$BlockingTaskEventCopyWithImpl<_BlockingTaskEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlockingTaskEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.timeout, timeout) || other.timeout == timeout));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,timeout);

@override
String toString() {
  return 'BlockingTaskEvent(id: $id, label: $label, timeout: $timeout)';
}


}

/// @nodoc
abstract mixin class _$BlockingTaskEventCopyWith<$Res> implements $BlockingTaskEventCopyWith<$Res> {
  factory _$BlockingTaskEventCopyWith(_BlockingTaskEvent value, $Res Function(_BlockingTaskEvent) _then) = __$BlockingTaskEventCopyWithImpl;
@override @useResult
$Res call({
 int id, String label, Duration? timeout
});




}
/// @nodoc
class __$BlockingTaskEventCopyWithImpl<$Res>
    implements _$BlockingTaskEventCopyWith<$Res> {
  __$BlockingTaskEventCopyWithImpl(this._self, this._then);

  final _BlockingTaskEvent _self;
  final $Res Function(_BlockingTaskEvent) _then;

/// Create a copy of BlockingTaskEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? timeout = freezed,}) {
  return _then(_BlockingTaskEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,timeout: freezed == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}


}

/// @nodoc
mixin _$BlockingTaskState {

 BlockingTaskEvent? get active;/// Submitted tasks waiting behind [active].
 int get pendingCount;
/// Create a copy of BlockingTaskState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlockingTaskStateCopyWith<BlockingTaskState> get copyWith => _$BlockingTaskStateCopyWithImpl<BlockingTaskState>(this as BlockingTaskState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlockingTaskState&&(identical(other.active, active) || other.active == active)&&(identical(other.pendingCount, pendingCount) || other.pendingCount == pendingCount));
}


@override
int get hashCode => Object.hash(runtimeType,active,pendingCount);

@override
String toString() {
  return 'BlockingTaskState(active: $active, pendingCount: $pendingCount)';
}


}

/// @nodoc
abstract mixin class $BlockingTaskStateCopyWith<$Res>  {
  factory $BlockingTaskStateCopyWith(BlockingTaskState value, $Res Function(BlockingTaskState) _then) = _$BlockingTaskStateCopyWithImpl;
@useResult
$Res call({
 BlockingTaskEvent? active, int pendingCount
});


$BlockingTaskEventCopyWith<$Res>? get active;

}
/// @nodoc
class _$BlockingTaskStateCopyWithImpl<$Res>
    implements $BlockingTaskStateCopyWith<$Res> {
  _$BlockingTaskStateCopyWithImpl(this._self, this._then);

  final BlockingTaskState _self;
  final $Res Function(BlockingTaskState) _then;

/// Create a copy of BlockingTaskState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? active = freezed,Object? pendingCount = null,}) {
  return _then(_self.copyWith(
active: freezed == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as BlockingTaskEvent?,pendingCount: null == pendingCount ? _self.pendingCount : pendingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of BlockingTaskState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockingTaskEventCopyWith<$Res>? get active {
    if (_self.active == null) {
    return null;
  }

  return $BlockingTaskEventCopyWith<$Res>(_self.active!, (value) {
    return _then(_self.copyWith(active: value));
  });
}
}


/// Adds pattern-matching-related methods to [BlockingTaskState].
extension BlockingTaskStatePatterns on BlockingTaskState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlockingTaskState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlockingTaskState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlockingTaskState value)  $default,){
final _that = this;
switch (_that) {
case _BlockingTaskState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlockingTaskState value)?  $default,){
final _that = this;
switch (_that) {
case _BlockingTaskState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BlockingTaskEvent? active,  int pendingCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlockingTaskState() when $default != null:
return $default(_that.active,_that.pendingCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BlockingTaskEvent? active,  int pendingCount)  $default,) {final _that = this;
switch (_that) {
case _BlockingTaskState():
return $default(_that.active,_that.pendingCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BlockingTaskEvent? active,  int pendingCount)?  $default,) {final _that = this;
switch (_that) {
case _BlockingTaskState() when $default != null:
return $default(_that.active,_that.pendingCount);case _:
  return null;

}
}

}

/// @nodoc


class _BlockingTaskState extends BlockingTaskState {
  const _BlockingTaskState({this.active, this.pendingCount = 0}): super._();
  

@override final  BlockingTaskEvent? active;
/// Submitted tasks waiting behind [active].
@override@JsonKey() final  int pendingCount;

/// Create a copy of BlockingTaskState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlockingTaskStateCopyWith<_BlockingTaskState> get copyWith => __$BlockingTaskStateCopyWithImpl<_BlockingTaskState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlockingTaskState&&(identical(other.active, active) || other.active == active)&&(identical(other.pendingCount, pendingCount) || other.pendingCount == pendingCount));
}


@override
int get hashCode => Object.hash(runtimeType,active,pendingCount);

@override
String toString() {
  return 'BlockingTaskState(active: $active, pendingCount: $pendingCount)';
}


}

/// @nodoc
abstract mixin class _$BlockingTaskStateCopyWith<$Res> implements $BlockingTaskStateCopyWith<$Res> {
  factory _$BlockingTaskStateCopyWith(_BlockingTaskState value, $Res Function(_BlockingTaskState) _then) = __$BlockingTaskStateCopyWithImpl;
@override @useResult
$Res call({
 BlockingTaskEvent? active, int pendingCount
});


@override $BlockingTaskEventCopyWith<$Res>? get active;

}
/// @nodoc
class __$BlockingTaskStateCopyWithImpl<$Res>
    implements _$BlockingTaskStateCopyWith<$Res> {
  __$BlockingTaskStateCopyWithImpl(this._self, this._then);

  final _BlockingTaskState _self;
  final $Res Function(_BlockingTaskState) _then;

/// Create a copy of BlockingTaskState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? active = freezed,Object? pendingCount = null,}) {
  return _then(_BlockingTaskState(
active: freezed == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as BlockingTaskEvent?,pendingCount: null == pendingCount ? _self.pendingCount : pendingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of BlockingTaskState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockingTaskEventCopyWith<$Res>? get active {
    if (_self.active == null) {
    return null;
  }

  return $BlockingTaskEventCopyWith<$Res>(_self.active!, (value) {
    return _then(_self.copyWith(active: value));
  });
}
}

// dart format on
