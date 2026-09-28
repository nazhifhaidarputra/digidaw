// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_browser_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginBrowserEntry {

 int get registryId; String get favoriteKey; String get name; String get vendor; KarbeatPluginType get pluginType; PluginBinaryType get binaryType; bool get isExternal;
/// Create a copy of PluginBrowserEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginBrowserEntryCopyWith<PluginBrowserEntry> get copyWith => _$PluginBrowserEntryCopyWithImpl<PluginBrowserEntry>(this as PluginBrowserEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginBrowserEntry&&(identical(other.registryId, registryId) || other.registryId == registryId)&&(identical(other.favoriteKey, favoriteKey) || other.favoriteKey == favoriteKey)&&(identical(other.name, name) || other.name == name)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.pluginType, pluginType) || other.pluginType == pluginType)&&(identical(other.binaryType, binaryType) || other.binaryType == binaryType)&&(identical(other.isExternal, isExternal) || other.isExternal == isExternal));
}


@override
int get hashCode => Object.hash(runtimeType,registryId,favoriteKey,name,vendor,pluginType,binaryType,isExternal);

@override
String toString() {
  return 'PluginBrowserEntry(registryId: $registryId, favoriteKey: $favoriteKey, name: $name, vendor: $vendor, pluginType: $pluginType, binaryType: $binaryType, isExternal: $isExternal)';
}


}

/// @nodoc
abstract mixin class $PluginBrowserEntryCopyWith<$Res>  {
  factory $PluginBrowserEntryCopyWith(PluginBrowserEntry value, $Res Function(PluginBrowserEntry) _then) = _$PluginBrowserEntryCopyWithImpl;
@useResult
$Res call({
 int registryId, String favoriteKey, String name, String vendor, KarbeatPluginType pluginType, PluginBinaryType binaryType, bool isExternal
});




}
/// @nodoc
class _$PluginBrowserEntryCopyWithImpl<$Res>
    implements $PluginBrowserEntryCopyWith<$Res> {
  _$PluginBrowserEntryCopyWithImpl(this._self, this._then);

  final PluginBrowserEntry _self;
  final $Res Function(PluginBrowserEntry) _then;

/// Create a copy of PluginBrowserEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? registryId = null,Object? favoriteKey = null,Object? name = null,Object? vendor = null,Object? pluginType = null,Object? binaryType = null,Object? isExternal = null,}) {
  return _then(_self.copyWith(
registryId: null == registryId ? _self.registryId : registryId // ignore: cast_nullable_to_non_nullable
as int,favoriteKey: null == favoriteKey ? _self.favoriteKey : favoriteKey // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,pluginType: null == pluginType ? _self.pluginType : pluginType // ignore: cast_nullable_to_non_nullable
as KarbeatPluginType,binaryType: null == binaryType ? _self.binaryType : binaryType // ignore: cast_nullable_to_non_nullable
as PluginBinaryType,isExternal: null == isExternal ? _self.isExternal : isExternal // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginBrowserEntry].
extension PluginBrowserEntryPatterns on PluginBrowserEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginBrowserEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginBrowserEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginBrowserEntry value)  $default,){
final _that = this;
switch (_that) {
case _PluginBrowserEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginBrowserEntry value)?  $default,){
final _that = this;
switch (_that) {
case _PluginBrowserEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int registryId,  String favoriteKey,  String name,  String vendor,  KarbeatPluginType pluginType,  PluginBinaryType binaryType,  bool isExternal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginBrowserEntry() when $default != null:
return $default(_that.registryId,_that.favoriteKey,_that.name,_that.vendor,_that.pluginType,_that.binaryType,_that.isExternal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int registryId,  String favoriteKey,  String name,  String vendor,  KarbeatPluginType pluginType,  PluginBinaryType binaryType,  bool isExternal)  $default,) {final _that = this;
switch (_that) {
case _PluginBrowserEntry():
return $default(_that.registryId,_that.favoriteKey,_that.name,_that.vendor,_that.pluginType,_that.binaryType,_that.isExternal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int registryId,  String favoriteKey,  String name,  String vendor,  KarbeatPluginType pluginType,  PluginBinaryType binaryType,  bool isExternal)?  $default,) {final _that = this;
switch (_that) {
case _PluginBrowserEntry() when $default != null:
return $default(_that.registryId,_that.favoriteKey,_that.name,_that.vendor,_that.pluginType,_that.binaryType,_that.isExternal);case _:
  return null;

}
}

}

/// @nodoc


class _PluginBrowserEntry implements PluginBrowserEntry {
  const _PluginBrowserEntry({required this.registryId, required this.favoriteKey, required this.name, required this.vendor, required this.pluginType, required this.binaryType, required this.isExternal});
  

@override final  int registryId;
@override final  String favoriteKey;
@override final  String name;
@override final  String vendor;
@override final  KarbeatPluginType pluginType;
@override final  PluginBinaryType binaryType;
@override final  bool isExternal;

/// Create a copy of PluginBrowserEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginBrowserEntryCopyWith<_PluginBrowserEntry> get copyWith => __$PluginBrowserEntryCopyWithImpl<_PluginBrowserEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginBrowserEntry&&(identical(other.registryId, registryId) || other.registryId == registryId)&&(identical(other.favoriteKey, favoriteKey) || other.favoriteKey == favoriteKey)&&(identical(other.name, name) || other.name == name)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.pluginType, pluginType) || other.pluginType == pluginType)&&(identical(other.binaryType, binaryType) || other.binaryType == binaryType)&&(identical(other.isExternal, isExternal) || other.isExternal == isExternal));
}


@override
int get hashCode => Object.hash(runtimeType,registryId,favoriteKey,name,vendor,pluginType,binaryType,isExternal);

@override
String toString() {
  return 'PluginBrowserEntry(registryId: $registryId, favoriteKey: $favoriteKey, name: $name, vendor: $vendor, pluginType: $pluginType, binaryType: $binaryType, isExternal: $isExternal)';
}


}

/// @nodoc
abstract mixin class _$PluginBrowserEntryCopyWith<$Res> implements $PluginBrowserEntryCopyWith<$Res> {
  factory _$PluginBrowserEntryCopyWith(_PluginBrowserEntry value, $Res Function(_PluginBrowserEntry) _then) = __$PluginBrowserEntryCopyWithImpl;
@override @useResult
$Res call({
 int registryId, String favoriteKey, String name, String vendor, KarbeatPluginType pluginType, PluginBinaryType binaryType, bool isExternal
});




}
/// @nodoc
class __$PluginBrowserEntryCopyWithImpl<$Res>
    implements _$PluginBrowserEntryCopyWith<$Res> {
  __$PluginBrowserEntryCopyWithImpl(this._self, this._then);

  final _PluginBrowserEntry _self;
  final $Res Function(_PluginBrowserEntry) _then;

/// Create a copy of PluginBrowserEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? registryId = null,Object? favoriteKey = null,Object? name = null,Object? vendor = null,Object? pluginType = null,Object? binaryType = null,Object? isExternal = null,}) {
  return _then(_PluginBrowserEntry(
registryId: null == registryId ? _self.registryId : registryId // ignore: cast_nullable_to_non_nullable
as int,favoriteKey: null == favoriteKey ? _self.favoriteKey : favoriteKey // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,pluginType: null == pluginType ? _self.pluginType : pluginType // ignore: cast_nullable_to_non_nullable
as KarbeatPluginType,binaryType: null == binaryType ? _self.binaryType : binaryType // ignore: cast_nullable_to_non_nullable
as PluginBinaryType,isExternal: null == isExternal ? _self.isExternal : isExternal // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
