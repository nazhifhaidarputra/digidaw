// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'automation_lane_editor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutomationLaneEditorState {

/// The ID of the hovered automation lane
 int? get hoveredLaneId;/// The ID of the hovererd point in an automation lane
 int? get hoveredPointId;/// The currently opened context automation lane ID
 int? get contextLaneId;/// The currently opened context automation point ID
 int? get contextPointId;/// The clipboard for automation lane point value
 AutomationLanePointClipboard get clipboard;
/// Create a copy of AutomationLaneEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationLaneEditorStateCopyWith<AutomationLaneEditorState> get copyWith => _$AutomationLaneEditorStateCopyWithImpl<AutomationLaneEditorState>(this as AutomationLaneEditorState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationLaneEditorState&&(identical(other.hoveredLaneId, hoveredLaneId) || other.hoveredLaneId == hoveredLaneId)&&(identical(other.hoveredPointId, hoveredPointId) || other.hoveredPointId == hoveredPointId)&&(identical(other.contextLaneId, contextLaneId) || other.contextLaneId == contextLaneId)&&(identical(other.contextPointId, contextPointId) || other.contextPointId == contextPointId)&&(identical(other.clipboard, clipboard) || other.clipboard == clipboard));
}


@override
int get hashCode => Object.hash(runtimeType,hoveredLaneId,hoveredPointId,contextLaneId,contextPointId,clipboard);

@override
String toString() {
  return 'AutomationLaneEditorState(hoveredLaneId: $hoveredLaneId, hoveredPointId: $hoveredPointId, contextLaneId: $contextLaneId, contextPointId: $contextPointId, clipboard: $clipboard)';
}


}

/// @nodoc
abstract mixin class $AutomationLaneEditorStateCopyWith<$Res>  {
  factory $AutomationLaneEditorStateCopyWith(AutomationLaneEditorState value, $Res Function(AutomationLaneEditorState) _then) = _$AutomationLaneEditorStateCopyWithImpl;
@useResult
$Res call({
 int? hoveredLaneId, int? hoveredPointId, int? contextLaneId, int? contextPointId, AutomationLanePointClipboard clipboard
});


$AutomationLanePointClipboardCopyWith<$Res> get clipboard;

}
/// @nodoc
class _$AutomationLaneEditorStateCopyWithImpl<$Res>
    implements $AutomationLaneEditorStateCopyWith<$Res> {
  _$AutomationLaneEditorStateCopyWithImpl(this._self, this._then);

  final AutomationLaneEditorState _self;
  final $Res Function(AutomationLaneEditorState) _then;

/// Create a copy of AutomationLaneEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hoveredLaneId = freezed,Object? hoveredPointId = freezed,Object? contextLaneId = freezed,Object? contextPointId = freezed,Object? clipboard = null,}) {
  return _then(_self.copyWith(
hoveredLaneId: freezed == hoveredLaneId ? _self.hoveredLaneId : hoveredLaneId // ignore: cast_nullable_to_non_nullable
as int?,hoveredPointId: freezed == hoveredPointId ? _self.hoveredPointId : hoveredPointId // ignore: cast_nullable_to_non_nullable
as int?,contextLaneId: freezed == contextLaneId ? _self.contextLaneId : contextLaneId // ignore: cast_nullable_to_non_nullable
as int?,contextPointId: freezed == contextPointId ? _self.contextPointId : contextPointId // ignore: cast_nullable_to_non_nullable
as int?,clipboard: null == clipboard ? _self.clipboard : clipboard // ignore: cast_nullable_to_non_nullable
as AutomationLanePointClipboard,
  ));
}
/// Create a copy of AutomationLaneEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AutomationLanePointClipboardCopyWith<$Res> get clipboard {
  
  return $AutomationLanePointClipboardCopyWith<$Res>(_self.clipboard, (value) {
    return _then(_self.copyWith(clipboard: value));
  });
}
}


/// Adds pattern-matching-related methods to [AutomationLaneEditorState].
extension AutomationLaneEditorStatePatterns on AutomationLaneEditorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutomationLaneEditorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutomationLaneEditorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutomationLaneEditorState value)  $default,){
final _that = this;
switch (_that) {
case _AutomationLaneEditorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutomationLaneEditorState value)?  $default,){
final _that = this;
switch (_that) {
case _AutomationLaneEditorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? hoveredLaneId,  int? hoveredPointId,  int? contextLaneId,  int? contextPointId,  AutomationLanePointClipboard clipboard)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutomationLaneEditorState() when $default != null:
return $default(_that.hoveredLaneId,_that.hoveredPointId,_that.contextLaneId,_that.contextPointId,_that.clipboard);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? hoveredLaneId,  int? hoveredPointId,  int? contextLaneId,  int? contextPointId,  AutomationLanePointClipboard clipboard)  $default,) {final _that = this;
switch (_that) {
case _AutomationLaneEditorState():
return $default(_that.hoveredLaneId,_that.hoveredPointId,_that.contextLaneId,_that.contextPointId,_that.clipboard);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? hoveredLaneId,  int? hoveredPointId,  int? contextLaneId,  int? contextPointId,  AutomationLanePointClipboard clipboard)?  $default,) {final _that = this;
switch (_that) {
case _AutomationLaneEditorState() when $default != null:
return $default(_that.hoveredLaneId,_that.hoveredPointId,_that.contextLaneId,_that.contextPointId,_that.clipboard);case _:
  return null;

}
}

}

