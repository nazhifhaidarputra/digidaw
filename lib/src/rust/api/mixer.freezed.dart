// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mixer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ParameterSpecDTO {

 int get id; String get name; String get group; double get value; double get min; double get max; double get defaultValue; double get step; ParameterValueTypeDTO get valueType; List<String> get choices;
/// Create a copy of ParameterSpecDTO
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParameterSpecDTOCopyWith<ParameterSpecDTO> get copyWith => _$ParameterSpecDTOCopyWithImpl<ParameterSpecDTO>(this as ParameterSpecDTO, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParameterSpecDTO&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.group, group) || other.group == group)&&(identical(other.value, value) || other.value == value)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.step, step) || other.step == step)&&(identical(other.valueType, valueType) || other.valueType == valueType)&&const DeepCollectionEquality().equals(other.choices, choices));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,group,value,min,max,defaultValue,step,valueType,const DeepCollectionEquality().hash(choices));

@override
String toString() {
  return 'ParameterSpecDTO(id: $id, name: $name, group: $group, value: $value, min: $min, max: $max, defaultValue: $defaultValue, step: $step, valueType: $valueType, choices: $choices)';
}


}

/// @nodoc
abstract mixin class $ParameterSpecDTOCopyWith<$Res>  {
  factory $ParameterSpecDTOCopyWith(ParameterSpecDTO value, $Res Function(ParameterSpecDTO) _then) = _$ParameterSpecDTOCopyWithImpl;
@useResult
$Res call({
 int id, String name, String group, double value, double min, double max, double defaultValue, double step, ParameterValueTypeDTO valueType, List<String> choices
});




}
/// @nodoc
class _$ParameterSpecDTOCopyWithImpl<$Res>
    implements $ParameterSpecDTOCopyWith<$Res> {
  _$ParameterSpecDTOCopyWithImpl(this._self, this._then);

  final ParameterSpecDTO _self;
  final $Res Function(ParameterSpecDTO) _then;

/// Create a copy of ParameterSpecDTO
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? group = null,Object? value = null,Object? min = null,Object? max = null,Object? defaultValue = null,Object? step = null,Object? valueType = null,Object? choices = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as double,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as double,valueType: null == valueType ? _self.valueType : valueType // ignore: cast_nullable_to_non_nullable
as ParameterValueTypeDTO,choices: null == choices ? _self.choices : choices // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ParameterSpecDTO].
extension ParameterSpecDTOPatterns on ParameterSpecDTO {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ParameterSpecDTO value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ParameterSpecDTO() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ParameterSpecDTO value)  $default,){
final _that = this;
switch (_that) {
case _ParameterSpecDTO():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ParameterSpecDTO value)?  $default,){
final _that = this;
switch (_that) {
case _ParameterSpecDTO() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String group,  double value,  double min,  double max,  double defaultValue,  double step,  ParameterValueTypeDTO valueType,  List<String> choices)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ParameterSpecDTO() when $default != null:
return $default(_that.id,_that.name,_that.group,_that.value,_that.min,_that.max,_that.defaultValue,_that.step,_that.valueType,_that.choices);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String group,  double value,  double min,  double max,  double defaultValue,  double step,  ParameterValueTypeDTO valueType,  List<String> choices)  $default,) {final _that = this;
switch (_that) {
case _ParameterSpecDTO():
return $default(_that.id,_that.name,_that.group,_that.value,_that.min,_that.max,_that.defaultValue,_that.step,_that.valueType,_that.choices);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String group,  double value,  double min,  double max,  double defaultValue,  double step,  ParameterValueTypeDTO valueType,  List<String> choices)?  $default,) {final _that = this;
switch (_that) {
case _ParameterSpecDTO() when $default != null:
return $default(_that.id,_that.name,_that.group,_that.value,_that.min,_that.max,_that.defaultValue,_that.step,_that.valueType,_that.choices);case _:
  return null;

}
}

}

/// @nodoc


class _ParameterSpecDTO implements ParameterSpecDTO {
  const _ParameterSpecDTO({required this.id, required this.name, required this.group, required this.value, required this.min, required this.max, required this.defaultValue, required this.step, required this.valueType, required final  List<String> choices}): _choices = choices;
  

@override final  int id;
@override final  String name;
@override final  String group;
@override final  double value;
@override final  double min;
@override final  double max;
@override final  double defaultValue;
@override final  double step;
@override final  ParameterValueTypeDTO valueType;
 final  List<String> _choices;
@override List<String> get choices {
  if (_choices is EqualUnmodifiableListView) return _choices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_choices);
}


/// Create a copy of ParameterSpecDTO
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParameterSpecDTOCopyWith<_ParameterSpecDTO> get copyWith => __$ParameterSpecDTOCopyWithImpl<_ParameterSpecDTO>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ParameterSpecDTO&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.group, group) || other.group == group)&&(identical(other.value, value) || other.value == value)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.step, step) || other.step == step)&&(identical(other.valueType, valueType) || other.valueType == valueType)&&const DeepCollectionEquality().equals(other._choices, _choices));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,group,value,min,max,defaultValue,step,valueType,const DeepCollectionEquality().hash(_choices));

@override
String toString() {
  return 'ParameterSpecDTO(id: $id, name: $name, group: $group, value: $value, min: $min, max: $max, defaultValue: $defaultValue, step: $step, valueType: $valueType, choices: $choices)';
}


}

