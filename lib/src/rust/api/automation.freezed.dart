// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'automation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutomationLaneDto {

 int get id; String get label; List<AutomationPointDto> get points; bool get enabled; double get min; double get max; double get defaultValue;
/// Create a copy of AutomationLaneDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationLaneDtoCopyWith<AutomationLaneDto> get copyWith => _$AutomationLaneDtoCopyWithImpl<AutomationLaneDto>(this as AutomationLaneDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationLaneDto&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other.points, points)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,const DeepCollectionEquality().hash(points),enabled,min,max,defaultValue);

@override
String toString() {
  return 'AutomationLaneDto(id: $id, label: $label, points: $points, enabled: $enabled, min: $min, max: $max, defaultValue: $defaultValue)';
}


}

/// @nodoc
abstract mixin class $AutomationLaneDtoCopyWith<$Res>  {
  factory $AutomationLaneDtoCopyWith(AutomationLaneDto value, $Res Function(AutomationLaneDto) _then) = _$AutomationLaneDtoCopyWithImpl;
@useResult
$Res call({
 int id, String label, List<AutomationPointDto> points, bool enabled, double min, double max, double defaultValue
});




}
/// @nodoc
class _$AutomationLaneDtoCopyWithImpl<$Res>
    implements $AutomationLaneDtoCopyWith<$Res> {
  _$AutomationLaneDtoCopyWithImpl(this._self, this._then);

  final AutomationLaneDto _self;
  final $Res Function(AutomationLaneDto) _then;

/// Create a copy of AutomationLaneDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? points = null,Object? enabled = null,Object? min = null,Object? max = null,Object? defaultValue = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<AutomationPointDto>,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AutomationLaneDto].
extension AutomationLaneDtoPatterns on AutomationLaneDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutomationLaneDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutomationLaneDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutomationLaneDto value)  $default,){
final _that = this;
switch (_that) {
case _AutomationLaneDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutomationLaneDto value)?  $default,){
final _that = this;
switch (_that) {
case _AutomationLaneDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String label,  List<AutomationPointDto> points,  bool enabled,  double min,  double max,  double defaultValue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutomationLaneDto() when $default != null:
return $default(_that.id,_that.label,_that.points,_that.enabled,_that.min,_that.max,_that.defaultValue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String label,  List<AutomationPointDto> points,  bool enabled,  double min,  double max,  double defaultValue)  $default,) {final _that = this;
switch (_that) {
case _AutomationLaneDto():
return $default(_that.id,_that.label,_that.points,_that.enabled,_that.min,_that.max,_that.defaultValue);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String label,  List<AutomationPointDto> points,  bool enabled,  double min,  double max,  double defaultValue)?  $default,) {final _that = this;
switch (_that) {
case _AutomationLaneDto() when $default != null:
return $default(_that.id,_that.label,_that.points,_that.enabled,_that.min,_that.max,_that.defaultValue);case _:
  return null;

}
}

}

/// @nodoc


class _AutomationLaneDto implements AutomationLaneDto {
  const _AutomationLaneDto({required this.id, required this.label, required final  List<AutomationPointDto> points, required this.enabled, required this.min, required this.max, required this.defaultValue}): _points = points;
  

@override final  int id;
@override final  String label;
 final  List<AutomationPointDto> _points;
@override List<AutomationPointDto> get points {
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_points);
}

@override final  bool enabled;
@override final  double min;
@override final  double max;
@override final  double defaultValue;

/// Create a copy of AutomationLaneDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutomationLaneDtoCopyWith<_AutomationLaneDto> get copyWith => __$AutomationLaneDtoCopyWithImpl<_AutomationLaneDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutomationLaneDto&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other._points, _points)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue));
}


@override
int get hashCode => Object.hash(runtimeType,id,label,const DeepCollectionEquality().hash(_points),enabled,min,max,defaultValue);

@override
String toString() {
  return 'AutomationLaneDto(id: $id, label: $label, points: $points, enabled: $enabled, min: $min, max: $max, defaultValue: $defaultValue)';
}


}

/// @nodoc
abstract mixin class _$AutomationLaneDtoCopyWith<$Res> implements $AutomationLaneDtoCopyWith<$Res> {
  factory _$AutomationLaneDtoCopyWith(_AutomationLaneDto value, $Res Function(_AutomationLaneDto) _then) = __$AutomationLaneDtoCopyWithImpl;
@override @useResult
$Res call({
 int id, String label, List<AutomationPointDto> points, bool enabled, double min, double max, double defaultValue
});




}
/// @nodoc
class __$AutomationLaneDtoCopyWithImpl<$Res>
    implements _$AutomationLaneDtoCopyWith<$Res> {
  __$AutomationLaneDtoCopyWithImpl(this._self, this._then);

  final _AutomationLaneDto _self;
  final $Res Function(_AutomationLaneDto) _then;

/// Create a copy of AutomationLaneDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? points = null,Object? enabled = null,Object? min = null,Object? max = null,Object? defaultValue = null,}) {
  return _then(_AutomationLaneDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<AutomationPointDto>,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$AutomationPointDto {

 int get timeTicks; double get value; AutomationCurveTypeDto get curveType; double get tension;
/// Create a copy of AutomationPointDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationPointDtoCopyWith<AutomationPointDto> get copyWith => _$AutomationPointDtoCopyWithImpl<AutomationPointDto>(this as AutomationPointDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationPointDto&&(identical(other.timeTicks, timeTicks) || other.timeTicks == timeTicks)&&(identical(other.value, value) || other.value == value)&&(identical(other.curveType, curveType) || other.curveType == curveType)&&(identical(other.tension, tension) || other.tension == tension));
}


@override
int get hashCode => Object.hash(runtimeType,timeTicks,value,curveType,tension);

@override
String toString() {
  return 'AutomationPointDto(timeTicks: $timeTicks, value: $value, curveType: $curveType, tension: $tension)';
}


}

/// @nodoc
abstract mixin class $AutomationPointDtoCopyWith<$Res>  {
  factory $AutomationPointDtoCopyWith(AutomationPointDto value, $Res Function(AutomationPointDto) _then) = _$AutomationPointDtoCopyWithImpl;
@useResult
$Res call({
 int timeTicks, double value, AutomationCurveTypeDto curveType, double tension
});




}
/// @nodoc
class _$AutomationPointDtoCopyWithImpl<$Res>
    implements $AutomationPointDtoCopyWith<$Res> {
  _$AutomationPointDtoCopyWithImpl(this._self, this._then);

  final AutomationPointDto _self;
  final $Res Function(AutomationPointDto) _then;

/// Create a copy of AutomationPointDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timeTicks = null,Object? value = null,Object? curveType = null,Object? tension = null,}) {
  return _then(_self.copyWith(
timeTicks: null == timeTicks ? _self.timeTicks : timeTicks // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,curveType: null == curveType ? _self.curveType : curveType // ignore: cast_nullable_to_non_nullable
as AutomationCurveTypeDto,tension: null == tension ? _self.tension : tension // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AutomationPointDto].
extension AutomationPointDtoPatterns on AutomationPointDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutomationPointDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutomationPointDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutomationPointDto value)  $default,){
final _that = this;
switch (_that) {
case _AutomationPointDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutomationPointDto value)?  $default,){
final _that = this;
switch (_that) {
case _AutomationPointDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int timeTicks,  double value,  AutomationCurveTypeDto curveType,  double tension)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutomationPointDto() when $default != null:
return $default(_that.timeTicks,_that.value,_that.curveType,_that.tension);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int timeTicks,  double value,  AutomationCurveTypeDto curveType,  double tension)  $default,) {final _that = this;
switch (_that) {
case _AutomationPointDto():
return $default(_that.timeTicks,_that.value,_that.curveType,_that.tension);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int timeTicks,  double value,  AutomationCurveTypeDto curveType,  double tension)?  $default,) {final _that = this;
switch (_that) {
case _AutomationPointDto() when $default != null:
return $default(_that.timeTicks,_that.value,_that.curveType,_that.tension);case _:
  return null;

}
}

}

