// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'automation_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutomationDataState {

 bool get isMasterAutomationDrawerOpened;/// Tracks which track automations are collapsed.
/// If a trackId is NOT in this set, it is considered expanded (defaults to true).
 ISet<int> get collapsedTrackAutomations;/// Tracks which bus automations are collapsed.
 ISet<int> get collapsedBusAutomations;/// Optional: Tracks the currently selected/highlighted automation lane in the UI
 int? get selectedAutomationLaneId;
/// Create a copy of AutomationDataState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationDataStateCopyWith<AutomationDataState> get copyWith => _$AutomationDataStateCopyWithImpl<AutomationDataState>(this as AutomationDataState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationDataState&&(identical(other.isMasterAutomationDrawerOpened, isMasterAutomationDrawerOpened) || other.isMasterAutomationDrawerOpened == isMasterAutomationDrawerOpened)&&const DeepCollectionEquality().equals(other.collapsedTrackAutomations, collapsedTrackAutomations)&&const DeepCollectionEquality().equals(other.collapsedBusAutomations, collapsedBusAutomations)&&(identical(other.selectedAutomationLaneId, selectedAutomationLaneId) || other.selectedAutomationLaneId == selectedAutomationLaneId));
}


@override
int get hashCode => Object.hash(runtimeType,isMasterAutomationDrawerOpened,const DeepCollectionEquality().hash(collapsedTrackAutomations),const DeepCollectionEquality().hash(collapsedBusAutomations),selectedAutomationLaneId);

@override
String toString() {
  return 'AutomationDataState(isMasterAutomationDrawerOpened: $isMasterAutomationDrawerOpened, collapsedTrackAutomations: $collapsedTrackAutomations, collapsedBusAutomations: $collapsedBusAutomations, selectedAutomationLaneId: $selectedAutomationLaneId)';
}


}

/// @nodoc
abstract mixin class $AutomationDataStateCopyWith<$Res>  {
  factory $AutomationDataStateCopyWith(AutomationDataState value, $Res Function(AutomationDataState) _then) = _$AutomationDataStateCopyWithImpl;
@useResult
$Res call({
 bool isMasterAutomationDrawerOpened, ISet<int> collapsedTrackAutomations, ISet<int> collapsedBusAutomations, int? selectedAutomationLaneId
});




}
/// @nodoc
class _$AutomationDataStateCopyWithImpl<$Res>
    implements $AutomationDataStateCopyWith<$Res> {
  _$AutomationDataStateCopyWithImpl(this._self, this._then);

  final AutomationDataState _self;
  final $Res Function(AutomationDataState) _then;

/// Create a copy of AutomationDataState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isMasterAutomationDrawerOpened = null,Object? collapsedTrackAutomations = null,Object? collapsedBusAutomations = null,Object? selectedAutomationLaneId = freezed,}) {
  return _then(_self.copyWith(
isMasterAutomationDrawerOpened: null == isMasterAutomationDrawerOpened ? _self.isMasterAutomationDrawerOpened : isMasterAutomationDrawerOpened // ignore: cast_nullable_to_non_nullable
as bool,collapsedTrackAutomations: null == collapsedTrackAutomations ? _self.collapsedTrackAutomations : collapsedTrackAutomations // ignore: cast_nullable_to_non_nullable
as ISet<int>,collapsedBusAutomations: null == collapsedBusAutomations ? _self.collapsedBusAutomations : collapsedBusAutomations // ignore: cast_nullable_to_non_nullable
as ISet<int>,selectedAutomationLaneId: freezed == selectedAutomationLaneId ? _self.selectedAutomationLaneId : selectedAutomationLaneId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AutomationDataState].
extension AutomationDataStatePatterns on AutomationDataState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutomationDataState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutomationDataState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutomationDataState value)  $default,){
final _that = this;
switch (_that) {
case _AutomationDataState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutomationDataState value)?  $default,){
final _that = this;
switch (_that) {
case _AutomationDataState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isMasterAutomationDrawerOpened,  ISet<int> collapsedTrackAutomations,  ISet<int> collapsedBusAutomations,  int? selectedAutomationLaneId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutomationDataState() when $default != null:
return $default(_that.isMasterAutomationDrawerOpened,_that.collapsedTrackAutomations,_that.collapsedBusAutomations,_that.selectedAutomationLaneId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isMasterAutomationDrawerOpened,  ISet<int> collapsedTrackAutomations,  ISet<int> collapsedBusAutomations,  int? selectedAutomationLaneId)  $default,) {final _that = this;
switch (_that) {
case _AutomationDataState():
return $default(_that.isMasterAutomationDrawerOpened,_that.collapsedTrackAutomations,_that.collapsedBusAutomations,_that.selectedAutomationLaneId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isMasterAutomationDrawerOpened,  ISet<int> collapsedTrackAutomations,  ISet<int> collapsedBusAutomations,  int? selectedAutomationLaneId)?  $default,) {final _that = this;
switch (_that) {
case _AutomationDataState() when $default != null:
return $default(_that.isMasterAutomationDrawerOpened,_that.collapsedTrackAutomations,_that.collapsedBusAutomations,_that.selectedAutomationLaneId);case _:
  return null;

}
}

}

/// @nodoc


class _AutomationDataState implements AutomationDataState {
  const _AutomationDataState({this.isMasterAutomationDrawerOpened = false, this.collapsedTrackAutomations = const ISetConst({}), this.collapsedBusAutomations = const ISetConst({}), this.selectedAutomationLaneId});
  

@override@JsonKey() final  bool isMasterAutomationDrawerOpened;
/// Tracks which track automations are collapsed.
/// If a trackId is NOT in this set, it is considered expanded (defaults to true).
@override@JsonKey() final  ISet<int> collapsedTrackAutomations;
/// Tracks which bus automations are collapsed.
@override@JsonKey() final  ISet<int> collapsedBusAutomations;
/// Optional: Tracks the currently selected/highlighted automation lane in the UI
@override final  int? selectedAutomationLaneId;

/// Create a copy of AutomationDataState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutomationDataStateCopyWith<_AutomationDataState> get copyWith => __$AutomationDataStateCopyWithImpl<_AutomationDataState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutomationDataState&&(identical(other.isMasterAutomationDrawerOpened, isMasterAutomationDrawerOpened) || other.isMasterAutomationDrawerOpened == isMasterAutomationDrawerOpened)&&const DeepCollectionEquality().equals(other.collapsedTrackAutomations, collapsedTrackAutomations)&&const DeepCollectionEquality().equals(other.collapsedBusAutomations, collapsedBusAutomations)&&(identical(other.selectedAutomationLaneId, selectedAutomationLaneId) || other.selectedAutomationLaneId == selectedAutomationLaneId));
}


@override
int get hashCode => Object.hash(runtimeType,isMasterAutomationDrawerOpened,const DeepCollectionEquality().hash(collapsedTrackAutomations),const DeepCollectionEquality().hash(collapsedBusAutomations),selectedAutomationLaneId);

@override
String toString() {
  return 'AutomationDataState(isMasterAutomationDrawerOpened: $isMasterAutomationDrawerOpened, collapsedTrackAutomations: $collapsedTrackAutomations, collapsedBusAutomations: $collapsedBusAutomations, selectedAutomationLaneId: $selectedAutomationLaneId)';
}


}

