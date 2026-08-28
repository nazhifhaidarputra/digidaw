// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationQueueState {

 UserNotificationEvent? get current; int get pendingCount;
/// Create a copy of NotificationQueueState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationQueueStateCopyWith<NotificationQueueState> get copyWith => _$NotificationQueueStateCopyWithImpl<NotificationQueueState>(this as NotificationQueueState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationQueueState&&(identical(other.current, current) || other.current == current)&&(identical(other.pendingCount, pendingCount) || other.pendingCount == pendingCount));
}


@override
int get hashCode => Object.hash(runtimeType,current,pendingCount);

@override
String toString() {
  return 'NotificationQueueState(current: $current, pendingCount: $pendingCount)';
}


}

/// @nodoc
abstract mixin class $NotificationQueueStateCopyWith<$Res>  {
  factory $NotificationQueueStateCopyWith(NotificationQueueState value, $Res Function(NotificationQueueState) _then) = _$NotificationQueueStateCopyWithImpl;
@useResult
$Res call({
 UserNotificationEvent? current, int pendingCount
});




}
/// @nodoc
class _$NotificationQueueStateCopyWithImpl<$Res>
    implements $NotificationQueueStateCopyWith<$Res> {
  _$NotificationQueueStateCopyWithImpl(this._self, this._then);

  final NotificationQueueState _self;
  final $Res Function(NotificationQueueState) _then;

/// Create a copy of NotificationQueueState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? current = freezed,Object? pendingCount = null,}) {
  return _then(_self.copyWith(
current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as UserNotificationEvent?,pendingCount: null == pendingCount ? _self.pendingCount : pendingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationQueueState].
extension NotificationQueueStatePatterns on NotificationQueueState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationQueueState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationQueueState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationQueueState value)  $default,){
final _that = this;
switch (_that) {
case _NotificationQueueState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationQueueState value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationQueueState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserNotificationEvent? current,  int pendingCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationQueueState() when $default != null:
return $default(_that.current,_that.pendingCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserNotificationEvent? current,  int pendingCount)  $default,) {final _that = this;
switch (_that) {
case _NotificationQueueState():
return $default(_that.current,_that.pendingCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserNotificationEvent? current,  int pendingCount)?  $default,) {final _that = this;
switch (_that) {
case _NotificationQueueState() when $default != null:
return $default(_that.current,_that.pendingCount);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationQueueState extends NotificationQueueState {
  const _NotificationQueueState({this.current, this.pendingCount = 0}): super._();
  

@override final  UserNotificationEvent? current;
@override@JsonKey() final  int pendingCount;

/// Create a copy of NotificationQueueState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationQueueStateCopyWith<_NotificationQueueState> get copyWith => __$NotificationQueueStateCopyWithImpl<_NotificationQueueState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationQueueState&&(identical(other.current, current) || other.current == current)&&(identical(other.pendingCount, pendingCount) || other.pendingCount == pendingCount));
}


@override
int get hashCode => Object.hash(runtimeType,current,pendingCount);

@override
String toString() {
  return 'NotificationQueueState(current: $current, pendingCount: $pendingCount)';
}


}

/// @nodoc
abstract mixin class _$NotificationQueueStateCopyWith<$Res> implements $NotificationQueueStateCopyWith<$Res> {
  factory _$NotificationQueueStateCopyWith(_NotificationQueueState value, $Res Function(_NotificationQueueState) _then) = __$NotificationQueueStateCopyWithImpl;
@override @useResult
$Res call({
 UserNotificationEvent? current, int pendingCount
});




}
/// @nodoc
class __$NotificationQueueStateCopyWithImpl<$Res>
    implements _$NotificationQueueStateCopyWith<$Res> {
  __$NotificationQueueStateCopyWithImpl(this._self, this._then);

  final _NotificationQueueState _self;
  final $Res Function(_NotificationQueueState) _then;

/// Create a copy of NotificationQueueState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? current = freezed,Object? pendingCount = null,}) {
  return _then(_NotificationQueueState(
current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as UserNotificationEvent?,pendingCount: null == pendingCount ? _self.pendingCount : pendingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