/// @nodoc
abstract mixin class _$ParameterSpecDTOCopyWith<$Res> implements $ParameterSpecDTOCopyWith<$Res> {
  factory _$ParameterSpecDTOCopyWith(_ParameterSpecDTO value, $Res Function(_ParameterSpecDTO) _then) = __$ParameterSpecDTOCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String group, double value, double min, double max, double defaultValue, double step, ParameterValueTypeDTO valueType, List<String> choices
});




}
/// @nodoc
class __$ParameterSpecDTOCopyWithImpl<$Res>
    implements _$ParameterSpecDTOCopyWith<$Res> {
  __$ParameterSpecDTOCopyWithImpl(this._self, this._then);

  final _ParameterSpecDTO _self;
  final $Res Function(_ParameterSpecDTO) _then;

/// Create a copy of ParameterSpecDTO
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? group = null,Object? value = null,Object? min = null,Object? max = null,Object? defaultValue = null,Object? step = null,Object? valueType = null,Object? choices = null,}) {
  return _then(_ParameterSpecDTO(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as double,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as double,valueType: null == valueType ? _self.valueType : valueType // ignore: cast_nullable_to_non_nullable
as ParameterValueTypeDTO,choices: null == choices ? _self._choices : choices // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$UiBus {

 int get id; String get name; UiMixerChannel get channel;
/// Create a copy of UiBus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiBusCopyWith<UiBus> get copyWith => _$UiBusCopyWithImpl<UiBus>(this as UiBus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiBus&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.channel, channel) || other.channel == channel));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,channel);

@override
String toString() {
  return 'UiBus(id: $id, name: $name, channel: $channel)';
}


}

/// @nodoc
abstract mixin class $UiBusCopyWith<$Res>  {
  factory $UiBusCopyWith(UiBus value, $Res Function(UiBus) _then) = _$UiBusCopyWithImpl;
@useResult
$Res call({
 int id, String name, UiMixerChannel channel
});




}
/// @nodoc
class _$UiBusCopyWithImpl<$Res>
    implements $UiBusCopyWith<$Res> {
  _$UiBusCopyWithImpl(this._self, this._then);

  final UiBus _self;
  final $Res Function(UiBus) _then;

/// Create a copy of UiBus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? channel = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as UiMixerChannel,
  ));
}

}


/// Adds pattern-matching-related methods to [UiBus].
extension UiBusPatterns on UiBus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiBus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiBus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiBus value)  $default,){
final _that = this;
switch (_that) {
case _UiBus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiBus value)?  $default,){
final _that = this;
switch (_that) {
case _UiBus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  UiMixerChannel channel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiBus() when $default != null:
return $default(_that.id,_that.name,_that.channel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  UiMixerChannel channel)  $default,) {final _that = this;
switch (_that) {
case _UiBus():
return $default(_that.id,_that.name,_that.channel);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  UiMixerChannel channel)?  $default,) {final _that = this;
switch (_that) {
case _UiBus() when $default != null:
return $default(_that.id,_that.name,_that.channel);case _:
  return null;

}
}

}

/// @nodoc


class _UiBus implements UiBus {
  const _UiBus({required this.id, required this.name, required this.channel});
  

@override final  int id;
@override final  String name;
@override final  UiMixerChannel channel;

/// Create a copy of UiBus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiBusCopyWith<_UiBus> get copyWith => __$UiBusCopyWithImpl<_UiBus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiBus&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.channel, channel) || other.channel == channel));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,channel);

@override
String toString() {
  return 'UiBus(id: $id, name: $name, channel: $channel)';
}


}

/// @nodoc
abstract mixin class _$UiBusCopyWith<$Res> implements $UiBusCopyWith<$Res> {
  factory _$UiBusCopyWith(_UiBus value, $Res Function(_UiBus) _then) = __$UiBusCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, UiMixerChannel channel
});




}
/// @nodoc
class __$UiBusCopyWithImpl<$Res>
    implements _$UiBusCopyWith<$Res> {
  __$UiBusCopyWithImpl(this._self, this._then);

  final _UiBus _self;
  final $Res Function(_UiBus) _then;

/// Create a copy of UiBus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? channel = null,}) {
  return _then(_UiBus(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as UiMixerChannel,
  ));
}


}

