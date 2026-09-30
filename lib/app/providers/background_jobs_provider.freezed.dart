// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'background_jobs_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BackgroundJob {

 int get id; UiJobKind get kind; UiJobTarget get target; UiJobState get state;
/// Create a copy of BackgroundJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackgroundJobCopyWith<BackgroundJob> get copyWith => _$BackgroundJobCopyWithImpl<BackgroundJob>(this as BackgroundJob, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BackgroundJob&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.target, target) || other.target == target)&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,target,state);

@override
String toString() {
  return 'BackgroundJob(id: $id, kind: $kind, target: $target, state: $state)';
}


}

/// @nodoc
abstract mixin class $BackgroundJobCopyWith<$Res>  {
  factory $BackgroundJobCopyWith(BackgroundJob value, $Res Function(BackgroundJob) _then) = _$BackgroundJobCopyWithImpl;
@useResult
$Res call({
 int id, UiJobKind kind, UiJobTarget target, UiJobState state
});


$UiJobTargetCopyWith<$Res> get target;$UiJobStateCopyWith<$Res> get state;

}
/// @nodoc
class _$BackgroundJobCopyWithImpl<$Res>
    implements $BackgroundJobCopyWith<$Res> {
  _$BackgroundJobCopyWithImpl(this._self, this._then);

  final BackgroundJob _self;
  final $Res Function(BackgroundJob) _then;

/// Create a copy of BackgroundJob
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
/// Create a copy of BackgroundJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiJobTargetCopyWith<$Res> get target {
  
  return $UiJobTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of BackgroundJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiJobStateCopyWith<$Res> get state {
  
  return $UiJobStateCopyWith<$Res>(_self.state, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}


/// Adds pattern-matching-related methods to [BackgroundJob].
extension BackgroundJobPatterns on BackgroundJob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BackgroundJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BackgroundJob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BackgroundJob value)  $default,){
final _that = this;
switch (_that) {
case _BackgroundJob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BackgroundJob value)?  $default,){
final _that = this;
switch (_that) {
case _BackgroundJob() when $default != null:
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
case _BackgroundJob() when $default != null:
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
case _BackgroundJob():
return $default(_that.id,_that.kind,_that.target,_that.state);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  UiJobKind kind,  UiJobTarget target,  UiJobState state)?  $default,) {final _that = this;
switch (_that) {
case _BackgroundJob() when $default != null:
return $default(_that.id,_that.kind,_that.target,_that.state);case _:
  return null;

}
}

}

/// @nodoc


class _BackgroundJob implements BackgroundJob {
  const _BackgroundJob({required this.id, required this.kind, required this.target, required this.state});
  

@override final  int id;
@override final  UiJobKind kind;
@override final  UiJobTarget target;
@override final  UiJobState state;

/// Create a copy of BackgroundJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BackgroundJobCopyWith<_BackgroundJob> get copyWith => __$BackgroundJobCopyWithImpl<_BackgroundJob>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BackgroundJob&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.target, target) || other.target == target)&&(identical(other.state, state) || other.state == state));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,target,state);

@override
String toString() {
  return 'BackgroundJob(id: $id, kind: $kind, target: $target, state: $state)';
}


}

/// @nodoc
abstract mixin class _$BackgroundJobCopyWith<$Res> implements $BackgroundJobCopyWith<$Res> {
  factory _$BackgroundJobCopyWith(_BackgroundJob value, $Res Function(_BackgroundJob) _then) = __$BackgroundJobCopyWithImpl;
@override @useResult
$Res call({
 int id, UiJobKind kind, UiJobTarget target, UiJobState state
});


@override $UiJobTargetCopyWith<$Res> get target;@override $UiJobStateCopyWith<$Res> get state;

}
/// @nodoc
class __$BackgroundJobCopyWithImpl<$Res>
    implements _$BackgroundJobCopyWith<$Res> {
  __$BackgroundJobCopyWithImpl(this._self, this._then);

  final _BackgroundJob _self;
  final $Res Function(_BackgroundJob) _then;

/// Create a copy of BackgroundJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? target = null,Object? state = null,}) {
  return _then(_BackgroundJob(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as UiJobKind,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as UiJobTarget,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as UiJobState,
  ));
}

/// Create a copy of BackgroundJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiJobTargetCopyWith<$Res> get target {
  
  return $UiJobTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of BackgroundJob
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
mixin _$BackgroundJobsState {

/// Unfinished jobs by id. Finished jobs are removed.
 IMap<int, BackgroundJob> get active;/// Bumped each time a job that changed an audio source completes, keyed by
/// source ID. Watch an entry to refetch that source.
 IMap<int, int> get sourceRevisions;
/// Create a copy of BackgroundJobsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackgroundJobsStateCopyWith<BackgroundJobsState> get copyWith => _$BackgroundJobsStateCopyWithImpl<BackgroundJobsState>(this as BackgroundJobsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BackgroundJobsState&&(identical(other.active, active) || other.active == active)&&(identical(other.sourceRevisions, sourceRevisions) || other.sourceRevisions == sourceRevisions));
}


