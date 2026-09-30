// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jobs.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiJobEvent {

 int get id; UiJobKind get kind; UiJobTarget get target; UiJobState get state;
/// Create a copy of UiJobEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiJobEventCopyWith<UiJobEvent> get copyWith => _$UiJobEventCopyWithImpl<UiJobEvent>(this as UiJobEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.target, target) || other.target == target)&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,target,state);

@override
String toString() {
  return 'UiJobEvent(id: $id, kind: $kind, target: $target, state: $state)';
}


}

/// @nodoc
abstract mixin class $UiJobEventCopyWith<$Res>  {
  factory $UiJobEventCopyWith(UiJobEvent value, $Res Function(UiJobEvent) _then) = _$UiJobEventCopyWithImpl;
@useResult
$Res call({
 int id, UiJobKind kind, UiJobTarget target, UiJobState state
});


$UiJobTargetCopyWith<$Res> get target;$UiJobStateCopyWith<$Res> get state;

}
/// @nodoc
class _$UiJobEventCopyWithImpl<$Res>
    implements $UiJobEventCopyWith<$Res> {
  _$UiJobEventCopyWithImpl(this._self, this._then);

  final UiJobEvent _self;
  final $Res Function(UiJobEvent) _then;

/// Create a copy of UiJobEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? target = null,Object? state = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as UiJobKind,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as UiJobTarget,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as UiJobState,
  ));
}
/// Create a copy of UiJobEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiJobTargetCopyWith<$Res> get target {
  
  return $UiJobTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of UiJobEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiJobStateCopyWith<$Res> get state {
  
  return $UiJobStateCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiJobEvent].
extension UiJobEventPatterns on UiJobEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiJobEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiJobEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiJobEvent value)  $default,){
final _that = this;
switch (_that) {
case _UiJobEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiJobEvent value)?  $default,){
final _that = this;
switch (_that) {
case _UiJobEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  UiJobKind kind,  UiJobTarget target,  UiJobState state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiJobEvent() when $default != null:
return $default(_that.id,_that.kind,_that.target,_that.state);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  UiJobKind kind,  UiJobTarget target,  UiJobState state)  $default,) {final _that = this;
switch (_that) {
case _UiJobEvent():
return $default(_that.id,_that.kind,_that.target,_that.state);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  UiJobKind kind,  UiJobTarget target,  UiJobState state)?  $default,) {final _that = this;
switch (_that) {
case _UiJobEvent() when $default != null:
return $default(_that.id,_that.kind,_that.target,_that.state);case _:
  return null;

}
}

}

/// @nodoc


class _UiJobEvent implements UiJobEvent {
  const _UiJobEvent({required this.id, required this.kind, required this.target, required this.state});
  

@override final  int id;
@override final  UiJobKind kind;
@override final  UiJobTarget target;
@override final  UiJobState state;

/// Create a copy of UiJobEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiJobEventCopyWith<_UiJobEvent> get copyWith => __$UiJobEventCopyWithImpl<_UiJobEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiJobEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.target, target) || other.target == target)&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,target,state);

@override
String toString() {
  return 'UiJobEvent(id: $id, kind: $kind, target: $target, state: $state)';
}


}

/// @nodoc
abstract mixin class _$UiJobEventCopyWith<$Res> implements $UiJobEventCopyWith<$Res> {
  factory _$UiJobEventCopyWith(_UiJobEvent value, $Res Function(_UiJobEvent) _then) = __$UiJobEventCopyWithImpl;
@override @useResult
$Res call({
 int id, UiJobKind kind, UiJobTarget target, UiJobState state
});


@override $UiJobTargetCopyWith<$Res> get target;@override $UiJobStateCopyWith<$Res> get state;

}
/// @nodoc
class __$UiJobEventCopyWithImpl<$Res>
    implements _$UiJobEventCopyWith<$Res> {
  __$UiJobEventCopyWithImpl(this._self, this._then);

  final _UiJobEvent _self;
  final $Res Function(_UiJobEvent) _then;

/// Create a copy of UiJobEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? target = null,Object? state = null,}) {
  return _then(_UiJobEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as UiJobKind,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as UiJobTarget,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as UiJobState,
  ));
}