/// @nodoc


class _AutomationPointDto implements AutomationPointDto {
  const _AutomationPointDto({required this.timeTicks, required this.value, required this.curveType, required this.tension});
  

@override final  int timeTicks;
@override final  double value;
@override final  AutomationCurveTypeDto curveType;
@override final  double tension;

/// Create a copy of AutomationPointDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutomationPointDtoCopyWith<_AutomationPointDto> get copyWith => __$AutomationPointDtoCopyWithImpl<_AutomationPointDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutomationPointDto&&(identical(other.timeTicks, timeTicks) || other.timeTicks == timeTicks)&&(identical(other.value, value) || other.value == value)&&(identical(other.curveType, curveType) || other.curveType == curveType)&&(identical(other.tension, tension) || other.tension == tension));
}


@override
int get hashCode => Object.hash(runtimeType,timeTicks,value,curveType,tension);

@override
String toString() {
  return 'AutomationPointDto(timeTicks: $timeTicks, value: $value, curveType: $curveType, tension: $tension)';
}


}

/// @nodoc
abstract mixin class _$AutomationPointDtoCopyWith<$Res> implements $AutomationPointDtoCopyWith<$Res> {
  factory _$AutomationPointDtoCopyWith(_AutomationPointDto value, $Res Function(_AutomationPointDto) _then) = __$AutomationPointDtoCopyWithImpl;
@override @useResult
$Res call({
 int timeTicks, double value, AutomationCurveTypeDto curveType, double tension
});




}
/// @nodoc
class __$AutomationPointDtoCopyWithImpl<$Res>
    implements _$AutomationPointDtoCopyWith<$Res> {
  __$AutomationPointDtoCopyWithImpl(this._self, this._then);

  final _AutomationPointDto _self;
  final $Res Function(_AutomationPointDto) _then;

/// Create a copy of AutomationPointDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timeTicks = null,Object? value = null,Object? curveType = null,Object? tension = null,}) {
  return _then(_AutomationPointDto(
timeTicks: null == timeTicks ? _self.timeTicks : timeTicks // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,curveType: null == curveType ? _self.curveType : curveType // ignore: cast_nullable_to_non_nullable
as AutomationCurveTypeDto,tension: null == tension ? _self.tension : tension // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$AutomationTargetDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutomationTargetDto()';
}


}

/// @nodoc
class $AutomationTargetDtoCopyWith<$Res>  {
$AutomationTargetDtoCopyWith(AutomationTargetDto _, $Res Function(AutomationTargetDto) __);
}


/// Adds pattern-matching-related methods to [AutomationTargetDto].
extension AutomationTargetDtoPatterns on AutomationTargetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AutomationTargetDto_Generator value)?  generator,TResult Function( AutomationTargetDto_Track value)?  track,TResult Function( AutomationTargetDto_Bus value)?  bus,TResult Function( AutomationTargetDto_Master value)?  master,TResult Function( AutomationTargetDto_TempoBpm value)?  tempoBpm,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AutomationTargetDto_Generator() when generator != null:
return generator(_that);case AutomationTargetDto_Track() when track != null:
return track(_that);case AutomationTargetDto_Bus() when bus != null:
return bus(_that);case AutomationTargetDto_Master() when master != null:
return master(_that);case AutomationTargetDto_TempoBpm() when tempoBpm != null:
return tempoBpm(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AutomationTargetDto_Generator value)  generator,required TResult Function( AutomationTargetDto_Track value)  track,required TResult Function( AutomationTargetDto_Bus value)  bus,required TResult Function( AutomationTargetDto_Master value)  master,required TResult Function( AutomationTargetDto_TempoBpm value)  tempoBpm,}){
final _that = this;
switch (_that) {
case AutomationTargetDto_Generator():
return generator(_that);case AutomationTargetDto_Track():
return track(_that);case AutomationTargetDto_Bus():
return bus(_that);case AutomationTargetDto_Master():
return master(_that);case AutomationTargetDto_TempoBpm():
return tempoBpm(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AutomationTargetDto_Generator value)?  generator,TResult? Function( AutomationTargetDto_Track value)?  track,TResult? Function( AutomationTargetDto_Bus value)?  bus,TResult? Function( AutomationTargetDto_Master value)?  master,TResult? Function( AutomationTargetDto_TempoBpm value)?  tempoBpm,}){
final _that = this;
switch (_that) {
case AutomationTargetDto_Generator() when generator != null:
return generator(_that);case AutomationTargetDto_Track() when track != null:
return track(_that);case AutomationTargetDto_Bus() when bus != null:
return bus(_that);case AutomationTargetDto_Master() when master != null:
return master(_that);case AutomationTargetDto_TempoBpm() when tempoBpm != null:
return tempoBpm(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int generatorId,  int paramId)?  generator,TResult Function( int trackId,  TrackAutomationTargetDto trackTarget)?  track,TResult Function( int busId,  MixerChannelParamTargetDto mixTarget)?  bus,TResult Function( MixerChannelParamTargetDto field0)?  master,TResult Function()?  tempoBpm,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AutomationTargetDto_Generator() when generator != null:
return generator(_that.generatorId,_that.paramId);case AutomationTargetDto_Track() when track != null:
return track(_that.trackId,_that.trackTarget);case AutomationTargetDto_Bus() when bus != null:
return bus(_that.busId,_that.mixTarget);case AutomationTargetDto_Master() when master != null:
return master(_that.field0);case AutomationTargetDto_TempoBpm() when tempoBpm != null:
return tempoBpm();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int generatorId,  int paramId)  generator,required TResult Function( int trackId,  TrackAutomationTargetDto trackTarget)  track,required TResult Function( int busId,  MixerChannelParamTargetDto mixTarget)  bus,required TResult Function( MixerChannelParamTargetDto field0)  master,required TResult Function()  tempoBpm,}) {final _that = this;
switch (_that) {
case AutomationTargetDto_Generator():
return generator(_that.generatorId,_that.paramId);case AutomationTargetDto_Track():
return track(_that.trackId,_that.trackTarget);case AutomationTargetDto_Bus():
return bus(_that.busId,_that.mixTarget);case AutomationTargetDto_Master():
return master(_that.field0);case AutomationTargetDto_TempoBpm():
return tempoBpm();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int generatorId,  int paramId)?  generator,TResult? Function( int trackId,  TrackAutomationTargetDto trackTarget)?  track,TResult? Function( int busId,  MixerChannelParamTargetDto mixTarget)?  bus,TResult? Function( MixerChannelParamTargetDto field0)?  master,TResult? Function()?  tempoBpm,}) {final _that = this;
switch (_that) {
case AutomationTargetDto_Generator() when generator != null:
return generator(_that.generatorId,_that.paramId);case AutomationTargetDto_Track() when track != null:
return track(_that.trackId,_that.trackTarget);case AutomationTargetDto_Bus() when bus != null:
return bus(_that.busId,_that.mixTarget);case AutomationTargetDto_Master() when master != null:
return master(_that.field0);case AutomationTargetDto_TempoBpm() when tempoBpm != null:
return tempoBpm();case _:
  return null;

}
}

}

