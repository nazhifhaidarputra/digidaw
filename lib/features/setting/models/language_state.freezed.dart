// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'language_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LanguageState {

/// Every language, in the order the selector lists them.
 IList<UiLanguage> get languages;/// The saved choice; null follows the system language.
 String? get selected;/// The language messages are shown in; null until loaded.
 UiLanguage? get active;/// The language the system locales resolve to.
 UiLanguage? get system; bool get isApplying;
/// Create a copy of LanguageState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LanguageStateCopyWith<LanguageState> get copyWith => _$LanguageStateCopyWithImpl<LanguageState>(this as LanguageState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LanguageState&&const DeepCollectionEquality().equals(other.languages, languages)&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.active, active) || other.active == active)&&(identical(other.system, system) || other.system == system)&&(identical(other.isApplying, isApplying) || other.isApplying == isApplying));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(languages),selected,active,system,isApplying);

@override
String toString() {
  return 'LanguageState(languages: $languages, selected: $selected, active: $active, system: $system, isApplying: $isApplying)';
}


}

/// @nodoc
abstract mixin class $LanguageStateCopyWith<$Res>  {
  factory $LanguageStateCopyWith(LanguageState value, $Res Function(LanguageState) _then) = _$LanguageStateCopyWithImpl;
@useResult
$Res call({
 IList<UiLanguage> languages, String? selected, UiLanguage? active, UiLanguage? system, bool isApplying
});


$UiLanguageCopyWith<$Res>? get active;$UiLanguageCopyWith<$Res>? get system;

}
/// @nodoc
class _$LanguageStateCopyWithImpl<$Res>
    implements $LanguageStateCopyWith<$Res> {
  _$LanguageStateCopyWithImpl(this._self, this._then);

  final LanguageState _self;
  final $Res Function(LanguageState) _then;

/// Create a copy of LanguageState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? languages = null,Object? selected = freezed,Object? active = freezed,Object? system = freezed,Object? isApplying = null,}) {
  return _then(_self.copyWith(
languages: null == languages ? _self.languages : languages // ignore: cast_nullable_to_non_nullable
as IList<UiLanguage>,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as String?,active: freezed == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as UiLanguage?,system: freezed == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as UiLanguage?,isApplying: null == isApplying ? _self.isApplying : isApplying // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of LanguageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<$Res>? get active {
    if (_self.active == null) {
    return null;
  }

  return $UiLanguageCopyWith<$Res>(_self.active!, (value) {
    return _then(_self.copyWith(active: value));
  });
}/// Create a copy of LanguageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<$Res>? get system {
    if (_self.system == null) {
    return null;
  }

  return $UiLanguageCopyWith<$Res>(_self.system!, (value) {
    return _then(_self.copyWith(system: value));
  });
}
}


/// Adds pattern-matching-related methods to [LanguageState].
extension LanguageStatePatterns on LanguageState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LanguageState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LanguageState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LanguageState value)  $default,){
final _that = this;
switch (_that) {
case _LanguageState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LanguageState value)?  $default,){
final _that = this;
switch (_that) {
case _LanguageState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IList<UiLanguage> languages,  String? selected,  UiLanguage? active,  UiLanguage? system,  bool isApplying)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LanguageState() when $default != null:
return $default(_that.languages,_that.selected,_that.active,_that.system,_that.isApplying);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IList<UiLanguage> languages,  String? selected,  UiLanguage? active,  UiLanguage? system,  bool isApplying)  $default,) {final _that = this;
switch (_that) {
case _LanguageState():
return $default(_that.languages,_that.selected,_that.active,_that.system,_that.isApplying);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IList<UiLanguage> languages,  String? selected,  UiLanguage? active,  UiLanguage? system,  bool isApplying)?  $default,) {final _that = this;
switch (_that) {
case _LanguageState() when $default != null:
return $default(_that.languages,_that.selected,_that.active,_that.system,_that.isApplying);case _:
  return null;

}
}

}

/// @nodoc


class _LanguageState extends LanguageState {
  const _LanguageState({this.languages = const IListConst<UiLanguage>([]), this.selected, this.active, this.system, this.isApplying = false}): super._();
  

/// Every language, in the order the selector lists them.
@override@JsonKey() final  IList<UiLanguage> languages;
/// The saved choice; null follows the system language.
@override final  String? selected;
/// The language messages are shown in; null until loaded.
@override final  UiLanguage? active;
/// The language the system locales resolve to.
@override final  UiLanguage? system;
@override@JsonKey() final  bool isApplying;

/// Create a copy of LanguageState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LanguageStateCopyWith<_LanguageState> get copyWith => __$LanguageStateCopyWithImpl<_LanguageState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LanguageState&&const DeepCollectionEquality().equals(other.languages, languages)&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.active, active) || other.active == active)&&(identical(other.system, system) || other.system == system)&&(identical(other.isApplying, isApplying) || other.isApplying == isApplying));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(languages),selected,active,system,isApplying);

@override
String toString() {
  return 'LanguageState(languages: $languages, selected: $selected, active: $active, system: $system, isApplying: $isApplying)';
}


}

/// @nodoc
abstract mixin class _$LanguageStateCopyWith<$Res> implements $LanguageStateCopyWith<$Res> {
  factory _$LanguageStateCopyWith(_LanguageState value, $Res Function(_LanguageState) _then) = __$LanguageStateCopyWithImpl;
@override @useResult
$Res call({
 IList<UiLanguage> languages, String? selected, UiLanguage? active, UiLanguage? system, bool isApplying
});


@override $UiLanguageCopyWith<$Res>? get active;@override $UiLanguageCopyWith<$Res>? get system;

}
/// @nodoc
class __$LanguageStateCopyWithImpl<$Res>
    implements _$LanguageStateCopyWith<$Res> {
  __$LanguageStateCopyWithImpl(this._self, this._then);

  final _LanguageState _self;
  final $Res Function(_LanguageState) _then;

/// Create a copy of LanguageState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? languages = null,Object? selected = freezed,Object? active = freezed,Object? system = freezed,Object? isApplying = null,}) {
  return _then(_LanguageState(
languages: null == languages ? _self.languages : languages // ignore: cast_nullable_to_non_nullable
as IList<UiLanguage>,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as String?,active: freezed == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as UiLanguage?,system: freezed == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as UiLanguage?,isApplying: null == isApplying ? _self.isApplying : isApplying // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of LanguageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<$Res>? get active {
    if (_self.active == null) {
    return null;
  }

  return $UiLanguageCopyWith<$Res>(_self.active!, (value) {
    return _then(_self.copyWith(active: value));
  });
}/// Create a copy of LanguageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiLanguageCopyWith<$Res>? get system {
    if (_self.system == null) {
    return null;
  }

  return $UiLanguageCopyWith<$Res>(_self.system!, (value) {
    return _then(_self.copyWith(system: value));
  });
}
}

// dart format on
