// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'automation_curve_template.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutomationCurveTemplate {

/// Stable identifier, unique inside the library
 String get id;/// Name shown in the template menus
 String get name;/// Length of the saved range in ticks
 int get lengthTicks;/// Points with times relative to the start of the saved range
 IList<AutomationPointDto> get points;
/// Create a copy of AutomationCurveTemplate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationCurveTemplateCopyWith<AutomationCurveTemplate> get copyWith => _$AutomationCurveTemplateCopyWithImpl<AutomationCurveTemplate>(this as AutomationCurveTemplate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationCurveTemplate&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.lengthTicks, lengthTicks) || other.lengthTicks == lengthTicks)&&const DeepCollectionEquality().equals(other.points, points));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,lengthTicks,const DeepCollectionEquality().hash(points));

@override
String toString() {
  return 'AutomationCurveTemplate(id: $id, name: $name, lengthTicks: $lengthTicks, points: $points)';
}


}

/// @nodoc
abstract mixin class $AutomationCurveTemplateCopyWith<$Res>  {
  factory $AutomationCurveTemplateCopyWith(AutomationCurveTemplate value, $Res Function(AutomationCurveTemplate) _then) = _$AutomationCurveTemplateCopyWithImpl;
@useResult
$Res call({
 String id, String name, int lengthTicks, IList<AutomationPointDto> points
});




}
/// @nodoc
class _$AutomationCurveTemplateCopyWithImpl<$Res>
    implements $AutomationCurveTemplateCopyWith<$Res> {
  _$AutomationCurveTemplateCopyWithImpl(this._self, this._then);

  final AutomationCurveTemplate _self;
  final $Res Function(AutomationCurveTemplate) _then;

/// Create a copy of AutomationCurveTemplate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? lengthTicks = null,Object? points = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lengthTicks: null == lengthTicks ? _self.lengthTicks : lengthTicks // ignore: cast_nullable_to_non_nullable
as int,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as IList<AutomationPointDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [AutomationCurveTemplate].
extension AutomationCurveTemplatePatterns on AutomationCurveTemplate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutomationCurveTemplate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutomationCurveTemplate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutomationCurveTemplate value)  $default,){
final _that = this;
switch (_that) {
case _AutomationCurveTemplate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutomationCurveTemplate value)?  $default,){
final _that = this;
switch (_that) {
case _AutomationCurveTemplate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int lengthTicks,  IList<AutomationPointDto> points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutomationCurveTemplate() when $default != null:
return $default(_that.id,_that.name,_that.lengthTicks,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int lengthTicks,  IList<AutomationPointDto> points)  $default,) {final _that = this;
switch (_that) {
case _AutomationCurveTemplate():
return $default(_that.id,_that.name,_that.lengthTicks,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int lengthTicks,  IList<AutomationPointDto> points)?  $default,) {final _that = this;
switch (_that) {
case _AutomationCurveTemplate() when $default != null:
return $default(_that.id,_that.name,_that.lengthTicks,_that.points);case _:
  return null;

}
}

}

/// @nodoc


class _AutomationCurveTemplate implements AutomationCurveTemplate {
  const _AutomationCurveTemplate({required this.id, required this.name, required this.lengthTicks, required this.points});
  

/// Stable identifier, unique inside the library
@override final  String id;
/// Name shown in the template menus
@override final  String name;
/// Length of the saved range in ticks
@override final  int lengthTicks;
/// Points with times relative to the start of the saved range
@override final  IList<AutomationPointDto> points;

/// Create a copy of AutomationCurveTemplate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutomationCurveTemplateCopyWith<_AutomationCurveTemplate> get copyWith => __$AutomationCurveTemplateCopyWithImpl<_AutomationCurveTemplate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutomationCurveTemplate&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.lengthTicks, lengthTicks) || other.lengthTicks == lengthTicks)&&const DeepCollectionEquality().equals(other.points, points));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,lengthTicks,const DeepCollectionEquality().hash(points));

@override
String toString() {
  return 'AutomationCurveTemplate(id: $id, name: $name, lengthTicks: $lengthTicks, points: $points)';
}


}

/// @nodoc
abstract mixin class _$AutomationCurveTemplateCopyWith<$Res> implements $AutomationCurveTemplateCopyWith<$Res> {
  factory _$AutomationCurveTemplateCopyWith(_AutomationCurveTemplate value, $Res Function(_AutomationCurveTemplate) _then) = __$AutomationCurveTemplateCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int lengthTicks, IList<AutomationPointDto> points
});




}
/// @nodoc
class __$AutomationCurveTemplateCopyWithImpl<$Res>
    implements _$AutomationCurveTemplateCopyWith<$Res> {
  __$AutomationCurveTemplateCopyWithImpl(this._self, this._then);

  final _AutomationCurveTemplate _self;
  final $Res Function(_AutomationCurveTemplate) _then;

/// Create a copy of AutomationCurveTemplate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? lengthTicks = null,Object? points = null,}) {
  return _then(_AutomationCurveTemplate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lengthTicks: null == lengthTicks ? _self.lengthTicks : lengthTicks // ignore: cast_nullable_to_non_nullable
as int,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as IList<AutomationPointDto>,
  ));
}


}

// dart format on