/// @nodoc


class AutomationTargetDto_Generator extends AutomationTargetDto {
  const AutomationTargetDto_Generator({required this.generatorId, required this.paramId}): super._();
  

 final  int generatorId;
 final  int paramId;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationTargetDto_GeneratorCopyWith<AutomationTargetDto_Generator> get copyWith => _$AutomationTargetDto_GeneratorCopyWithImpl<AutomationTargetDto_Generator>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_Generator&&(identical(other.generatorId, generatorId) || other.generatorId == generatorId)&&(identical(other.paramId, paramId) || other.paramId == paramId));
}


@override
int get hashCode => Object.hash(runtimeType,generatorId,paramId);

@override
String toString() {
  return 'AutomationTargetDto.generator(generatorId: $generatorId, paramId: $paramId)';
}


}

/// @nodoc
abstract mixin class $AutomationTargetDto_GeneratorCopyWith<$Res> implements $AutomationTargetDtoCopyWith<$Res> {
  factory $AutomationTargetDto_GeneratorCopyWith(AutomationTargetDto_Generator value, $Res Function(AutomationTargetDto_Generator) _then) = _$AutomationTargetDto_GeneratorCopyWithImpl;
@useResult
$Res call({
 int generatorId, int paramId
});




}
/// @nodoc
class _$AutomationTargetDto_GeneratorCopyWithImpl<$Res>
    implements $AutomationTargetDto_GeneratorCopyWith<$Res> {
  _$AutomationTargetDto_GeneratorCopyWithImpl(this._self, this._then);

  final AutomationTargetDto_Generator _self;
  final $Res Function(AutomationTargetDto_Generator) _then;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? generatorId = null,Object? paramId = null,}) {
  return _then(AutomationTargetDto_Generator(
generatorId: null == generatorId ? _self.generatorId : generatorId // ignore: cast_nullable_to_non_nullable
as int,paramId: null == paramId ? _self.paramId : paramId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class AutomationTargetDto_Track extends AutomationTargetDto {
  const AutomationTargetDto_Track({required this.trackId, required this.trackTarget}): super._();
  

 final  int trackId;
 final  TrackAutomationTargetDto trackTarget;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationTargetDto_TrackCopyWith<AutomationTargetDto_Track> get copyWith => _$AutomationTargetDto_TrackCopyWithImpl<AutomationTargetDto_Track>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_Track&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.trackTarget, trackTarget) || other.trackTarget == trackTarget));
}


@override
int get hashCode => Object.hash(runtimeType,trackId,trackTarget);

@override
String toString() {
  return 'AutomationTargetDto.track(trackId: $trackId, trackTarget: $trackTarget)';
}


}

/// @nodoc
abstract mixin class $AutomationTargetDto_TrackCopyWith<$Res> implements $AutomationTargetDtoCopyWith<$Res> {
  factory $AutomationTargetDto_TrackCopyWith(AutomationTargetDto_Track value, $Res Function(AutomationTargetDto_Track) _then) = _$AutomationTargetDto_TrackCopyWithImpl;
@useResult
$Res call({
 int trackId, TrackAutomationTargetDto trackTarget
});


$TrackAutomationTargetDtoCopyWith<$Res> get trackTarget;

}
/// @nodoc
class _$AutomationTargetDto_TrackCopyWithImpl<$Res>
    implements $AutomationTargetDto_TrackCopyWith<$Res> {
  _$AutomationTargetDto_TrackCopyWithImpl(this._self, this._then);

  final AutomationTargetDto_Track _self;
  final $Res Function(AutomationTargetDto_Track) _then;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? trackTarget = null,}) {
  return _then(AutomationTargetDto_Track(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,trackTarget: null == trackTarget ? _self.trackTarget : trackTarget // ignore: cast_nullable_to_non_nullable
as TrackAutomationTargetDto,
  ));
}

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrackAutomationTargetDtoCopyWith<$Res> get trackTarget {
  
  return $TrackAutomationTargetDtoCopyWith<$Res>(_self.trackTarget, (value) {
    return _then(_self.copyWith(trackTarget: value));
  });
}
}

/// @nodoc


class AutomationTargetDto_Bus extends AutomationTargetDto {
  const AutomationTargetDto_Bus({required this.busId, required this.mixTarget}): super._();
  

 final  int busId;
 final  MixerChannelParamTargetDto mixTarget;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationTargetDto_BusCopyWith<AutomationTargetDto_Bus> get copyWith => _$AutomationTargetDto_BusCopyWithImpl<AutomationTargetDto_Bus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_Bus&&(identical(other.busId, busId) || other.busId == busId)&&(identical(other.mixTarget, mixTarget) || other.mixTarget == mixTarget));
}