/// @nodoc
mixin _$UiEffectInstance {

 int get id; String get name;
/// Create a copy of UiEffectInstance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEffectInstanceCopyWith<UiEffectInstance> get copyWith => _$UiEffectInstanceCopyWithImpl<UiEffectInstance>(this as UiEffectInstance, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEffectInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'UiEffectInstance(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $UiEffectInstanceCopyWith<$Res>  {
  factory $UiEffectInstanceCopyWith(UiEffectInstance value, $Res Function(UiEffectInstance) _then) = _$UiEffectInstanceCopyWithImpl;
@useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class _$UiEffectInstanceCopyWithImpl<$Res>
    implements $UiEffectInstanceCopyWith<$Res> {
  _$UiEffectInstanceCopyWithImpl(this._self, this._then);

  final UiEffectInstance _self;
  final $Res Function(UiEffectInstance) _then;

/// Create a copy of UiEffectInstance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiEffectInstance].
extension UiEffectInstancePatterns on UiEffectInstance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiEffectInstance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiEffectInstance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiEffectInstance value)  $default,){
final _that = this;
switch (_that) {
case _UiEffectInstance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiEffectInstance value)?  $default,){
final _that = this;
switch (_that) {
case _UiEffectInstance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiEffectInstance() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name)  $default,) {final _that = this;
switch (_that) {
case _UiEffectInstance():
return $default(_that.id,_that.name);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _UiEffectInstance() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _UiEffectInstance implements UiEffectInstance {
  const _UiEffectInstance({required this.id, required this.name});
  

@override final  int id;
@override final  String name;

/// Create a copy of UiEffectInstance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiEffectInstanceCopyWith<_UiEffectInstance> get copyWith => __$UiEffectInstanceCopyWithImpl<_UiEffectInstance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiEffectInstance&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'UiEffectInstance(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$UiEffectInstanceCopyWith<$Res> implements $UiEffectInstanceCopyWith<$Res> {
  factory _$UiEffectInstanceCopyWith(_UiEffectInstance value, $Res Function(_UiEffectInstance) _then) = __$UiEffectInstanceCopyWithImpl;
@override @useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class __$UiEffectInstanceCopyWithImpl<$Res>
    implements _$UiEffectInstanceCopyWith<$Res> {
  __$UiEffectInstanceCopyWithImpl(this._self, this._then);

  final _UiEffectInstance _self;
  final $Res Function(_UiEffectInstance) _then;

/// Create a copy of UiEffectInstance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_UiEffectInstance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiMixerChannelParams {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelParams&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'UiMixerChannelParams(field0: $field0)';
}


}

/// @nodoc
class $UiMixerChannelParamsCopyWith<$Res>  {
$UiMixerChannelParamsCopyWith(UiMixerChannelParams _, $Res Function(UiMixerChannelParams) __);
}


/// Adds pattern-matching-related methods to [UiMixerChannelParams].
extension UiMixerChannelParamsPatterns on UiMixerChannelParams {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiMixerChannelParams_Volume value)?  volume,TResult Function( UiMixerChannelParams_Pan value)?  pan,TResult Function( UiMixerChannelParams_Mute value)?  mute,TResult Function( UiMixerChannelParams_InvertedPhase value)?  invertedPhase,TResult Function( UiMixerChannelParams_Solo value)?  solo,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiMixerChannelParams_Volume() when volume != null:
return volume(_that);case UiMixerChannelParams_Pan() when pan != null:
return pan(_that);case UiMixerChannelParams_Mute() when mute != null:
return mute(_that);case UiMixerChannelParams_InvertedPhase() when invertedPhase != null:
return invertedPhase(_that);case UiMixerChannelParams_Solo() when solo != null:
return solo(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiMixerChannelParams_Volume value)  volume,required TResult Function( UiMixerChannelParams_Pan value)  pan,required TResult Function( UiMixerChannelParams_Mute value)  mute,required TResult Function( UiMixerChannelParams_InvertedPhase value)  invertedPhase,required TResult Function( UiMixerChannelParams_Solo value)  solo,}){
final _that = this;
switch (_that) {
case UiMixerChannelParams_Volume():
return volume(_that);case UiMixerChannelParams_Pan():
return pan(_that);case UiMixerChannelParams_Mute():
return mute(_that);case UiMixerChannelParams_InvertedPhase():
return invertedPhase(_that);case UiMixerChannelParams_Solo():
return solo(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiMixerChannelParams_Volume value)?  volume,TResult? Function( UiMixerChannelParams_Pan value)?  pan,TResult? Function( UiMixerChannelParams_Mute value)?  mute,TResult? Function( UiMixerChannelParams_InvertedPhase value)?  invertedPhase,TResult? Function( UiMixerChannelParams_Solo value)?  solo,}){
final _that = this;
switch (_that) {
case UiMixerChannelParams_Volume() when volume != null:
return volume(_that);case UiMixerChannelParams_Pan() when pan != null:
return pan(_that);case UiMixerChannelParams_Mute() when mute != null:
return mute(_that);case UiMixerChannelParams_InvertedPhase() when invertedPhase != null:
return invertedPhase(_that);case UiMixerChannelParams_Solo() when solo != null:
return solo(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( double field0)?  volume,TResult Function( double field0)?  pan,TResult Function( bool field0)?  mute,TResult Function( bool field0)?  invertedPhase,TResult Function( bool field0)?  solo,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiMixerChannelParams_Volume() when volume != null:
return volume(_that.field0);case UiMixerChannelParams_Pan() when pan != null:
return pan(_that.field0);case UiMixerChannelParams_Mute() when mute != null:
return mute(_that.field0);case UiMixerChannelParams_InvertedPhase() when invertedPhase != null:
return invertedPhase(_that.field0);case UiMixerChannelParams_Solo() when solo != null:
return solo(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( double field0)  volume,required TResult Function( double field0)  pan,required TResult Function( bool field0)  mute,required TResult Function( bool field0)  invertedPhase,required TResult Function( bool field0)  solo,}) {final _that = this;
switch (_that) {
case UiMixerChannelParams_Volume():
return volume(_that.field0);case UiMixerChannelParams_Pan():
return pan(_that.field0);case UiMixerChannelParams_Mute():
return mute(_that.field0);case UiMixerChannelParams_InvertedPhase():
return invertedPhase(_that.field0);case UiMixerChannelParams_Solo():
return solo(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( double field0)?  volume,TResult? Function( double field0)?  pan,TResult? Function( bool field0)?  mute,TResult? Function( bool field0)?  invertedPhase,TResult? Function( bool field0)?  solo,}) {final _that = this;
switch (_that) {
case UiMixerChannelParams_Volume() when volume != null:
return volume(_that.field0);case UiMixerChannelParams_Pan() when pan != null:
return pan(_that.field0);case UiMixerChannelParams_Mute() when mute != null:
return mute(_that.field0);case UiMixerChannelParams_InvertedPhase() when invertedPhase != null:
return invertedPhase(_that.field0);case UiMixerChannelParams_Solo() when solo != null:
return solo(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class UiMixerChannelParams_Volume extends UiMixerChannelParams {
  const UiMixerChannelParams_Volume(this.field0): super._();
  

@override final  double field0;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMixerChannelParams_VolumeCopyWith<UiMixerChannelParams_Volume> get copyWith => _$UiMixerChannelParams_VolumeCopyWithImpl<UiMixerChannelParams_Volume>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelParams_Volume&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiMixerChannelParams.volume(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiMixerChannelParams_VolumeCopyWith<$Res> implements $UiMixerChannelParamsCopyWith<$Res> {
  factory $UiMixerChannelParams_VolumeCopyWith(UiMixerChannelParams_Volume value, $Res Function(UiMixerChannelParams_Volume) _then) = _$UiMixerChannelParams_VolumeCopyWithImpl;
@useResult
$Res call({
 double field0
});




}
/// @nodoc
class _$UiMixerChannelParams_VolumeCopyWithImpl<$Res>
    implements $UiMixerChannelParams_VolumeCopyWith<$Res> {
  _$UiMixerChannelParams_VolumeCopyWithImpl(this._self, this._then);

  final UiMixerChannelParams_Volume _self;
  final $Res Function(UiMixerChannelParams_Volume) _then;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiMixerChannelParams_Volume(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class UiMixerChannelParams_Pan extends UiMixerChannelParams {
  const UiMixerChannelParams_Pan(this.field0): super._();
  

@override final  double field0;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMixerChannelParams_PanCopyWith<UiMixerChannelParams_Pan> get copyWith => _$UiMixerChannelParams_PanCopyWithImpl<UiMixerChannelParams_Pan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelParams_Pan&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiMixerChannelParams.pan(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiMixerChannelParams_PanCopyWith<$Res> implements $UiMixerChannelParamsCopyWith<$Res> {
  factory $UiMixerChannelParams_PanCopyWith(UiMixerChannelParams_Pan value, $Res Function(UiMixerChannelParams_Pan) _then) = _$UiMixerChannelParams_PanCopyWithImpl;
@useResult
$Res call({
 double field0
});




}
/// @nodoc
class _$UiMixerChannelParams_PanCopyWithImpl<$Res>
    implements $UiMixerChannelParams_PanCopyWith<$Res> {
  _$UiMixerChannelParams_PanCopyWithImpl(this._self, this._then);

  final UiMixerChannelParams_Pan _self;
  final $Res Function(UiMixerChannelParams_Pan) _then;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiMixerChannelParams_Pan(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class UiMixerChannelParams_Mute extends UiMixerChannelParams {
  const UiMixerChannelParams_Mute(this.field0): super._();
  

@override final  bool field0;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMixerChannelParams_MuteCopyWith<UiMixerChannelParams_Mute> get copyWith => _$UiMixerChannelParams_MuteCopyWithImpl<UiMixerChannelParams_Mute>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelParams_Mute&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiMixerChannelParams.mute(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiMixerChannelParams_MuteCopyWith<$Res> implements $UiMixerChannelParamsCopyWith<$Res> {
  factory $UiMixerChannelParams_MuteCopyWith(UiMixerChannelParams_Mute value, $Res Function(UiMixerChannelParams_Mute) _then) = _$UiMixerChannelParams_MuteCopyWithImpl;
@useResult
$Res call({
 bool field0
});




}
/// @nodoc
class _$UiMixerChannelParams_MuteCopyWithImpl<$Res>
    implements $UiMixerChannelParams_MuteCopyWith<$Res> {
  _$UiMixerChannelParams_MuteCopyWithImpl(this._self, this._then);

  final UiMixerChannelParams_Mute _self;
  final $Res Function(UiMixerChannelParams_Mute) _then;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiMixerChannelParams_Mute(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class UiMixerChannelParams_InvertedPhase extends UiMixerChannelParams {
  const UiMixerChannelParams_InvertedPhase(this.field0): super._();
  

@override final  bool field0;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMixerChannelParams_InvertedPhaseCopyWith<UiMixerChannelParams_InvertedPhase> get copyWith => _$UiMixerChannelParams_InvertedPhaseCopyWithImpl<UiMixerChannelParams_InvertedPhase>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelParams_InvertedPhase&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiMixerChannelParams.invertedPhase(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiMixerChannelParams_InvertedPhaseCopyWith<$Res> implements $UiMixerChannelParamsCopyWith<$Res> {
  factory $UiMixerChannelParams_InvertedPhaseCopyWith(UiMixerChannelParams_InvertedPhase value, $Res Function(UiMixerChannelParams_InvertedPhase) _then) = _$UiMixerChannelParams_InvertedPhaseCopyWithImpl;
@useResult
$Res call({
 bool field0
});




}
/// @nodoc
class _$UiMixerChannelParams_InvertedPhaseCopyWithImpl<$Res>
    implements $UiMixerChannelParams_InvertedPhaseCopyWith<$Res> {
  _$UiMixerChannelParams_InvertedPhaseCopyWithImpl(this._self, this._then);

  final UiMixerChannelParams_InvertedPhase _self;
  final $Res Function(UiMixerChannelParams_InvertedPhase) _then;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiMixerChannelParams_InvertedPhase(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class UiMixerChannelParams_Solo extends UiMixerChannelParams {
  const UiMixerChannelParams_Solo(this.field0): super._();
  

@override final  bool field0;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMixerChannelParams_SoloCopyWith<UiMixerChannelParams_Solo> get copyWith => _$UiMixerChannelParams_SoloCopyWithImpl<UiMixerChannelParams_Solo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelParams_Solo&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiMixerChannelParams.solo(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiMixerChannelParams_SoloCopyWith<$Res> implements $UiMixerChannelParamsCopyWith<$Res> {
  factory $UiMixerChannelParams_SoloCopyWith(UiMixerChannelParams_Solo value, $Res Function(UiMixerChannelParams_Solo) _then) = _$UiMixerChannelParams_SoloCopyWithImpl;
@useResult
$Res call({
 bool field0
});




}
/// @nodoc
class _$UiMixerChannelParams_SoloCopyWithImpl<$Res>
    implements $UiMixerChannelParams_SoloCopyWith<$Res> {
  _$UiMixerChannelParams_SoloCopyWithImpl(this._self, this._then);

  final UiMixerChannelParams_Solo _self;
  final $Res Function(UiMixerChannelParams_Solo) _then;

/// Create a copy of UiMixerChannelParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiMixerChannelParams_Solo(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$UiMixerChannelTarget {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelTarget);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiMixerChannelTarget()';
}


}

/// @nodoc
class $UiMixerChannelTargetCopyWith<$Res>  {
$UiMixerChannelTargetCopyWith(UiMixerChannelTarget _, $Res Function(UiMixerChannelTarget) __);
}


/// Adds pattern-matching-related methods to [UiMixerChannelTarget].
extension UiMixerChannelTargetPatterns on UiMixerChannelTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiMixerChannelTarget_Track value)?  track,TResult Function( UiMixerChannelTarget_Bus value)?  bus,TResult Function( UiMixerChannelTarget_Master value)?  master,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiMixerChannelTarget_Track() when track != null:
return track(_that);case UiMixerChannelTarget_Bus() when bus != null:
return bus(_that);case UiMixerChannelTarget_Master() when master != null:
return master(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiMixerChannelTarget_Track value)  track,required TResult Function( UiMixerChannelTarget_Bus value)  bus,required TResult Function( UiMixerChannelTarget_Master value)  master,}){
final _that = this;
switch (_that) {
case UiMixerChannelTarget_Track():
return track(_that);case UiMixerChannelTarget_Bus():
return bus(_that);case UiMixerChannelTarget_Master():
return master(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiMixerChannelTarget_Track value)?  track,TResult? Function( UiMixerChannelTarget_Bus value)?  bus,TResult? Function( UiMixerChannelTarget_Master value)?  master,}){
final _that = this;
switch (_that) {
case UiMixerChannelTarget_Track() when track != null:
return track(_that);case UiMixerChannelTarget_Bus() when bus != null:
return bus(_that);case UiMixerChannelTarget_Master() when master != null:
return master(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int field0)?  track,TResult Function( int field0)?  bus,TResult Function()?  master,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiMixerChannelTarget_Track() when track != null:
return track(_that.field0);case UiMixerChannelTarget_Bus() when bus != null:
return bus(_that.field0);case UiMixerChannelTarget_Master() when master != null:
return master();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int field0)  track,required TResult Function( int field0)  bus,required TResult Function()  master,}) {final _that = this;
switch (_that) {
case UiMixerChannelTarget_Track():
return track(_that.field0);case UiMixerChannelTarget_Bus():
return bus(_that.field0);case UiMixerChannelTarget_Master():
return master();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int field0)?  track,TResult? Function( int field0)?  bus,TResult? Function()?  master,}) {final _that = this;
switch (_that) {
case UiMixerChannelTarget_Track() when track != null:
return track(_that.field0);case UiMixerChannelTarget_Bus() when bus != null:
return bus(_that.field0);case UiMixerChannelTarget_Master() when master != null:
return master();case _:
  return null;

}
}

}

/// @nodoc


class UiMixerChannelTarget_Track extends UiMixerChannelTarget {
  const UiMixerChannelTarget_Track(this.field0): super._();
  

 final  int field0;

/// Create a copy of UiMixerChannelTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMixerChannelTarget_TrackCopyWith<UiMixerChannelTarget_Track> get copyWith => _$UiMixerChannelTarget_TrackCopyWithImpl<UiMixerChannelTarget_Track>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelTarget_Track&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiMixerChannelTarget.track(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiMixerChannelTarget_TrackCopyWith<$Res> implements $UiMixerChannelTargetCopyWith<$Res> {
  factory $UiMixerChannelTarget_TrackCopyWith(UiMixerChannelTarget_Track value, $Res Function(UiMixerChannelTarget_Track) _then) = _$UiMixerChannelTarget_TrackCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiMixerChannelTarget_TrackCopyWithImpl<$Res>
    implements $UiMixerChannelTarget_TrackCopyWith<$Res> {
  _$UiMixerChannelTarget_TrackCopyWithImpl(this._self, this._then);

  final UiMixerChannelTarget_Track _self;
  final $Res Function(UiMixerChannelTarget_Track) _then;

/// Create a copy of UiMixerChannelTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiMixerChannelTarget_Track(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiMixerChannelTarget_Bus extends UiMixerChannelTarget {
  const UiMixerChannelTarget_Bus(this.field0): super._();
  

 final  int field0;

/// Create a copy of UiMixerChannelTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMixerChannelTarget_BusCopyWith<UiMixerChannelTarget_Bus> get copyWith => _$UiMixerChannelTarget_BusCopyWithImpl<UiMixerChannelTarget_Bus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelTarget_Bus&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiMixerChannelTarget.bus(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiMixerChannelTarget_BusCopyWith<$Res> implements $UiMixerChannelTargetCopyWith<$Res> {
  factory $UiMixerChannelTarget_BusCopyWith(UiMixerChannelTarget_Bus value, $Res Function(UiMixerChannelTarget_Bus) _then) = _$UiMixerChannelTarget_BusCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiMixerChannelTarget_BusCopyWithImpl<$Res>
    implements $UiMixerChannelTarget_BusCopyWith<$Res> {
  _$UiMixerChannelTarget_BusCopyWithImpl(this._self, this._then);

  final UiMixerChannelTarget_Bus _self;
  final $Res Function(UiMixerChannelTarget_Bus) _then;

/// Create a copy of UiMixerChannelTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiMixerChannelTarget_Bus(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiMixerChannelTarget_Master extends UiMixerChannelTarget {
  const UiMixerChannelTarget_Master(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerChannelTarget_Master);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiMixerChannelTarget.master()';
}


}




/// @nodoc
mixin _$UiMixerState {

 Map<int, UiMixerChannel> get channels; UiMixerChannel get masterBus; Map<int, UiBus> get buses; List<UiRoutingConnection> get routing;
/// Create a copy of UiMixerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiMixerStateCopyWith<UiMixerState> get copyWith => _$UiMixerStateCopyWithImpl<UiMixerState>(this as UiMixerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiMixerState&&const DeepCollectionEquality().equals(other.channels, channels)&&(identical(other.masterBus, masterBus) || other.masterBus == masterBus)&&const DeepCollectionEquality().equals(other.buses, buses)&&const DeepCollectionEquality().equals(other.routing, routing));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(channels),masterBus,const DeepCollectionEquality().hash(buses),const DeepCollectionEquality().hash(routing));

@override
String toString() {
  return 'UiMixerState(channels: $channels, masterBus: $masterBus, buses: $buses, routing: $routing)';
}


}

/// @nodoc
abstract mixin class $UiMixerStateCopyWith<$Res>  {
  factory $UiMixerStateCopyWith(UiMixerState value, $Res Function(UiMixerState) _then) = _$UiMixerStateCopyWithImpl;
@useResult
$Res call({
 Map<int, UiMixerChannel> channels, UiMixerChannel masterBus, Map<int, UiBus> buses, List<UiRoutingConnection> routing
});




}
/// @nodoc
class _$UiMixerStateCopyWithImpl<$Res>
    implements $UiMixerStateCopyWith<$Res> {
  _$UiMixerStateCopyWithImpl(this._self, this._then);

  final UiMixerState _self;
  final $Res Function(UiMixerState) _then;

/// Create a copy of UiMixerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channels = null,Object? masterBus = null,Object? buses = null,Object? routing = null,}) {
  return _then(_self.copyWith(
channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as Map<int, UiMixerChannel>,masterBus: null == masterBus ? _self.masterBus : masterBus // ignore: cast_nullable_to_non_nullable
as UiMixerChannel,buses: null == buses ? _self.buses : buses // ignore: cast_nullable_to_non_nullable
as Map<int, UiBus>,routing: null == routing ? _self.routing : routing // ignore: cast_nullable_to_non_nullable
as List<UiRoutingConnection>,
  ));
}

}


/// Adds pattern-matching-related methods to [UiMixerState].
extension UiMixerStatePatterns on UiMixerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _UiMixerState value)?  raw,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiMixerState() when raw != null:
return raw(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _UiMixerState value)  raw,}){
final _that = this;
switch (_that) {
case _UiMixerState():
return raw(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _UiMixerState value)?  raw,}){
final _that = this;
switch (_that) {
case _UiMixerState() when raw != null:
return raw(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Map<int, UiMixerChannel> channels,  UiMixerChannel masterBus,  Map<int, UiBus> buses,  List<UiRoutingConnection> routing)?  raw,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiMixerState() when raw != null:
return raw(_that.channels,_that.masterBus,_that.buses,_that.routing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Map<int, UiMixerChannel> channels,  UiMixerChannel masterBus,  Map<int, UiBus> buses,  List<UiRoutingConnection> routing)  raw,}) {final _that = this;
switch (_that) {
case _UiMixerState():
return raw(_that.channels,_that.masterBus,_that.buses,_that.routing);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Map<int, UiMixerChannel> channels,  UiMixerChannel masterBus,  Map<int, UiBus> buses,  List<UiRoutingConnection> routing)?  raw,}) {final _that = this;
switch (_that) {
case _UiMixerState() when raw != null:
return raw(_that.channels,_that.masterBus,_that.buses,_that.routing);case _:
  return null;

}
}

}

/// @nodoc


class _UiMixerState extends UiMixerState {
  const _UiMixerState({required final  Map<int, UiMixerChannel> channels, required this.masterBus, required final  Map<int, UiBus> buses, required final  List<UiRoutingConnection> routing}): _channels = channels,_buses = buses,_routing = routing,super._();
  

 final  Map<int, UiMixerChannel> _channels;
@override Map<int, UiMixerChannel> get channels {
  if (_channels is EqualUnmodifiableMapView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_channels);
}

@override final  UiMixerChannel masterBus;
 final  Map<int, UiBus> _buses;
@override Map<int, UiBus> get buses {
  if (_buses is EqualUnmodifiableMapView) return _buses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_buses);
}

 final  List<UiRoutingConnection> _routing;
@override List<UiRoutingConnection> get routing {
  if (_routing is EqualUnmodifiableListView) return _routing;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_routing);
}


/// Create a copy of UiMixerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiMixerStateCopyWith<_UiMixerState> get copyWith => __$UiMixerStateCopyWithImpl<_UiMixerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiMixerState&&const DeepCollectionEquality().equals(other._channels, _channels)&&(identical(other.masterBus, masterBus) || other.masterBus == masterBus)&&const DeepCollectionEquality().equals(other._buses, _buses)&&const DeepCollectionEquality().equals(other._routing, _routing));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_channels),masterBus,const DeepCollectionEquality().hash(_buses),const DeepCollectionEquality().hash(_routing));

@override
String toString() {
  return 'UiMixerState.raw(channels: $channels, masterBus: $masterBus, buses: $buses, routing: $routing)';
}


}

/// @nodoc
abstract mixin class _$UiMixerStateCopyWith<$Res> implements $UiMixerStateCopyWith<$Res> {
  factory _$UiMixerStateCopyWith(_UiMixerState value, $Res Function(_UiMixerState) _then) = __$UiMixerStateCopyWithImpl;
@override @useResult
$Res call({
 Map<int, UiMixerChannel> channels, UiMixerChannel masterBus, Map<int, UiBus> buses, List<UiRoutingConnection> routing
});




}
/// @nodoc
class __$UiMixerStateCopyWithImpl<$Res>
    implements _$UiMixerStateCopyWith<$Res> {
  __$UiMixerStateCopyWithImpl(this._self, this._then);

  final _UiMixerState _self;
  final $Res Function(_UiMixerState) _then;

/// Create a copy of UiMixerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channels = null,Object? masterBus = null,Object? buses = null,Object? routing = null,}) {
  return _then(_UiMixerState(
channels: null == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as Map<int, UiMixerChannel>,masterBus: null == masterBus ? _self.masterBus : masterBus // ignore: cast_nullable_to_non_nullable
as UiMixerChannel,buses: null == buses ? _self._buses : buses // ignore: cast_nullable_to_non_nullable
as Map<int, UiBus>,routing: null == routing ? _self._routing : routing // ignore: cast_nullable_to_non_nullable
as List<UiRoutingConnection>,
  ));
}


}

/// @nodoc
mixin _$UiRoutingConnection {

 UiRoutingNode get source; UiRoutingNode get destination; double get sendLevel; bool get isSend;
/// Create a copy of UiRoutingConnection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiRoutingConnectionCopyWith<UiRoutingConnection> get copyWith => _$UiRoutingConnectionCopyWithImpl<UiRoutingConnection>(this as UiRoutingConnection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRoutingConnection&&(identical(other.source, source) || other.source == source)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.sendLevel, sendLevel) || other.sendLevel == sendLevel)&&(identical(other.isSend, isSend) || other.isSend == isSend));
}


@override
int get hashCode => Object.hash(runtimeType,source,destination,sendLevel,isSend);

@override
String toString() {
  return 'UiRoutingConnection(source: $source, destination: $destination, sendLevel: $sendLevel, isSend: $isSend)';
}


}

/// @nodoc
abstract mixin class $UiRoutingConnectionCopyWith<$Res>  {
  factory $UiRoutingConnectionCopyWith(UiRoutingConnection value, $Res Function(UiRoutingConnection) _then) = _$UiRoutingConnectionCopyWithImpl;
@useResult
$Res call({
 UiRoutingNode source, UiRoutingNode destination, double sendLevel, bool isSend
});


$UiRoutingNodeCopyWith<$Res> get source;$UiRoutingNodeCopyWith<$Res> get destination;

}
/// @nodoc
class _$UiRoutingConnectionCopyWithImpl<$Res>
    implements $UiRoutingConnectionCopyWith<$Res> {
  _$UiRoutingConnectionCopyWithImpl(this._self, this._then);

  final UiRoutingConnection _self;
  final $Res Function(UiRoutingConnection) _then;

/// Create a copy of UiRoutingConnection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? destination = null,Object? sendLevel = null,Object? isSend = null,}) {
  return _then(_self.copyWith(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as UiRoutingNode,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as UiRoutingNode,sendLevel: null == sendLevel ? _self.sendLevel : sendLevel // ignore: cast_nullable_to_non_nullable
as double,isSend: null == isSend ? _self.isSend : isSend // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of UiRoutingConnection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRoutingNodeCopyWith<$Res> get source {
  
  return $UiRoutingNodeCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}/// Create a copy of UiRoutingConnection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRoutingNodeCopyWith<$Res> get destination {
  
  return $UiRoutingNodeCopyWith<$Res>(_self.destination, (value) {
    return _then(_self.copyWith(destination: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiRoutingConnection].
extension UiRoutingConnectionPatterns on UiRoutingConnection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiRoutingConnection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiRoutingConnection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiRoutingConnection value)  $default,){
final _that = this;
switch (_that) {
case _UiRoutingConnection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiRoutingConnection value)?  $default,){
final _that = this;
switch (_that) {
case _UiRoutingConnection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UiRoutingNode source,  UiRoutingNode destination,  double sendLevel,  bool isSend)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiRoutingConnection() when $default != null:
return $default(_that.source,_that.destination,_that.sendLevel,_that.isSend);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UiRoutingNode source,  UiRoutingNode destination,  double sendLevel,  bool isSend)  $default,) {final _that = this;
switch (_that) {
case _UiRoutingConnection():
return $default(_that.source,_that.destination,_that.sendLevel,_that.isSend);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UiRoutingNode source,  UiRoutingNode destination,  double sendLevel,  bool isSend)?  $default,) {final _that = this;
switch (_that) {
case _UiRoutingConnection() when $default != null:
return $default(_that.source,_that.destination,_that.sendLevel,_that.isSend);case _:
  return null;

}
}

}

/// @nodoc


class _UiRoutingConnection implements UiRoutingConnection {
  const _UiRoutingConnection({required this.source, required this.destination, required this.sendLevel, required this.isSend});
  

@override final  UiRoutingNode source;
@override final  UiRoutingNode destination;
@override final  double sendLevel;
@override final  bool isSend;

/// Create a copy of UiRoutingConnection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiRoutingConnectionCopyWith<_UiRoutingConnection> get copyWith => __$UiRoutingConnectionCopyWithImpl<_UiRoutingConnection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiRoutingConnection&&(identical(other.source, source) || other.source == source)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.sendLevel, sendLevel) || other.sendLevel == sendLevel)&&(identical(other.isSend, isSend) || other.isSend == isSend));
}


@override
int get hashCode => Object.hash(runtimeType,source,destination,sendLevel,isSend);

@override
String toString() {
  return 'UiRoutingConnection(source: $source, destination: $destination, sendLevel: $sendLevel, isSend: $isSend)';
}


}

/// @nodoc
abstract mixin class _$UiRoutingConnectionCopyWith<$Res> implements $UiRoutingConnectionCopyWith<$Res> {
  factory _$UiRoutingConnectionCopyWith(_UiRoutingConnection value, $Res Function(_UiRoutingConnection) _then) = __$UiRoutingConnectionCopyWithImpl;
@override @useResult
$Res call({
 UiRoutingNode source, UiRoutingNode destination, double sendLevel, bool isSend
});


@override $UiRoutingNodeCopyWith<$Res> get source;@override $UiRoutingNodeCopyWith<$Res> get destination;

}
/// @nodoc
class __$UiRoutingConnectionCopyWithImpl<$Res>
    implements _$UiRoutingConnectionCopyWith<$Res> {
  __$UiRoutingConnectionCopyWithImpl(this._self, this._then);

  final _UiRoutingConnection _self;
  final $Res Function(_UiRoutingConnection) _then;

/// Create a copy of UiRoutingConnection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? destination = null,Object? sendLevel = null,Object? isSend = null,}) {
  return _then(_UiRoutingConnection(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as UiRoutingNode,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as UiRoutingNode,sendLevel: null == sendLevel ? _self.sendLevel : sendLevel // ignore: cast_nullable_to_non_nullable
as double,isSend: null == isSend ? _self.isSend : isSend // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of UiRoutingConnection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRoutingNodeCopyWith<$Res> get source {
  
  return $UiRoutingNodeCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}/// Create a copy of UiRoutingConnection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiRoutingNodeCopyWith<$Res> get destination {
  
  return $UiRoutingNodeCopyWith<$Res>(_self.destination, (value) {
    return _then(_self.copyWith(destination: value));
  });
}
}

/// @nodoc
mixin _$UiRoutingNode {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRoutingNode);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiRoutingNode()';
}


}

/// @nodoc
class $UiRoutingNodeCopyWith<$Res>  {
$UiRoutingNodeCopyWith(UiRoutingNode _, $Res Function(UiRoutingNode) __);
}


/// Adds pattern-matching-related methods to [UiRoutingNode].
extension UiRoutingNodePatterns on UiRoutingNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiRoutingNode_Track value)?  track,TResult Function( UiRoutingNode_Bus value)?  bus,TResult Function( UiRoutingNode_Master value)?  master,TResult Function( UiRoutingNode_PluginSidechain value)?  pluginSidechain,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiRoutingNode_Track() when track != null:
return track(_that);case UiRoutingNode_Bus() when bus != null:
return bus(_that);case UiRoutingNode_Master() when master != null:
return master(_that);case UiRoutingNode_PluginSidechain() when pluginSidechain != null:
return pluginSidechain(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiRoutingNode_Track value)  track,required TResult Function( UiRoutingNode_Bus value)  bus,required TResult Function( UiRoutingNode_Master value)  master,required TResult Function( UiRoutingNode_PluginSidechain value)  pluginSidechain,}){
final _that = this;
switch (_that) {
case UiRoutingNode_Track():
return track(_that);case UiRoutingNode_Bus():
return bus(_that);case UiRoutingNode_Master():
return master(_that);case UiRoutingNode_PluginSidechain():
return pluginSidechain(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiRoutingNode_Track value)?  track,TResult? Function( UiRoutingNode_Bus value)?  bus,TResult? Function( UiRoutingNode_Master value)?  master,TResult? Function( UiRoutingNode_PluginSidechain value)?  pluginSidechain,}){
final _that = this;
switch (_that) {
case UiRoutingNode_Track() when track != null:
return track(_that);case UiRoutingNode_Bus() when bus != null:
return bus(_that);case UiRoutingNode_Master() when master != null:
return master(_that);case UiRoutingNode_PluginSidechain() when pluginSidechain != null:
return pluginSidechain(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int field0)?  track,TResult Function( int field0)?  bus,TResult Function()?  master,TResult Function()?  pluginSidechain,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiRoutingNode_Track() when track != null:
return track(_that.field0);case UiRoutingNode_Bus() when bus != null:
return bus(_that.field0);case UiRoutingNode_Master() when master != null:
return master();case UiRoutingNode_PluginSidechain() when pluginSidechain != null:
return pluginSidechain();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int field0)  track,required TResult Function( int field0)  bus,required TResult Function()  master,required TResult Function()  pluginSidechain,}) {final _that = this;
switch (_that) {
case UiRoutingNode_Track():
return track(_that.field0);case UiRoutingNode_Bus():
return bus(_that.field0);case UiRoutingNode_Master():
return master();case UiRoutingNode_PluginSidechain():
return pluginSidechain();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int field0)?  track,TResult? Function( int field0)?  bus,TResult? Function()?  master,TResult? Function()?  pluginSidechain,}) {final _that = this;
switch (_that) {
case UiRoutingNode_Track() when track != null:
return track(_that.field0);case UiRoutingNode_Bus() when bus != null:
return bus(_that.field0);case UiRoutingNode_Master() when master != null:
return master();case UiRoutingNode_PluginSidechain() when pluginSidechain != null:
return pluginSidechain();case _:
  return null;

}
}

}