/// @nodoc


class _AutomationLaneEditorState implements AutomationLaneEditorState {
  const _AutomationLaneEditorState({this.hoveredLaneId, this.hoveredPointId, this.contextLaneId, this.contextPointId, this.clipboard = const AutomationLanePointClipboard.empty()});
  

/// The ID of the hovered automation lane
@override final  int? hoveredLaneId;
/// The ID of the hovererd point in an automation lane
@override final  int? hoveredPointId;
/// The currently opened context automation lane ID
@override final  int? contextLaneId;
/// The currently opened context automation point ID
@override final  int? contextPointId;
/// The clipboard for automation lane point value
@override@JsonKey() final  AutomationLanePointClipboard clipboard;

/// Create a copy of AutomationLaneEditorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutomationLaneEditorStateCopyWith<_AutomationLaneEditorState> get copyWith => __$AutomationLaneEditorStateCopyWithImpl<_AutomationLaneEditorState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutomationLaneEditorState&&(identical(other.hoveredLaneId, hoveredLaneId) || other.hoveredLaneId == hoveredLaneId)&&(identical(other.hoveredPointId, hoveredPointId) || other.hoveredPointId == hoveredPointId)&&(identical(other.contextLaneId, contextLaneId) || other.contextLaneId == contextLaneId)&&(identical(other.contextPointId, contextPointId) || other.contextPointId == contextPointId)&&(identical(other.clipboard, clipboard) || other.clipboard == clipboard));
}


@override
int get hashCode => Object.hash(runtimeType,hoveredLaneId,hoveredPointId,contextLaneId,contextPointId,clipboard);

@override
String toString() {
  return 'AutomationLaneEditorState(hoveredLaneId: $hoveredLaneId, hoveredPointId: $hoveredPointId, contextLaneId: $contextLaneId, contextPointId: $contextPointId, clipboard: $clipboard)';
}


}

/// @nodoc
abstract mixin class _$AutomationLaneEditorStateCopyWith<$Res> implements $AutomationLaneEditorStateCopyWith<$Res> {
  factory _$AutomationLaneEditorStateCopyWith(_AutomationLaneEditorState value, $Res Function(_AutomationLaneEditorState) _then) = __$AutomationLaneEditorStateCopyWithImpl;
@override @useResult
$Res call({
 int? hoveredLaneId, int? hoveredPointId, int? contextLaneId, int? contextPointId, AutomationLanePointClipboard clipboard
});


@override $AutomationLanePointClipboardCopyWith<$Res> get clipboard;

}
/// @nodoc
class __$AutomationLaneEditorStateCopyWithImpl<$Res>
    implements _$AutomationLaneEditorStateCopyWith<$Res> {
  __$AutomationLaneEditorStateCopyWithImpl(this._self, this._then);

  final _AutomationLaneEditorState _self;
  final $Res Function(_AutomationLaneEditorState) _then;

/// Create a copy of AutomationLaneEditorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hoveredLaneId = freezed,Object? hoveredPointId = freezed,Object? contextLaneId = freezed,Object? contextPointId = freezed,Object? clipboard = null,}) {
  return _then(_AutomationLaneEditorState(
hoveredLaneId: freezed == hoveredLaneId ? _self.hoveredLaneId : hoveredLaneId // ignore: cast_nullable_to_non_nullable
as int?,hoveredPointId: freezed == hoveredPointId ? _self.hoveredPointId : hoveredPointId // ignore: cast_nullable_to_non_nullable
as int?,contextLaneId: freezed == contextLaneId ? _self.contextLaneId : contextLaneId // ignore: cast_nullable_to_non_nullable
as int?,contextPointId: freezed == contextPointId ? _self.contextPointId : contextPointId // ignore: cast_nullable_to_non_nullable
as int?,clipboard: null == clipboard ? _self.clipboard : clipboard // ignore: cast_nullable_to_non_nullable
as AutomationLanePointClipboard,
  ));
}

/// Create a copy of AutomationLaneEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AutomationLanePointClipboardCopyWith<$Res> get clipboard {
  
  return $AutomationLanePointClipboardCopyWith<$Res>(_self.clipboard, (value) {
    return _then(_self.copyWith(clipboard: value));
  });
}
}

// dart format on
