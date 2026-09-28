// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectSettingsState {

 UiProjectMetadata? get metadata; bool get hasProject;
/// Create a copy of ProjectSettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSettingsStateCopyWith<ProjectSettingsState> get copyWith => _$ProjectSettingsStateCopyWithImpl<ProjectSettingsState>(this as ProjectSettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSettingsState&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.hasProject, hasProject) || other.hasProject == hasProject));
}


@override
int get hashCode => Object.hash(runtimeType,metadata,hasProject);

@override
String toString() {
  return 'ProjectSettingsState(metadata: $metadata, hasProject: $hasProject)';
}


}

/// @nodoc
abstract mixin class $ProjectSettingsStateCopyWith<$Res>  {
  factory $ProjectSettingsStateCopyWith(ProjectSettingsState value, $Res Function(ProjectSettingsState) _then) = _$ProjectSettingsStateCopyWithImpl;
@useResult
$Res call({
 UiProjectMetadata? metadata, bool hasProject
});


$UiProjectMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$ProjectSettingsStateCopyWithImpl<$Res>
    implements $ProjectSettingsStateCopyWith<$Res> {
  _$ProjectSettingsStateCopyWithImpl(this._self, this._then);

  final ProjectSettingsState _self;
  final $Res Function(ProjectSettingsState) _then;

/// Create a copy of ProjectSettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? metadata = freezed,Object? hasProject = null,}) {
  return _then(_self.copyWith(
metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as UiProjectMetadata?,hasProject: null == hasProject ? _self.hasProject : hasProject // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ProjectSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiProjectMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $UiProjectMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProjectSettingsState].
extension ProjectSettingsStatePatterns on ProjectSettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSettingsState value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiProjectMetadata? metadata,  bool hasProject)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSettingsState() when $default != null:
return $default(_that.metadata,_that.hasProject);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiProjectMetadata? metadata,  bool hasProject)  $default,) {final _that = this;
switch (_that) {
case _ProjectSettingsState():
return $default(_that.metadata,_that.hasProject);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiProjectMetadata? metadata,  bool hasProject)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSettingsState() when $default != null:
return $default(_that.metadata,_that.hasProject);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectSettingsState implements ProjectSettingsState {
  const _ProjectSettingsState({this.metadata, this.hasProject = false});
  

@override final  UiProjectMetadata? metadata;
@override@JsonKey() final  bool hasProject;

/// Create a copy of ProjectSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSettingsStateCopyWith<_ProjectSettingsState> get copyWith => __$ProjectSettingsStateCopyWithImpl<_ProjectSettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSettingsState&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.hasProject, hasProject) || other.hasProject == hasProject));
}


@override
int get hashCode => Object.hash(runtimeType,metadata,hasProject);

@override
String toString() {
  return 'ProjectSettingsState(metadata: $metadata, hasProject: $hasProject)';
}


}

/// @nodoc
abstract mixin class _$ProjectSettingsStateCopyWith<$Res> implements $ProjectSettingsStateCopyWith<$Res> {
  factory _$ProjectSettingsStateCopyWith(_ProjectSettingsState value, $Res Function(_ProjectSettingsState) _then) = __$ProjectSettingsStateCopyWithImpl;
@override @useResult
$Res call({
 UiProjectMetadata? metadata, bool hasProject
});


@override $UiProjectMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class __$ProjectSettingsStateCopyWithImpl<$Res>
    implements _$ProjectSettingsStateCopyWith<$Res> {
  __$ProjectSettingsStateCopyWithImpl(this._self, this._then);

  final _ProjectSettingsState _self;
  final $Res Function(_ProjectSettingsState) _then;

/// Create a copy of ProjectSettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? metadata = freezed,Object? hasProject = null,}) {
  return _then(_ProjectSettingsState(
metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as UiProjectMetadata?,hasProject: null == hasProject ? _self.hasProject : hasProject // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ProjectSettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiProjectMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $UiProjectMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}

// dart format on