/// @nodoc


class UiRoutingNode_Track extends UiRoutingNode {
  const UiRoutingNode_Track(this.field0): super._();
  

 final  int field0;

/// Create a copy of UiRoutingNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiRoutingNode_TrackCopyWith<UiRoutingNode_Track> get copyWith => _$UiRoutingNode_TrackCopyWithImpl<UiRoutingNode_Track>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRoutingNode_Track&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiRoutingNode.track(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiRoutingNode_TrackCopyWith<$Res> implements $UiRoutingNodeCopyWith<$Res> {
  factory $UiRoutingNode_TrackCopyWith(UiRoutingNode_Track value, $Res Function(UiRoutingNode_Track) _then) = _$UiRoutingNode_TrackCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiRoutingNode_TrackCopyWithImpl<$Res>
    implements $UiRoutingNode_TrackCopyWith<$Res> {
  _$UiRoutingNode_TrackCopyWithImpl(this._self, this._then);

  final UiRoutingNode_Track _self;
  final $Res Function(UiRoutingNode_Track) _then;

/// Create a copy of UiRoutingNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiRoutingNode_Track(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiRoutingNode_Bus extends UiRoutingNode {
  const UiRoutingNode_Bus(this.field0): super._();
  

 final  int field0;

/// Create a copy of UiRoutingNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiRoutingNode_BusCopyWith<UiRoutingNode_Bus> get copyWith => _$UiRoutingNode_BusCopyWithImpl<UiRoutingNode_Bus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRoutingNode_Bus&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiRoutingNode.bus(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiRoutingNode_BusCopyWith<$Res> implements $UiRoutingNodeCopyWith<$Res> {
  factory $UiRoutingNode_BusCopyWith(UiRoutingNode_Bus value, $Res Function(UiRoutingNode_Bus) _then) = _$UiRoutingNode_BusCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$UiRoutingNode_BusCopyWithImpl<$Res>
    implements $UiRoutingNode_BusCopyWith<$Res> {
  _$UiRoutingNode_BusCopyWithImpl(this._self, this._then);

  final UiRoutingNode_Bus _self;
  final $Res Function(UiRoutingNode_Bus) _then;

/// Create a copy of UiRoutingNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiRoutingNode_Bus(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiRoutingNode_Master extends UiRoutingNode {
  const UiRoutingNode_Master(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRoutingNode_Master);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiRoutingNode.master()';
}


}




/// @nodoc


class UiRoutingNode_PluginSidechain extends UiRoutingNode {
  const UiRoutingNode_PluginSidechain(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiRoutingNode_PluginSidechain);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiRoutingNode.pluginSidechain()';
}


}




// dart format on
