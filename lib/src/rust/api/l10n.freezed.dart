// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'l10n.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiL10nValue {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiL10nValue&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'UiL10nValue(field0: $field0)';
}


}

/// @nodoc
class $UiL10nValueCopyWith<$Res>  {
$UiL10nValueCopyWith(UiL10nValue _, $Res Function(UiL10nValue) __);
}


/// Adds pattern-matching-related methods to [UiL10nValue].
extension UiL10nValuePatterns on UiL10nValue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiL10nValue_Text value)?  text,TResult Function( UiL10nValue_Number value)?  number,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiL10nValue_Text() when text != null:
return text(_that);case UiL10nValue_Number() when number != null:
return number(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiL10nValue_Text value)  text,required TResult Function( UiL10nValue_Number value)  number,}){
final _that = this;
switch (_that) {
case UiL10nValue_Text():
return text(_that);case UiL10nValue_Number():
return number(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiL10nValue_Text value)?  text,TResult? Function( UiL10nValue_Number value)?  number,}){
final _that = this;
switch (_that) {
case UiL10nValue_Text() when text != null:
return text(_that);case UiL10nValue_Number() when number != null:
return number(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String field0)?  text,TResult Function( double field0)?  number,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiL10nValue_Text() when text != null:
return text(_that.field0);case UiL10nValue_Number() when number != null:
return number(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String field0)  text,required TResult Function( double field0)  number,}) {final _that = this;
switch (_that) {
case UiL10nValue_Text():
return text(_that.field0);case UiL10nValue_Number():
return number(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String field0)?  text,TResult? Function( double field0)?  number,}) {final _that = this;
switch (_that) {
case UiL10nValue_Text() when text != null:
return text(_that.field0);case UiL10nValue_Number() when number != null:
return number(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class UiL10nValue_Text extends UiL10nValue {
  const UiL10nValue_Text(this.field0): super._();
  

@override final  String field0;

/// Create a copy of UiL10nValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiL10nValue_TextCopyWith<UiL10nValue_Text> get copyWith => _$UiL10nValue_TextCopyWithImpl<UiL10nValue_Text>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiL10nValue_Text&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiL10nValue.text(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiL10nValue_TextCopyWith<$Res> implements $UiL10nValueCopyWith<$Res> {
  factory $UiL10nValue_TextCopyWith(UiL10nValue_Text value, $Res Function(UiL10nValue_Text) _then) = _$UiL10nValue_TextCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$UiL10nValue_TextCopyWithImpl<$Res>
    implements $UiL10nValue_TextCopyWith<$Res> {
  _$UiL10nValue_TextCopyWithImpl(this._self, this._then);

  final UiL10nValue_Text _self;
  final $Res Function(UiL10nValue_Text) _then;

/// Create a copy of UiL10nValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiL10nValue_Text(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class UiL10nValue_Number extends UiL10nValue {
  const UiL10nValue_Number(this.field0): super._();
  

@override final  double field0;

/// Create a copy of UiL10nValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiL10nValue_NumberCopyWith<UiL10nValue_Number> get copyWith => _$UiL10nValue_NumberCopyWithImpl<UiL10nValue_Number>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiL10nValue_Number&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'UiL10nValue.number(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiL10nValue_NumberCopyWith<$Res> implements $UiL10nValueCopyWith<$Res> {
  factory $UiL10nValue_NumberCopyWith(UiL10nValue_Number value, $Res Function(UiL10nValue_Number) _then) = _$UiL10nValue_NumberCopyWithImpl;
@useResult
$Res call({
 double field0
});




}
/// @nodoc
class _$UiL10nValue_NumberCopyWithImpl<$Res>
    implements $UiL10nValue_NumberCopyWith<$Res> {
  _$UiL10nValue_NumberCopyWithImpl(this._self, this._then);

  final UiL10nValue_Number _self;
  final $Res Function(UiL10nValue_Number) _then;

/// Create a copy of UiL10nValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiL10nValue_Number(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$UiLanguage {

 String get code; String get nativeName; String get englishName; String get flag;
/// Create a copy of UiLanguage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<UiLanguage> get copyWith => _$UiLanguageCopyWithImpl<UiLanguage>(this as UiLanguage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiLanguage&&(identical(other.code, code) || other.code == code)&&(identical(other.nativeName, nativeName) || other.nativeName == nativeName)&&(identical(other.englishName, englishName) || other.englishName == englishName)&&(identical(other.flag, flag) || other.flag == flag));
}


@override
int get hashCode => Object.hash(runtimeType,code,nativeName,englishName,flag);

@override
String toString() {
  return 'UiLanguage(code: $code, nativeName: $nativeName, englishName: $englishName, flag: $flag)';
}


}

/// @nodoc
abstract mixin class $UiLanguageCopyWith<$Res>  {
  factory $UiLanguageCopyWith(UiLanguage value, $Res Function(UiLanguage) _then) = _$UiLanguageCopyWithImpl;
@useResult
$Res call({
 String code, String nativeName, String englishName, String flag
});




}
/// @nodoc
class _$UiLanguageCopyWithImpl<$Res>
    implements $UiLanguageCopyWith<$Res> {
  _$UiLanguageCopyWithImpl(this._self, this._then);

  final UiLanguage _self;
  final $Res Function(UiLanguage) _then;

/// Create a copy of UiLanguage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? nativeName = null,Object? englishName = null,Object? flag = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,nativeName: null == nativeName ? _self.nativeName : nativeName // ignore: cast_nullable_to_non_nullable
as String,englishName: null == englishName ? _self.englishName : englishName // ignore: cast_nullable_to_non_nullable
as String,flag: null == flag ? _self.flag : flag // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiLanguage].
extension UiLanguagePatterns on UiLanguage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiLanguage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiLanguage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiLanguage value)  $default,){
final _that = this;
switch (_that) {
case _UiLanguage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiLanguage value)?  $default,){
final _that = this;
switch (_that) {
case _UiLanguage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String nativeName,  String englishName,  String flag)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiLanguage() when $default != null:
return $default(_that.code,_that.nativeName,_that.englishName,_that.flag);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String nativeName,  String englishName,  String flag)  $default,) {final _that = this;
switch (_that) {
case _UiLanguage():
return $default(_that.code,_that.nativeName,_that.englishName,_that.flag);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String nativeName,  String englishName,  String flag)?  $default,) {final _that = this;
switch (_that) {
case _UiLanguage() when $default != null:
return $default(_that.code,_that.nativeName,_that.englishName,_that.flag);case _:
  return null;

}
}

}