@override
int get hashCode => Object.hash(runtimeType,busId,mixTarget);

@override
String toString() {
  return 'AutomationTargetDto.bus(busId: $busId, mixTarget: $mixTarget)';
}


}

/// @nodoc
abstract mixin class $AutomationTargetDto_BusCopyWith<$Res> implements $AutomationTargetDtoCopyWith<$Res> {
  factory $AutomationTargetDto_BusCopyWith(AutomationTargetDto_Bus value, $Res Function(AutomationTargetDto_Bus) _then) = _$AutomationTargetDto_BusCopyWithImpl;
@useResult
$Res call({
 int busId, MixerChannelParamTargetDto mixTarget
});


$MixerChannelParamTargetDtoCopyWith<$Res> get mixTarget;

}
/// @nodoc
class _$AutomationTargetDto_BusCopyWithImpl<$Res>
    implements $AutomationTargetDto_BusCopyWith<$Res> {
  _$AutomationTargetDto_BusCopyWithImpl(this._self, this._then);

  final AutomationTargetDto_Bus _self;
  final $Res Function(AutomationTargetDto_Bus) _then;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? busId = null,Object? mixTarget = null,}) {
  return _then(AutomationTargetDto_Bus(
busId: null == busId ? _self.busId : busId // ignore: cast_nullable_to_non_nullable
as int,mixTarget: null == mixTarget ? _self.mixTarget : mixTarget // ignore: cast_nullable_to_non_nullable
as MixerChannelParamTargetDto,
  ));
}

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MixerChannelParamTargetDtoCopyWith<$Res> get mixTarget {
  
  return $MixerChannelParamTargetDtoCopyWith<$Res>(_self.mixTarget, (value) {
    return _then(_self.copyWith(mixTarget: value));
  });
}
}

/// @nodoc


class AutomationTargetDto_Master extends AutomationTargetDto {
  const AutomationTargetDto_Master(this.field0): super._();
  

 final  MixerChannelParamTargetDto field0;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutomationTargetDto_MasterCopyWith<AutomationTargetDto_Master> get copyWith => _$AutomationTargetDto_MasterCopyWithImpl<AutomationTargetDto_Master>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_Master&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'AutomationTargetDto.master(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $AutomationTargetDto_MasterCopyWith<$Res> implements $AutomationTargetDtoCopyWith<$Res> {
  factory $AutomationTargetDto_MasterCopyWith(AutomationTargetDto_Master value, $Res Function(AutomationTargetDto_Master) _then) = _$AutomationTargetDto_MasterCopyWithImpl;
@useResult
$Res call({
 MixerChannelParamTargetDto field0
});


$MixerChannelParamTargetDtoCopyWith<$Res> get field0;

}
/// @nodoc
class _$AutomationTargetDto_MasterCopyWithImpl<$Res>
    implements $AutomationTargetDto_MasterCopyWith<$Res> {
  _$AutomationTargetDto_MasterCopyWithImpl(this._self, this._then);

  final AutomationTargetDto_Master _self;
  final $Res Function(AutomationTargetDto_Master) _then;

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(AutomationTargetDto_Master(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as MixerChannelParamTargetDto,
  ));
}

/// Create a copy of AutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MixerChannelParamTargetDtoCopyWith<$Res> get field0 {
  
  return $MixerChannelParamTargetDtoCopyWith<$Res>(_self.field0, (value) {
    return _then(_self.copyWith(field0: value));
  });
}
}

/// @nodoc


class AutomationTargetDto_TempoBpm extends AutomationTargetDto {
  const AutomationTargetDto_TempoBpm(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutomationTargetDto_TempoBpm);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutomationTargetDto.tempoBpm()';
}


}




/// @nodoc
mixin _$EffectAutomationTargetDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EffectAutomationTargetDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EffectAutomationTargetDto()';
}


}

/// @nodoc
class $EffectAutomationTargetDtoCopyWith<$Res>  {
$EffectAutomationTargetDtoCopyWith(EffectAutomationTargetDto _, $Res Function(EffectAutomationTargetDto) __);
}


/// Adds pattern-matching-related methods to [EffectAutomationTargetDto].
extension EffectAutomationTargetDtoPatterns on EffectAutomationTargetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( EffectAutomationTargetDto_Mix value)?  mix,TResult Function( EffectAutomationTargetDto_PluginParam value)?  pluginParam,required TResult orElse(),}){
final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix() when mix != null:
return mix(_that);case EffectAutomationTargetDto_PluginParam() when pluginParam != null:
return pluginParam(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( EffectAutomationTargetDto_Mix value)  mix,required TResult Function( EffectAutomationTargetDto_PluginParam value)  pluginParam,}){
final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix():
return mix(_that);case EffectAutomationTargetDto_PluginParam():
return pluginParam(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( EffectAutomationTargetDto_Mix value)?  mix,TResult? Function( EffectAutomationTargetDto_PluginParam value)?  pluginParam,}){
final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix() when mix != null:
return mix(_that);case EffectAutomationTargetDto_PluginParam() when pluginParam != null:
return pluginParam(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  mix,TResult Function( int paramId)?  pluginParam,required TResult orElse(),}) {final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix() when mix != null:
return mix();case EffectAutomationTargetDto_PluginParam() when pluginParam != null:
return pluginParam(_that.paramId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  mix,required TResult Function( int paramId)  pluginParam,}) {final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix():
return mix();case EffectAutomationTargetDto_PluginParam():
return pluginParam(_that.paramId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  mix,TResult? Function( int paramId)?  pluginParam,}) {final _that = this;
switch (_that) {
case EffectAutomationTargetDto_Mix() when mix != null:
return mix();case EffectAutomationTargetDto_PluginParam() when pluginParam != null:
return pluginParam(_that.paramId);case _:
  return null;

}
}

}

/// @nodoc


class EffectAutomationTargetDto_Mix extends EffectAutomationTargetDto {
  const EffectAutomationTargetDto_Mix(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EffectAutomationTargetDto_Mix);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'EffectAutomationTargetDto.mix()';
}


}




/// @nodoc


class EffectAutomationTargetDto_PluginParam extends EffectAutomationTargetDto {
  const EffectAutomationTargetDto_PluginParam({required this.paramId}): super._();
  

 final  int paramId;

/// Create a copy of EffectAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EffectAutomationTargetDto_PluginParamCopyWith<EffectAutomationTargetDto_PluginParam> get copyWith => _$EffectAutomationTargetDto_PluginParamCopyWithImpl<EffectAutomationTargetDto_PluginParam>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EffectAutomationTargetDto_PluginParam&&(identical(other.paramId, paramId) || other.paramId == paramId));
}


