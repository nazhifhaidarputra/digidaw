// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'automation_lane_clipboard.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutomationLanePointClipboard {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationLanePointClipboard);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutomationLanePointClipboard()';
}


}

/// @nodoc
class $AutomationLanePointClipboardCopyWith<$Res>  {
$AutomationLanePointClipboardCopyWith(AutomationLanePointClipboard _, $Res Function(AutomationLanePointClipboard) __);
}


/// Adds pattern-matching-related methods to [AutomationLanePointClipboard].
extension AutomationLanePointClipboardPatterns on AutomationLanePointClipboard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AutomationLanePointClipboardEmpty value)?  empty,TResult Function( AutomationLanePointClipboardValue value)?  value,TResult Function( AutomationLanePointClipboardCurve value)?  curve,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AutomationLanePointClipboardEmpty() when empty != null:
return empty(_that);case AutomationLanePointClipboardValue() when value != null:
return value(_that);case AutomationLanePointClipboardCurve() when curve != null:
return curve(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AutomationLanePointClipboardEmpty value)  empty,required TResult Function( AutomationLanePointClipboardValue value)  value,required TResult Function( AutomationLanePointClipboardCurve value)  curve,}){
final _that = this;
switch (_that) {
case AutomationLanePointClipboardEmpty():
return empty(_that);case AutomationLanePointClipboardValue():
return value(_that);case AutomationLanePointClipboardCurve():
return curve(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AutomationLanePointClipboardEmpty value)?  empty,TResult? Function( AutomationLanePointClipboardValue value)?  value,TResult? Function( AutomationLanePointClipboardCurve value)?  curve,}){
final _that = this;
switch (_that) {
case AutomationLanePointClipboardEmpty() when empty != null:
return empty(_that);case AutomationLanePointClipboardValue() when value != null:
return value(_that);case AutomationLanePointClipboardCurve() when curve != null:
return curve(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  empty,TResult Function( double normalizedValue)?  value,TResult Function( IList<AutomationPointDto> points,  int lengthTicks)?  curve,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AutomationLanePointClipboardEmpty() when empty != null:
return empty();case AutomationLanePointClipboardValue() when value != null:
return value(_that.normalizedValue);case AutomationLanePointClipboardCurve() when curve != null:
return curve(_that.points,_that.lengthTicks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  empty,required TResult Function( double normalizedValue)  value,required TResult Function( IList<AutomationPointDto> points,  int lengthTicks)  curve,}) {final _that = this;
switch (_that) {
case AutomationLanePointClipboardEmpty():
return empty();case AutomationLanePointClipboardValue():
return value(_that.normalizedValue);case AutomationLanePointClipboardCurve():
return curve(_that.points,_that.lengthTicks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  empty,TResult? Function( double normalizedValue)?  value,TResult? Function( IList<AutomationPointDto> points,  int lengthTicks)?  curve,}) {final _that = this;
switch (_that) {
case AutomationLanePointClipboardEmpty() when empty != null:
return empty();case AutomationLanePointClipboardValue() when value != null:
return value(_that.normalizedValue);case AutomationLanePointClipboardCurve() when curve != null:
return curve(_that.points,_that.lengthTicks);case _:
  return null;

}
}

}

/// @nodoc


class AutomationLanePointClipboardEmpty implements AutomationLanePointClipboard {
  const AutomationLanePointClipboardEmpty();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationLanePointClipboardEmpty);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutomationLanePointClipboard.empty()';
}


}




/// @nodoc


class AutomationLanePointClipboardValue implements AutomationLanePointClipboard {
  const AutomationLanePointClipboardValue({required this.normalizedValue});
  

 final  double normalizedValue;

/// Create a copy of AutomationLanePointClipboard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationLanePointClipboardValueCopyWith<AutomationLanePointClipboardValue> get copyWith => _$AutomationLanePointClipboardValueCopyWithImpl<AutomationLanePointClipboardValue>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationLanePointClipboardValue&&(identical(other.normalizedValue, normalizedValue) || other.normalizedValue == normalizedValue));
}


@override
int get hashCode => Object.hash(runtimeType,normalizedValue);

@override
String toString() {
  return 'AutomationLanePointClipboard.value(normalizedValue: $normalizedValue)';
}


}

/// @nodoc
abstract mixin class $AutomationLanePointClipboardValueCopyWith<$Res> implements $AutomationLanePointClipboardCopyWith<$Res> {
  factory $AutomationLanePointClipboardValueCopyWith(AutomationLanePointClipboardValue value, $Res Function(AutomationLanePointClipboardValue) _then) = _$AutomationLanePointClipboardValueCopyWithImpl;
@useResult
$Res call({
 double normalizedValue
});




}
/// @nodoc
class _$AutomationLanePointClipboardValueCopyWithImpl<$Res>
    implements $AutomationLanePointClipboardValueCopyWith<$Res> {
  _$AutomationLanePointClipboardValueCopyWithImpl(this._self, this._then);

  final AutomationLanePointClipboardValue _self;
  final $Res Function(AutomationLanePointClipboardValue) _then;

/// Create a copy of AutomationLanePointClipboard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? normalizedValue = null,}) {
  return _then(AutomationLanePointClipboardValue(
normalizedValue: null == normalizedValue ? _self.normalizedValue : normalizedValue // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class AutomationLanePointClipboardCurve implements AutomationLanePointClipboard {
  const AutomationLanePointClipboardCurve({required this.points, required this.lengthTicks});
  

 final  IList<AutomationPointDto> points;
 final  int lengthTicks;

/// Create a copy of AutomationLanePointClipboard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationLanePointClipboardCurveCopyWith<AutomationLanePointClipboardCurve> get copyWith => _$AutomationLanePointClipboardCurveCopyWithImpl<AutomationLanePointClipboardCurve>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationLanePointClipboardCurve&&const DeepCollectionEquality().equals(other.points, points)&&(identical(other.lengthTicks, lengthTicks) || other.lengthTicks == lengthTicks));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(points),lengthTicks);

@override
String toString() {
  return 'AutomationLanePointClipboard.curve(points: $points, lengthTicks: $lengthTicks)';
}


}

/// @nodoc
abstract mixin class $AutomationLanePointClipboardCurveCopyWith<$Res> implements $AutomationLanePointClipboardCopyWith<$Res> {
  factory $AutomationLanePointClipboardCurveCopyWith(AutomationLanePointClipboardCurve value, $Res Function(AutomationLanePointClipboardCurve) _then) = _$AutomationLanePointClipboardCurveCopyWithImpl;
@useResult
$Res call({
 IList<AutomationPointDto> points, int lengthTicks
});




}
/// @nodoc
class _$AutomationLanePointClipboardCurveCopyWithImpl<$Res>
    implements $AutomationLanePointClipboardCurveCopyWith<$Res> {
  _$AutomationLanePointClipboardCurveCopyWithImpl(this._self, this._then);

  final AutomationLanePointClipboardCurve _self;
  final $Res Function(AutomationLanePointClipboardCurve) _then;

/// Create a copy of AutomationLanePointClipboard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? points = null,Object? lengthTicks = null,}) {
  return _then(AutomationLanePointClipboardCurve(
points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as IList<AutomationPointDto>,lengthTicks: null == lengthTicks ? _self.lengthTicks : lengthTicks // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