/// @nodoc
abstract mixin class _$AutomationDataStateCopyWith<$Res> implements $AutomationDataStateCopyWith<$Res> {
  factory _$AutomationDataStateCopyWith(_AutomationDataState value, $Res Function(_AutomationDataState) _then) = __$AutomationDataStateCopyWithImpl;
@override @useResult
$Res call({
 bool isMasterAutomationDrawerOpened, ISet<int> collapsedTrackAutomations, ISet<int> collapsedBusAutomations, int? selectedAutomationLaneId
});




}
/// @nodoc
class __$AutomationDataStateCopyWithImpl<$Res>
    implements _$AutomationDataStateCopyWith<$Res> {
  __$AutomationDataStateCopyWithImpl(this._self, this._then);

  final _AutomationDataState _self;
  final $Res Function(_AutomationDataState) _then;

/// Create a copy of AutomationDataState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isMasterAutomationDrawerOpened = null,Object? collapsedTrackAutomations = null,Object? collapsedBusAutomations = null,Object? selectedAutomationLaneId = freezed,}) {
  return _then(_AutomationDataState(
isMasterAutomationDrawerOpened: null == isMasterAutomationDrawerOpened ? _self.isMasterAutomationDrawerOpened : isMasterAutomationDrawerOpened // ignore: cast_nullable_to_non_nullable
as bool,collapsedTrackAutomations: null == collapsedTrackAutomations ? _self.collapsedTrackAutomations : collapsedTrackAutomations // ignore: cast_nullable_to_non_nullable
as ISet<int>,collapsedBusAutomations: null == collapsedBusAutomations ? _self.collapsedBusAutomations : collapsedBusAutomations // ignore: cast_nullable_to_non_nullable
as ISet<int>,selectedAutomationLaneId: freezed == selectedAutomationLaneId ? _self.selectedAutomationLaneId : selectedAutomationLaneId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