@override
int get hashCode => Object.hash(runtimeType,paramId);

@override
String toString() {
  return 'EffectAutomationTargetDto.pluginParam(paramId: $paramId)';
}


}

/// @nodoc
abstract mixin class $EffectAutomationTargetDto_PluginParamCopyWith<$Res> implements $EffectAutomationTargetDtoCopyWith<$Res> {
  factory $EffectAutomationTargetDto_PluginParamCopyWith(EffectAutomationTargetDto_PluginParam value, $Res Function(EffectAutomationTargetDto_PluginParam) _then) = _$EffectAutomationTargetDto_PluginParamCopyWithImpl;
@useResult
$Res call({
 int paramId
});




}
/// @nodoc
class _$EffectAutomationTargetDto_PluginParamCopyWithImpl<$Res>
    implements $EffectAutomationTargetDto_PluginParamCopyWith<$Res> {
  _$EffectAutomationTargetDto_PluginParamCopyWithImpl(this._self, this._then);

  final EffectAutomationTargetDto_PluginParam _self;
  final $Res Function(EffectAutomationTargetDto_PluginParam) _then;

/// Create a copy of EffectAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? paramId = null,}) {
  return _then(EffectAutomationTargetDto_PluginParam(
paramId: null == paramId ? _self.paramId : paramId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$MixerChannelParamTargetDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelParamTargetDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MixerChannelParamTargetDto()';
}


}

/// @nodoc
class $MixerChannelParamTargetDtoCopyWith<$Res>  {
$MixerChannelParamTargetDtoCopyWith(MixerChannelParamTargetDto _, $Res Function(MixerChannelParamTargetDto) __);
}


/// Adds pattern-matching-related methods to [MixerChannelParamTargetDto].
extension MixerChannelParamTargetDtoPatterns on MixerChannelParamTargetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( MixerChannelParamTargetDto_Volume value)?  volume,TResult Function( MixerChannelParamTargetDto_Pan value)?  pan,TResult Function( MixerChannelParamTargetDto_Plugin value)?  plugin,required TResult orElse(),}){
final _that = this;
switch (_that) {
case MixerChannelParamTargetDto_Volume() when volume != null:
return volume(_that);case MixerChannelParamTargetDto_Pan() when pan != null:
return pan(_that);case MixerChannelParamTargetDto_Plugin() when plugin != null:
return plugin(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( MixerChannelParamTargetDto_Volume value)  volume,required TResult Function( MixerChannelParamTargetDto_Pan value)  pan,required TResult Function( MixerChannelParamTargetDto_Plugin value)  plugin,}){
final _that = this;
switch (_that) {
case MixerChannelParamTargetDto_Volume():
return volume(_that);case MixerChannelParamTargetDto_Pan():
return pan(_that);case MixerChannelParamTargetDto_Plugin():
return plugin(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( MixerChannelParamTargetDto_Volume value)?  volume,TResult? Function( MixerChannelParamTargetDto_Pan value)?  pan,TResult? Function( MixerChannelParamTargetDto_Plugin value)?  plugin,}){
final _that = this;
switch (_that) {
case MixerChannelParamTargetDto_Volume() when volume != null:
return volume(_that);case MixerChannelParamTargetDto_Pan() when pan != null:
return pan(_that);case MixerChannelParamTargetDto_Plugin() when plugin != null:
return plugin(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  volume,TResult Function()?  pan,TResult Function( int effectId,  EffectAutomationTargetDto target)?  plugin,required TResult orElse(),}) {final _that = this;
switch (_that) {
case MixerChannelParamTargetDto_Volume() when volume != null:
return volume();case MixerChannelParamTargetDto_Pan() when pan != null:
return pan();case MixerChannelParamTargetDto_Plugin() when plugin != null:
return plugin(_that.effectId,_that.target);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  volume,required TResult Function()  pan,required TResult Function( int effectId,  EffectAutomationTargetDto target)  plugin,}) {final _that = this;
switch (_that) {
case MixerChannelParamTargetDto_Volume():
return volume();case MixerChannelParamTargetDto_Pan():
return pan();case MixerChannelParamTargetDto_Plugin():
return plugin(_that.effectId,_that.target);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  volume,TResult? Function()?  pan,TResult? Function( int effectId,  EffectAutomationTargetDto target)?  plugin,}) {final _that = this;
switch (_that) {
case MixerChannelParamTargetDto_Volume() when volume != null:
return volume();case MixerChannelParamTargetDto_Pan() when pan != null:
return pan();case MixerChannelParamTargetDto_Plugin() when plugin != null:
return plugin(_that.effectId,_that.target);case _:
  return null;

}
}

}

/// @nodoc


class MixerChannelParamTargetDto_Volume extends MixerChannelParamTargetDto {
  const MixerChannelParamTargetDto_Volume(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelParamTargetDto_Volume);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MixerChannelParamTargetDto.volume()';
}


}




/// @nodoc


class MixerChannelParamTargetDto_Pan extends MixerChannelParamTargetDto {
  const MixerChannelParamTargetDto_Pan(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelParamTargetDto_Pan);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MixerChannelParamTargetDto.pan()';
}


}




/// @nodoc


class MixerChannelParamTargetDto_Plugin extends MixerChannelParamTargetDto {
  const MixerChannelParamTargetDto_Plugin({required this.effectId, required this.target}): super._();
  

 final  int effectId;
 final  EffectAutomationTargetDto target;

/// Create a copy of MixerChannelParamTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MixerChannelParamTargetDto_PluginCopyWith<MixerChannelParamTargetDto_Plugin> get copyWith => _$MixerChannelParamTargetDto_PluginCopyWithImpl<MixerChannelParamTargetDto_Plugin>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MixerChannelParamTargetDto_Plugin&&(identical(other.effectId, effectId) || other.effectId == effectId)&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,effectId,target);

@override
String toString() {
  return 'MixerChannelParamTargetDto.plugin(effectId: $effectId, target: $target)';
}


}

/// @nodoc
abstract mixin class $MixerChannelParamTargetDto_PluginCopyWith<$Res> implements $MixerChannelParamTargetDtoCopyWith<$Res> {
  factory $MixerChannelParamTargetDto_PluginCopyWith(MixerChannelParamTargetDto_Plugin value, $Res Function(MixerChannelParamTargetDto_Plugin) _then) = _$MixerChannelParamTargetDto_PluginCopyWithImpl;
@useResult
$Res call({
 int effectId, EffectAutomationTargetDto target
});


$EffectAutomationTargetDtoCopyWith<$Res> get target;

}
/// @nodoc
class _$MixerChannelParamTargetDto_PluginCopyWithImpl<$Res>
    implements $MixerChannelParamTargetDto_PluginCopyWith<$Res> {
  _$MixerChannelParamTargetDto_PluginCopyWithImpl(this._self, this._then);

  final MixerChannelParamTargetDto_Plugin _self;
  final $Res Function(MixerChannelParamTargetDto_Plugin) _then;

/// Create a copy of MixerChannelParamTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? effectId = null,Object? target = null,}) {
  return _then(MixerChannelParamTargetDto_Plugin(
effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as EffectAutomationTargetDto,
  ));
}