/// @nodoc


class _UiLanguage implements UiLanguage {
  const _UiLanguage({required this.code, required this.nativeName, required this.englishName, required this.flag});
  

@override final  String code;
@override final  String nativeName;
@override final  String englishName;
@override final  String flag;

/// Create a copy of UiLanguage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiLanguageCopyWith<_UiLanguage> get copyWith => __$UiLanguageCopyWithImpl<_UiLanguage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiLanguage&&(identical(other.code, code) || other.code == code)&&(identical(other.nativeName, nativeName) || other.nativeName == nativeName)&&(identical(other.englishName, englishName) || other.englishName == englishName)&&(identical(other.flag, flag) || other.flag == flag));
}


@override
int get hashCode => Object.hash(runtimeType,code,nativeName,englishName,flag);

@override
String toString() {
  return 'UiLanguage(code: $code, nativeName: $nativeName, englishName: $englishName, flag: $flag)';
}


}

/// @nodoc
abstract mixin class _$UiLanguageCopyWith<$Res> implements $UiLanguageCopyWith<$Res> {
  factory _$UiLanguageCopyWith(_UiLanguage value, $Res Function(_UiLanguage) _then) = __$UiLanguageCopyWithImpl;
@override @useResult
$Res call({
 String code, String nativeName, String englishName, String flag
});




}
/// @nodoc
class __$UiLanguageCopyWithImpl<$Res>
    implements _$UiLanguageCopyWith<$Res> {
  __$UiLanguageCopyWithImpl(this._self, this._then);

  final _UiLanguage _self;
  final $Res Function(_UiLanguage) _then;

/// Create a copy of UiLanguage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? nativeName = null,Object? englishName = null,Object? flag = null,}) {
  return _then(_UiLanguage(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,nativeName: null == nativeName ? _self.nativeName : nativeName // ignore: cast_nullable_to_non_nullable
as String,englishName: null == englishName ? _self.englishName : englishName // ignore: cast_nullable_to_non_nullable
as String,flag: null == flag ? _self.flag : flag // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiLanguageState {

 String? get selected; UiLanguage get active; UiLanguage get system;
/// Create a copy of UiLanguageState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiLanguageStateCopyWith<UiLanguageState> get copyWith => _$UiLanguageStateCopyWithImpl<UiLanguageState>(this as UiLanguageState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiLanguageState&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.active, active) || other.active == active)&&(identical(other.system, system) || other.system == system));
}


@override
int get hashCode => Object.hash(runtimeType,selected,active,system);

@override
String toString() {
  return 'UiLanguageState(selected: $selected, active: $active, system: $system)';
}


}

/// @nodoc
abstract mixin class $UiLanguageStateCopyWith<$Res>  {
  factory $UiLanguageStateCopyWith(UiLanguageState value, $Res Function(UiLanguageState) _then) = _$UiLanguageStateCopyWithImpl;
@useResult
$Res call({
 String? selected, UiLanguage active, UiLanguage system
});


$UiLanguageCopyWith<$Res> get active;$UiLanguageCopyWith<$Res> get system;

}
/// @nodoc
class _$UiLanguageStateCopyWithImpl<$Res>
    implements $UiLanguageStateCopyWith<$Res> {
  _$UiLanguageStateCopyWithImpl(this._self, this._then);

  final UiLanguageState _self;
  final $Res Function(UiLanguageState) _then;

/// Create a copy of UiLanguageState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selected = freezed,Object? active = null,Object? system = null,}) {
  return _then(_self.copyWith(
selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as UiLanguage,system: null == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as UiLanguage,
  ));
}
/// Create a copy of UiLanguageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<$Res> get active {
  
  return $UiLanguageCopyWith<$Res>(_self.active, (value) {
    return _then(_self.copyWith(active: value));
  });
}/// Create a copy of UiLanguageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<$Res> get system {
  
  return $UiLanguageCopyWith<$Res>(_self.system, (value) {
    return _then(_self.copyWith(system: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiLanguageState].
extension UiLanguageStatePatterns on UiLanguageState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiLanguageState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiLanguageState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiLanguageState value)  $default,){
final _that = this;
switch (_that) {
case _UiLanguageState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiLanguageState value)?  $default,){
final _that = this;
switch (_that) {
case _UiLanguageState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? selected,  UiLanguage active,  UiLanguage system)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiLanguageState() when $default != null:
return $default(_that.selected,_that.active,_that.system);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? selected,  UiLanguage active,  UiLanguage system)  $default,) {final _that = this;
switch (_that) {
case _UiLanguageState():
return $default(_that.selected,_that.active,_that.system);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? selected,  UiLanguage active,  UiLanguage system)?  $default,) {final _that = this;
switch (_that) {
case _UiLanguageState() when $default != null:
return $default(_that.selected,_that.active,_that.system);case _:
  return null;

}
}

}