/// Create a copy of UiJobEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiJobTargetCopyWith<$Res> get target {
  
  return $UiJobTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of UiJobEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiJobStateCopyWith<$Res> get state {
  
  return $UiJobStateCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

/// @nodoc
mixin _$UiJobState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiJobState()';
}


}

/// @nodoc
class $UiJobStateCopyWith<$Res>  {
$UiJobStateCopyWith(UiJobState _, $Res Function(UiJobState) __);
}


/// Adds pattern-matching-related methods to [UiJobState].
extension UiJobStatePatterns on UiJobState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiJobState_Queued value)?  queued,TResult Function( UiJobState_Running value)?  running,TResult Function( UiJobState_Progress value)?  progress,TResult Function( UiJobState_Completed value)?  completed,TResult Function( UiJobState_Failed value)?  failed,TResult Function( UiJobState_Cancelled value)?  cancelled,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiJobState_Queued() when queued != null:
return queued(_that);case UiJobState_Running() when running != null:
return running(_that);case UiJobState_Progress() when progress != null:
return progress(_that);case UiJobState_Completed() when completed != null:
return completed(_that);case UiJobState_Failed() when failed != null:
return failed(_that);case UiJobState_Cancelled() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiJobState_Queued value)  queued,required TResult Function( UiJobState_Running value)  running,required TResult Function( UiJobState_Progress value)  progress,required TResult Function( UiJobState_Completed value)  completed,required TResult Function( UiJobState_Failed value)  failed,required TResult Function( UiJobState_Cancelled value)  cancelled,}){
final _that = this;
switch (_that) {
case UiJobState_Queued():
return queued(_that);case UiJobState_Running():
return running(_that);case UiJobState_Progress():
return progress(_that);case UiJobState_Completed():
return completed(_that);case UiJobState_Failed():
return failed(_that);case UiJobState_Cancelled():
return cancelled(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiJobState_Queued value)?  queued,TResult? Function( UiJobState_Running value)?  running,TResult? Function( UiJobState_Progress value)?  progress,TResult? Function( UiJobState_Completed value)?  completed,TResult? Function( UiJobState_Failed value)?  failed,TResult? Function( UiJobState_Cancelled value)?  cancelled,}){
final _that = this;
switch (_that) {
case UiJobState_Queued() when queued != null:
return queued(_that);case UiJobState_Running() when running != null:
return running(_that);case UiJobState_Progress() when progress != null:
return progress(_that);case UiJobState_Completed() when completed != null:
return completed(_that);case UiJobState_Failed() when failed != null:
return failed(_that);case UiJobState_Cancelled() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  queued,TResult Function()?  running,TResult Function( String stage,  double fraction)?  progress,TResult Function()?  completed,TResult Function( String message)?  failed,TResult Function()?  cancelled,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiJobState_Queued() when queued != null:
return queued();case UiJobState_Running() when running != null:
return running();case UiJobState_Progress() when progress != null:
return progress(_that.stage,_that.fraction);case UiJobState_Completed() when completed != null:
return completed();case UiJobState_Failed() when failed != null:
return failed(_that.message);case UiJobState_Cancelled() when cancelled != null:
return cancelled();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  queued,required TResult Function()  running,required TResult Function( String stage,  double fraction)  progress,required TResult Function()  completed,required TResult Function( String message)  failed,required TResult Function()  cancelled,}) {final _that = this;
switch (_that) {
case UiJobState_Queued():
return queued();case UiJobState_Running():
return running();case UiJobState_Progress():
return progress(_that.stage,_that.fraction);case UiJobState_Completed():
return completed();case UiJobState_Failed():
return failed(_that.message);case UiJobState_Cancelled():
return cancelled();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  queued,TResult? Function()?  running,TResult? Function( String stage,  double fraction)?  progress,TResult? Function()?  completed,TResult? Function( String message)?  failed,TResult? Function()?  cancelled,}) {final _that = this;
switch (_that) {
case UiJobState_Queued() when queued != null:
return queued();case UiJobState_Running() when running != null:
return running();case UiJobState_Progress() when progress != null:
return progress(_that.stage,_that.fraction);case UiJobState_Completed() when completed != null:
return completed();case UiJobState_Failed() when failed != null:
return failed(_that.message);case UiJobState_Cancelled() when cancelled != null:
return cancelled();case _:
  return null;

}
}

}