/// Create a copy of MixerChannelParamTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EffectAutomationTargetDtoCopyWith<$Res> get target {
  
  return $EffectAutomationTargetDtoCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

/// @nodoc
mixin _$ModulationLinkDto {

 int get id; int get sourceId; AutomationTargetDto get target; double get depth; double get baseValue; int get orderIdx;
/// Create a copy of ModulationLinkDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModulationLinkDtoCopyWith<ModulationLinkDto> get copyWith => _$ModulationLinkDtoCopyWithImpl<ModulationLinkDto>(this as ModulationLinkDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModulationLinkDto&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.target, target) || other.target == target)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.baseValue, baseValue) || other.baseValue == baseValue)&&(identical(other.orderIdx, orderIdx) || other.orderIdx == orderIdx));
}


@override
int get hashCode => Object.hash(runtimeType,id,sourceId,target,depth,baseValue,orderIdx);

@override
String toString() {
  return 'ModulationLinkDto(id: $id, sourceId: $sourceId, target: $target, depth: $depth, baseValue: $baseValue, orderIdx: $orderIdx)';
}


}

/// @nodoc
abstract mixin class $ModulationLinkDtoCopyWith<$Res>  {
  factory $ModulationLinkDtoCopyWith(ModulationLinkDto value, $Res Function(ModulationLinkDto) _then) = _$ModulationLinkDtoCopyWithImpl;
@useResult
$Res call({
 int id, int sourceId, AutomationTargetDto target, double depth, double baseValue, int orderIdx
});


$AutomationTargetDtoCopyWith<$Res> get target;

}
/// @nodoc
class _$ModulationLinkDtoCopyWithImpl<$Res>
    implements $ModulationLinkDtoCopyWith<$Res> {
  _$ModulationLinkDtoCopyWithImpl(this._self, this._then);

  final ModulationLinkDto _self;
  final $Res Function(ModulationLinkDto) _then;

/// Create a copy of ModulationLinkDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceId = null,Object? target = null,Object? depth = null,Object? baseValue = null,Object? orderIdx = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as AutomationTargetDto,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as double,baseValue: null == baseValue ? _self.baseValue : baseValue // ignore: cast_nullable_to_non_nullable
as double,orderIdx: null == orderIdx ? _self.orderIdx : orderIdx // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ModulationLinkDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AutomationTargetDtoCopyWith<$Res> get target {
  
  return $AutomationTargetDtoCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// Adds pattern-matching-related methods to [ModulationLinkDto].
extension ModulationLinkDtoPatterns on ModulationLinkDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModulationLinkDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModulationLinkDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModulationLinkDto value)  $default,){
final _that = this;
switch (_that) {
case _ModulationLinkDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModulationLinkDto value)?  $default,){
final _that = this;
switch (_that) {
case _ModulationLinkDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int sourceId,  AutomationTargetDto target,  double depth,  double baseValue,  int orderIdx)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModulationLinkDto() when $default != null:
return $default(_that.id,_that.sourceId,_that.target,_that.depth,_that.baseValue,_that.orderIdx);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int sourceId,  AutomationTargetDto target,  double depth,  double baseValue,  int orderIdx)  $default,) {final _that = this;
switch (_that) {
case _ModulationLinkDto():
return $default(_that.id,_that.sourceId,_that.target,_that.depth,_that.baseValue,_that.orderIdx);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int sourceId,  AutomationTargetDto target,  double depth,  double baseValue,  int orderIdx)?  $default,) {final _that = this;
switch (_that) {
case _ModulationLinkDto() when $default != null:
return $default(_that.id,_that.sourceId,_that.target,_that.depth,_that.baseValue,_that.orderIdx);case _:
  return null;

}
}

}

/// @nodoc


class _ModulationLinkDto implements ModulationLinkDto {
  const _ModulationLinkDto({required this.id, required this.sourceId, required this.target, required this.depth, required this.baseValue, required this.orderIdx});
  

@override final  int id;
@override final  int sourceId;
@override final  AutomationTargetDto target;
@override final  double depth;
@override final  double baseValue;
@override final  int orderIdx;

/// Create a copy of ModulationLinkDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModulationLinkDtoCopyWith<_ModulationLinkDto> get copyWith => __$ModulationLinkDtoCopyWithImpl<_ModulationLinkDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModulationLinkDto&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.target, target) || other.target == target)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.baseValue, baseValue) || other.baseValue == baseValue)&&(identical(other.orderIdx, orderIdx) || other.orderIdx == orderIdx));
}


@override
int get hashCode => Object.hash(runtimeType,id,sourceId,target,depth,baseValue,orderIdx);

@override
String toString() {
  return 'ModulationLinkDto(id: $id, sourceId: $sourceId, target: $target, depth: $depth, baseValue: $baseValue, orderIdx: $orderIdx)';
}


}

/// @nodoc
abstract mixin class _$ModulationLinkDtoCopyWith<$Res> implements $ModulationLinkDtoCopyWith<$Res> {
  factory _$ModulationLinkDtoCopyWith(_ModulationLinkDto value, $Res Function(_ModulationLinkDto) _then) = __$ModulationLinkDtoCopyWithImpl;
@override @useResult
$Res call({
 int id, int sourceId, AutomationTargetDto target, double depth, double baseValue, int orderIdx
});


@override $AutomationTargetDtoCopyWith<$Res> get target;

}
/// @nodoc
class __$ModulationLinkDtoCopyWithImpl<$Res>
    implements _$ModulationLinkDtoCopyWith<$Res> {
  __$ModulationLinkDtoCopyWithImpl(this._self, this._then);

  final _ModulationLinkDto _self;
  final $Res Function(_ModulationLinkDto) _then;

/// Create a copy of ModulationLinkDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceId = null,Object? target = null,Object? depth = null,Object? baseValue = null,Object? orderIdx = null,}) {
  return _then(_ModulationLinkDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as AutomationTargetDto,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as double,baseValue: null == baseValue ? _self.baseValue : baseValue // ignore: cast_nullable_to_non_nullable
as double,orderIdx: null == orderIdx ? _self.orderIdx : orderIdx // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ModulationLinkDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AutomationTargetDtoCopyWith<$Res> get target {
  
  return $AutomationTargetDtoCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

/// @nodoc
mixin _$ModulationSourceDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModulationSourceDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ModulationSourceDto()';
}


}