/// @nodoc


class _UiLanguageState implements UiLanguageState {
  const _UiLanguageState({this.selected, required this.active, required this.system});
  

@override final  String? selected;
@override final  UiLanguage active;
@override final  UiLanguage system;

/// Create a copy of UiLanguageState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiLanguageStateCopyWith<_UiLanguageState> get copyWith => __$UiLanguageStateCopyWithImpl<_UiLanguageState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiLanguageState&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.active, active) || other.active == active)&&(identical(other.system, system) || other.system == system));
}


@override
int get hashCode => Object.hash(runtimeType,selected,active,system);

@override
String toString() {
  return 'UiLanguageState(selected: $selected, active: $active, system: $system)';
}


}

/// @nodoc
abstract mixin class _$UiLanguageStateCopyWith<$Res> implements $UiLanguageStateCopyWith<$Res> {
  factory _$UiLanguageStateCopyWith(_UiLanguageState value, $Res Function(_UiLanguageState) _then) = __$UiLanguageStateCopyWithImpl;
@override @useResult
$Res call({
 String? selected, UiLanguage active, UiLanguage system
});


@override $UiLanguageCopyWith<$Res> get active;@override $UiLanguageCopyWith<$Res> get system;

}
/// @nodoc
class __$UiLanguageStateCopyWithImpl<$Res>
    implements _$UiLanguageStateCopyWith<$Res> {
  __$UiLanguageStateCopyWithImpl(this._self, this._then);

  final _UiLanguageState _self;
  final $Res Function(_UiLanguageState) _then;

/// Create a copy of UiLanguageState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selected = freezed,Object? active = null,Object? system = null,}) {
  return _then(_UiLanguageState(
selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as UiLanguage,system: null == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as UiLanguage,
  ));
}

/// Create a copy of UiLanguageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<$Res> get active {
  
  return $UiLanguageCopyWith<$Res>(_self.active, (value) {
    return _then(_self.copyWith(active: value));
  });
}/// Create a copy of UiLanguageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<$Res> get system {
  
  return $UiLanguageCopyWith<$Res>(_self.system, (value) {
    return _then(_self.copyWith(system: value));
  });
}
}

// dart format on