/// @nodoc


class UiJobState_Queued extends UiJobState {
  const UiJobState_Queued(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobState_Queued);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiJobState.queued()';
}


}




/// @nodoc


class UiJobState_Running extends UiJobState {
  const UiJobState_Running(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobState_Running);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiJobState.running()';
}


}




/// @nodoc


class UiJobState_Progress extends UiJobState {
  const UiJobState_Progress({required this.stage, required this.fraction}): super._();
  

 final  String stage;
 final  double fraction;

/// Create a copy of UiJobState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiJobState_ProgressCopyWith<UiJobState_Progress> get copyWith => _$UiJobState_ProgressCopyWithImpl<UiJobState_Progress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobState_Progress&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.fraction, fraction) || other.fraction == fraction));
}


@override
int get hashCode => Object.hash(runtimeType,stage,fraction);

@override
String toString() {
  return 'UiJobState.progress(stage: $stage, fraction: $fraction)';
}


}

/// @nodoc
abstract mixin class $UiJobState_ProgressCopyWith<$Res> implements $UiJobStateCopyWith<$Res> {
  factory $UiJobState_ProgressCopyWith(UiJobState_Progress value, $Res Function(UiJobState_Progress) _then) = _$UiJobState_ProgressCopyWithImpl;
@useResult
$Res call({
 String stage, double fraction
});




}
/// @nodoc
class _$UiJobState_ProgressCopyWithImpl<$Res>
    implements $UiJobState_ProgressCopyWith<$Res> {
  _$UiJobState_ProgressCopyWithImpl(this._self, this._then);

  final UiJobState_Progress _self;
  final $Res Function(UiJobState_Progress) _then;

/// Create a copy of UiJobState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? fraction = null,}) {
  return _then(UiJobState_Progress(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,fraction: null == fraction ? _self.fraction : fraction // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class UiJobState_Completed extends UiJobState {
  const UiJobState_Completed(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobState_Completed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiJobState.completed()';
}


}




/// @nodoc


class UiJobState_Failed extends UiJobState {
  const UiJobState_Failed({required this.message}): super._();
  

 final  String message;

/// Create a copy of UiJobState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiJobState_FailedCopyWith<UiJobState_Failed> get copyWith => _$UiJobState_FailedCopyWithImpl<UiJobState_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobState_Failed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'UiJobState.failed(message: $message)';
}


}

/// @nodoc
abstract mixin class $UiJobState_FailedCopyWith<$Res> implements $UiJobStateCopyWith<$Res> {
  factory $UiJobState_FailedCopyWith(UiJobState_Failed value, $Res Function(UiJobState_Failed) _then) = _$UiJobState_FailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$UiJobState_FailedCopyWithImpl<$Res>
    implements $UiJobState_FailedCopyWith<$Res> {
  _$UiJobState_FailedCopyWithImpl(this._self, this._then);

  final UiJobState_Failed _self;
  final $Res Function(UiJobState_Failed) _then;

/// Create a copy of UiJobState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(UiJobState_Failed(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class UiJobState_Cancelled extends UiJobState {
  const UiJobState_Cancelled(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobState_Cancelled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiJobState.cancelled()';
}


}




/// @nodoc
mixin _$UiJobTarget {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobTarget);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiJobTarget()';
}


}