/// @nodoc
class $ModulationSourceDtoCopyWith<$Res>  {
$ModulationSourceDtoCopyWith(ModulationSourceDto _, $Res Function(ModulationSourceDto) __);
}


/// Adds pattern-matching-related methods to [ModulationSourceDto].
extension ModulationSourceDtoPatterns on ModulationSourceDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ModulationSourceDto_PeakController value)?  peakController,TResult Function( ModulationSourceDto_Automation value)?  automation,TResult Function( ModulationSourceDto_Lfo value)?  lfo,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ModulationSourceDto_PeakController() when peakController != null:
return peakController(_that);case ModulationSourceDto_Automation() when automation != null:
return automation(_that);case ModulationSourceDto_Lfo() when lfo != null:
return lfo(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ModulationSourceDto_PeakController value)  peakController,required TResult Function( ModulationSourceDto_Automation value)  automation,required TResult Function( ModulationSourceDto_Lfo value)  lfo,}){
final _that = this;
switch (_that) {
case ModulationSourceDto_PeakController():
return peakController(_that);case ModulationSourceDto_Automation():
return automation(_that);case ModulationSourceDto_Lfo():
return lfo(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ModulationSourceDto_PeakController value)?  peakController,TResult? Function( ModulationSourceDto_Automation value)?  automation,TResult? Function( ModulationSourceDto_Lfo value)?  lfo,}){
final _that = this;
switch (_that) {
case ModulationSourceDto_PeakController() when peakController != null:
return peakController(_that);case ModulationSourceDto_Automation() when automation != null:
return automation(_that);case ModulationSourceDto_Lfo() when lfo != null:
return lfo(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( UiPluginTarget source)?  peakController,TResult Function( int laneId)?  automation,TResult Function( double rateHz)?  lfo,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ModulationSourceDto_PeakController() when peakController != null:
return peakController(_that.source);case ModulationSourceDto_Automation() when automation != null:
return automation(_that.laneId);case ModulationSourceDto_Lfo() when lfo != null:
return lfo(_that.rateHz);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( UiPluginTarget source)  peakController,required TResult Function( int laneId)  automation,required TResult Function( double rateHz)  lfo,}) {final _that = this;
switch (_that) {
case ModulationSourceDto_PeakController():
return peakController(_that.source);case ModulationSourceDto_Automation():
return automation(_that.laneId);case ModulationSourceDto_Lfo():
return lfo(_that.rateHz);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( UiPluginTarget source)?  peakController,TResult? Function( int laneId)?  automation,TResult? Function( double rateHz)?  lfo,}) {final _that = this;
switch (_that) {
case ModulationSourceDto_PeakController() when peakController != null:
return peakController(_that.source);case ModulationSourceDto_Automation() when automation != null:
return automation(_that.laneId);case ModulationSourceDto_Lfo() when lfo != null:
return lfo(_that.rateHz);case _:
  return null;

}
}

}

/// @nodoc


class ModulationSourceDto_PeakController extends ModulationSourceDto {
  const ModulationSourceDto_PeakController({required this.source}): super._();
  

 final  UiPluginTarget source;

/// Create a copy of ModulationSourceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModulationSourceDto_PeakControllerCopyWith<ModulationSourceDto_PeakController> get copyWith => _$ModulationSourceDto_PeakControllerCopyWithImpl<ModulationSourceDto_PeakController>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModulationSourceDto_PeakController&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'ModulationSourceDto.peakController(source: $source)';
}


}

/// @nodoc
abstract mixin class $ModulationSourceDto_PeakControllerCopyWith<$Res> implements $ModulationSourceDtoCopyWith<$Res> {
  factory $ModulationSourceDto_PeakControllerCopyWith(ModulationSourceDto_PeakController value, $Res Function(ModulationSourceDto_PeakController) _then) = _$ModulationSourceDto_PeakControllerCopyWithImpl;
@useResult
$Res call({
 UiPluginTarget source
});


$UiPluginTargetCopyWith<$Res> get source;

}
/// @nodoc
class _$ModulationSourceDto_PeakControllerCopyWithImpl<$Res>
    implements $ModulationSourceDto_PeakControllerCopyWith<$Res> {
  _$ModulationSourceDto_PeakControllerCopyWithImpl(this._self, this._then);

  final ModulationSourceDto_PeakController _self;
  final $Res Function(ModulationSourceDto_PeakController) _then;

/// Create a copy of ModulationSourceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(ModulationSourceDto_PeakController(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as UiPluginTarget,
  ));
}

/// Create a copy of ModulationSourceDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiPluginTargetCopyWith<$Res> get source {
  
  return $UiPluginTargetCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}

/// @nodoc


class ModulationSourceDto_Automation extends ModulationSourceDto {
  const ModulationSourceDto_Automation({required this.laneId}): super._();
  

 final  int laneId;

/// Create a copy of ModulationSourceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModulationSourceDto_AutomationCopyWith<ModulationSourceDto_Automation> get copyWith => _$ModulationSourceDto_AutomationCopyWithImpl<ModulationSourceDto_Automation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModulationSourceDto_Automation&&(identical(other.laneId, laneId) || other.laneId == laneId));
}


@override
int get hashCode => Object.hash(runtimeType,laneId);

@override
String toString() {
  return 'ModulationSourceDto.automation(laneId: $laneId)';
}


}