@override
int get hashCode => Object.hash(runtimeType,active,sourceRevisions);

@override
String toString() {
  return 'BackgroundJobsState(active: $active, sourceRevisions: $sourceRevisions)';
}


}

/// @nodoc
abstract mixin class $BackgroundJobsStateCopyWith<$Res>  {
  factory $BackgroundJobsStateCopyWith(BackgroundJobsState value, $Res Function(BackgroundJobsState) _then) = _$BackgroundJobsStateCopyWithImpl;
@useResult
$Res call({
 IMap<int, BackgroundJob> active, IMap<int, int> sourceRevisions
});




}
/// @nodoc
class _$BackgroundJobsStateCopyWithImpl<$Res>
    implements $BackgroundJobsStateCopyWith<$Res> {
  _$BackgroundJobsStateCopyWithImpl(this._self, this._then);

  final BackgroundJobsState _self;
  final $Res Function(BackgroundJobsState) _then;

/// Create a copy of BackgroundJobsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? active = null,Object? sourceRevisions = null,}) {
  return _then(_self.copyWith(
active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as IMap<int, BackgroundJob>,sourceRevisions: null == sourceRevisions ? _self.sourceRevisions : sourceRevisions // ignore: cast_nullable_to_non_nullable
as IMap<int, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [BackgroundJobsState].
extension BackgroundJobsStatePatterns on BackgroundJobsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BackgroundJobsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BackgroundJobsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BackgroundJobsState value)  $default,){
final _that = this;
switch (_that) {
case _BackgroundJobsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BackgroundJobsState value)?  $default,){
final _that = this;
switch (_that) {
case _BackgroundJobsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IMap<int, BackgroundJob> active,  IMap<int, int> sourceRevisions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BackgroundJobsState() when $default != null:
return $default(_that.active,_that.sourceRevisions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IMap<int, BackgroundJob> active,  IMap<int, int> sourceRevisions)  $default,) {final _that = this;
switch (_that) {
case _BackgroundJobsState():
return $default(_that.active,_that.sourceRevisions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IMap<int, BackgroundJob> active,  IMap<int, int> sourceRevisions)?  $default,) {final _that = this;
switch (_that) {
case _BackgroundJobsState() when $default != null:
return $default(_that.active,_that.sourceRevisions);case _:
  return null;

}
}

}

/// @nodoc


class _BackgroundJobsState extends BackgroundJobsState {
  const _BackgroundJobsState({this.active = const IMapConst<int, BackgroundJob>({}), this.sourceRevisions = const IMapConst<int, int>({})}): super._();
  

/// Unfinished jobs by id. Finished jobs are removed.
@override@JsonKey() final  IMap<int, BackgroundJob> active;
/// Bumped each time a job that changed an audio source completes, keyed by
/// source ID. Watch an entry to refetch that source.
@override@JsonKey() final  IMap<int, int> sourceRevisions;

/// Create a copy of BackgroundJobsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BackgroundJobsStateCopyWith<_BackgroundJobsState> get copyWith => __$BackgroundJobsStateCopyWithImpl<_BackgroundJobsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BackgroundJobsState&&(identical(other.active, active) || other.active == active)&&(identical(other.sourceRevisions, sourceRevisions) || other.sourceRevisions == sourceRevisions));
}


@override
int get hashCode => Object.hash(runtimeType,active,sourceRevisions);

@override
String toString() {
  return 'BackgroundJobsState(active: $active, sourceRevisions: $sourceRevisions)';
}


}

/// @nodoc
abstract mixin class _$BackgroundJobsStateCopyWith<$Res> implements $BackgroundJobsStateCopyWith<$Res> {
  factory _$BackgroundJobsStateCopyWith(_BackgroundJobsState value, $Res Function(_BackgroundJobsState) _then) = __$BackgroundJobsStateCopyWithImpl;
@override @useResult
$Res call({
 IMap<int, BackgroundJob> active, IMap<int, int> sourceRevisions
});




}
/// @nodoc
class __$BackgroundJobsStateCopyWithImpl<$Res>
    implements _$BackgroundJobsStateCopyWith<$Res> {
  __$BackgroundJobsStateCopyWithImpl(this._self, this._then);

  final _BackgroundJobsState _self;
  final $Res Function(_BackgroundJobsState) _then;

/// Create a copy of BackgroundJobsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? active = null,Object? sourceRevisions = null,}) {
  return _then(_BackgroundJobsState(
active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as IMap<int, BackgroundJob>,sourceRevisions: null == sourceRevisions ? _self.sourceRevisions : sourceRevisions // ignore: cast_nullable_to_non_nullable
as IMap<int, int>,
  ));
}


}

// dart format on