/// @nodoc
class $UiJobTargetCopyWith<$Res>  {
$UiJobTargetCopyWith(UiJobTarget _, $Res Function(UiJobTarget) __);
}


/// Adds pattern-matching-related methods to [UiJobTarget].
extension UiJobTargetPatterns on UiJobTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiJobTarget_None value)?  none,TResult Function( UiJobTarget_Project value)?  project,TResult Function( UiJobTarget_Source value)?  source,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiJobTarget_None() when none != null:
return none(_that);case UiJobTarget_Project() when project != null:
return project(_that);case UiJobTarget_Source() when source != null:
return source(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiJobTarget_None value)  none,required TResult Function( UiJobTarget_Project value)  project,required TResult Function( UiJobTarget_Source value)  source,}){
final _that = this;
switch (_that) {
case UiJobTarget_None():
return none(_that);case UiJobTarget_Project():
return project(_that);case UiJobTarget_Source():
return source(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiJobTarget_None value)?  none,TResult? Function( UiJobTarget_Project value)?  project,TResult? Function( UiJobTarget_Source value)?  source,}){
final _that = this;
switch (_that) {
case UiJobTarget_None() when none != null:
return none(_that);case UiJobTarget_Project() when project != null:
return project(_that);case UiJobTarget_Source() when source != null:
return source(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  none,TResult Function()?  project,TResult Function( int sourceId)?  source,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiJobTarget_None() when none != null:
return none();case UiJobTarget_Project() when project != null:
return project();case UiJobTarget_Source() when source != null:
return source(_that.sourceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  none,required TResult Function()  project,required TResult Function( int sourceId)  source,}) {final _that = this;
switch (_that) {
case UiJobTarget_None():
return none();case UiJobTarget_Project():
return project();case UiJobTarget_Source():
return source(_that.sourceId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  none,TResult? Function()?  project,TResult? Function( int sourceId)?  source,}) {final _that = this;
switch (_that) {
case UiJobTarget_None() when none != null:
return none();case UiJobTarget_Project() when project != null:
return project();case UiJobTarget_Source() when source != null:
return source(_that.sourceId);case _:
  return null;

}
}

}

/// @nodoc


class UiJobTarget_None extends UiJobTarget {
  const UiJobTarget_None(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobTarget_None);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiJobTarget.none()';
}


}




/// @nodoc


class UiJobTarget_Project extends UiJobTarget {
  const UiJobTarget_Project(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobTarget_Project);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiJobTarget.project()';
}


}




/// @nodoc


class UiJobTarget_Source extends UiJobTarget {
  const UiJobTarget_Source({required this.sourceId}): super._();
  

 final  int sourceId;

/// Create a copy of UiJobTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiJobTarget_SourceCopyWith<UiJobTarget_Source> get copyWith => _$UiJobTarget_SourceCopyWithImpl<UiJobTarget_Source>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiJobTarget_Source&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId));
}


@override
int get hashCode => Object.hash(runtimeType,sourceId);

@override
String toString() {
  return 'UiJobTarget.source(sourceId: $sourceId)';
}


}

/// @nodoc
abstract mixin class $UiJobTarget_SourceCopyWith<$Res> implements $UiJobTargetCopyWith<$Res> {
  factory $UiJobTarget_SourceCopyWith(UiJobTarget_Source value, $Res Function(UiJobTarget_Source) _then) = _$UiJobTarget_SourceCopyWithImpl;
@useResult
$Res call({
 int sourceId
});




}
/// @nodoc
class _$UiJobTarget_SourceCopyWithImpl<$Res>
    implements $UiJobTarget_SourceCopyWith<$Res> {
  _$UiJobTarget_SourceCopyWithImpl(this._self, this._then);

  final UiJobTarget_Source _self;
  final $Res Function(UiJobTarget_Source) _then;

/// Create a copy of UiJobTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sourceId = null,}) {
  return _then(UiJobTarget_Source(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