/// @nodoc
abstract mixin class $ModulationSourceDto_AutomationCopyWith<$Res> implements $ModulationSourceDtoCopyWith<$Res> {
  factory $ModulationSourceDto_AutomationCopyWith(ModulationSourceDto_Automation value, $Res Function(ModulationSourceDto_Automation) _then) = _$ModulationSourceDto_AutomationCopyWithImpl;
@useResult
$Res call({
 int laneId
});




}
/// @nodoc
class _$ModulationSourceDto_AutomationCopyWithImpl<$Res>
    implements $ModulationSourceDto_AutomationCopyWith<$Res> {
  _$ModulationSourceDto_AutomationCopyWithImpl(this._self, this._then);

  final ModulationSourceDto_Automation _self;
  final $Res Function(ModulationSourceDto_Automation) _then;

/// Create a copy of ModulationSourceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? laneId = null,}) {
  return _then(ModulationSourceDto_Automation(
laneId: null == laneId ? _self.laneId : laneId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ModulationSourceDto_Lfo extends ModulationSourceDto {
  const ModulationSourceDto_Lfo({required this.rateHz}): super._();
  

 final  double rateHz;

/// Create a copy of ModulationSourceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModulationSourceDto_LfoCopyWith<ModulationSourceDto_Lfo> get copyWith => _$ModulationSourceDto_LfoCopyWithImpl<ModulationSourceDto_Lfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModulationSourceDto_Lfo&&(identical(other.rateHz, rateHz) || other.rateHz == rateHz));
}


@override
int get hashCode => Object.hash(runtimeType,rateHz);

@override
String toString() {
  return 'ModulationSourceDto.lfo(rateHz: $rateHz)';
}


}

/// @nodoc
abstract mixin class $ModulationSourceDto_LfoCopyWith<$Res> implements $ModulationSourceDtoCopyWith<$Res> {
  factory $ModulationSourceDto_LfoCopyWith(ModulationSourceDto_Lfo value, $Res Function(ModulationSourceDto_Lfo) _then) = _$ModulationSourceDto_LfoCopyWithImpl;
@useResult
$Res call({
 double rateHz
});




}
/// @nodoc
class _$ModulationSourceDto_LfoCopyWithImpl<$Res>
    implements $ModulationSourceDto_LfoCopyWith<$Res> {
  _$ModulationSourceDto_LfoCopyWithImpl(this._self, this._then);

  final ModulationSourceDto_Lfo _self;
  final $Res Function(ModulationSourceDto_Lfo) _then;

/// Create a copy of ModulationSourceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? rateHz = null,}) {
  return _then(ModulationSourceDto_Lfo(
rateHz: null == rateHz ? _self.rateHz : rateHz // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$TrackAutomationTargetDto {

 MixerChannelParamTargetDto get field0;
/// Create a copy of TrackAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackAutomationTargetDtoCopyWith<TrackAutomationTargetDto> get copyWith => _$TrackAutomationTargetDtoCopyWithImpl<TrackAutomationTargetDto>(this as TrackAutomationTargetDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackAutomationTargetDto&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'TrackAutomationTargetDto(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TrackAutomationTargetDtoCopyWith<$Res>  {
  factory $TrackAutomationTargetDtoCopyWith(TrackAutomationTargetDto value, $Res Function(TrackAutomationTargetDto) _then) = _$TrackAutomationTargetDtoCopyWithImpl;
@useResult
$Res call({
 MixerChannelParamTargetDto field0
});


$MixerChannelParamTargetDtoCopyWith<$Res> get field0;

}
/// @nodoc
class _$TrackAutomationTargetDtoCopyWithImpl<$Res>
    implements $TrackAutomationTargetDtoCopyWith<$Res> {
  _$TrackAutomationTargetDtoCopyWithImpl(this._self, this._then);

  final TrackAutomationTargetDto _self;
  final $Res Function(TrackAutomationTargetDto) _then;

/// Create a copy of TrackAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? field0 = null,}) {
  return _then(_self.copyWith(
field0: null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as MixerChannelParamTargetDto,
  ));
}
/// Create a copy of TrackAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MixerChannelParamTargetDtoCopyWith<$Res> get field0 {
  
  return $MixerChannelParamTargetDtoCopyWith<$Res>(_self.field0, (value) {
    return _then(_self.copyWith(field0: value));
  });
}
}


/// Adds pattern-matching-related methods to [TrackAutomationTargetDto].
extension TrackAutomationTargetDtoPatterns on TrackAutomationTargetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TrackAutomationTargetDto_MixerChannel value)?  mixerChannel,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TrackAutomationTargetDto_MixerChannel() when mixerChannel != null:
return mixerChannel(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TrackAutomationTargetDto_MixerChannel value)  mixerChannel,}){
final _that = this;
switch (_that) {
case TrackAutomationTargetDto_MixerChannel():
return mixerChannel(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TrackAutomationTargetDto_MixerChannel value)?  mixerChannel,}){
final _that = this;
switch (_that) {
case TrackAutomationTargetDto_MixerChannel() when mixerChannel != null:
return mixerChannel(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( MixerChannelParamTargetDto field0)?  mixerChannel,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TrackAutomationTargetDto_MixerChannel() when mixerChannel != null:
return mixerChannel(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( MixerChannelParamTargetDto field0)  mixerChannel,}) {final _that = this;
switch (_that) {
case TrackAutomationTargetDto_MixerChannel():
return mixerChannel(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( MixerChannelParamTargetDto field0)?  mixerChannel,}) {final _that = this;
switch (_that) {
case TrackAutomationTargetDto_MixerChannel() when mixerChannel != null:
return mixerChannel(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class TrackAutomationTargetDto_MixerChannel extends TrackAutomationTargetDto {
  const TrackAutomationTargetDto_MixerChannel(this.field0): super._();
  

@override final  MixerChannelParamTargetDto field0;

/// Create a copy of TrackAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackAutomationTargetDto_MixerChannelCopyWith<TrackAutomationTargetDto_MixerChannel> get copyWith => _$TrackAutomationTargetDto_MixerChannelCopyWithImpl<TrackAutomationTargetDto_MixerChannel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackAutomationTargetDto_MixerChannel&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'TrackAutomationTargetDto.mixerChannel(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TrackAutomationTargetDto_MixerChannelCopyWith<$Res> implements $TrackAutomationTargetDtoCopyWith<$Res> {
  factory $TrackAutomationTargetDto_MixerChannelCopyWith(TrackAutomationTargetDto_MixerChannel value, $Res Function(TrackAutomationTargetDto_MixerChannel) _then) = _$TrackAutomationTargetDto_MixerChannelCopyWithImpl;
@override @useResult
$Res call({
 MixerChannelParamTargetDto field0
});


@override $MixerChannelParamTargetDtoCopyWith<$Res> get field0;

}
/// @nodoc
class _$TrackAutomationTargetDto_MixerChannelCopyWithImpl<$Res>
    implements $TrackAutomationTargetDto_MixerChannelCopyWith<$Res> {
  _$TrackAutomationTargetDto_MixerChannelCopyWithImpl(this._self, this._then);

  final TrackAutomationTargetDto_MixerChannel _self;
  final $Res Function(TrackAutomationTargetDto_MixerChannel) _then;

/// Create a copy of TrackAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TrackAutomationTargetDto_MixerChannel(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as MixerChannelParamTargetDto,
  ));
}

/// Create a copy of TrackAutomationTargetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MixerChannelParamTargetDtoCopyWith<$Res> get field0 {
  
  return $MixerChannelParamTargetDtoCopyWith<$Res>(_self.field0, (value) {
    return _then(_self.copyWith(field0: value));
  });
}
}

// dart format on
