// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_plugins_service.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginRegistry {

 IList<UiPluginInfo> get availablePlugins; IList<PluginBrowserEntry> get browserEntries;
/// Create a copy of PluginRegistry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginRegistryCopyWith<PluginRegistry> get copyWith => _$PluginRegistryCopyWithImpl<PluginRegistry>(this as PluginRegistry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginRegistry&&const DeepCollectionEquality().equals(other.availablePlugins, availablePlugins)&&const DeepCollectionEquality().equals(other.browserEntries, browserEntries));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(availablePlugins),const DeepCollectionEquality().hash(browserEntries));

@override
String toString() {
  return 'PluginRegistry(availablePlugins: $availablePlugins, browserEntries: $browserEntries)';
}


}

/// @nodoc
abstract mixin class $PluginRegistryCopyWith<$Res>  {
  factory $PluginRegistryCopyWith(PluginRegistry value, $Res Function(PluginRegistry) _then) = _$PluginRegistryCopyWithImpl;
@useResult
$Res call({
 IList<UiPluginInfo> availablePlugins, IList<PluginBrowserEntry> browserEntries
});




}
/// @nodoc
class _$PluginRegistryCopyWithImpl<$Res>
    implements $PluginRegistryCopyWith<$Res> {
  _$PluginRegistryCopyWithImpl(this._self, this._then);

  final PluginRegistry _self;
  final $Res Function(PluginRegistry) _then;

/// Create a copy of PluginRegistry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? availablePlugins = null,Object? browserEntries = null,}) {
  return _then(_self.copyWith(
availablePlugins: null == availablePlugins ? _self.availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as IList<UiPluginInfo>,browserEntries: null == browserEntries ? _self.browserEntries : browserEntries // ignore: cast_nullable_to_non_nullable
as IList<PluginBrowserEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [PluginRegistry].
extension PluginRegistryPatterns on PluginRegistry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginRegistry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginRegistry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginRegistry value)  $default,){
final _that = this;
switch (_that) {
case _PluginRegistry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginRegistry value)?  $default,){
final _that = this;
switch (_that) {
case _PluginRegistry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IList<UiPluginInfo> availablePlugins,  IList<PluginBrowserEntry> browserEntries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginRegistry() when $default != null:
return $default(_that.availablePlugins,_that.browserEntries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IList<UiPluginInfo> availablePlugins,  IList<PluginBrowserEntry> browserEntries)  $default,) {final _that = this;
switch (_that) {
case _PluginRegistry():
return $default(_that.availablePlugins,_that.browserEntries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IList<UiPluginInfo> availablePlugins,  IList<PluginBrowserEntry> browserEntries)?  $default,) {final _that = this;
switch (_that) {
case _PluginRegistry() when $default != null:
return $default(_that.availablePlugins,_that.browserEntries);case _:
  return null;

}
}

}

/// @nodoc


class _PluginRegistry implements PluginRegistry {
  const _PluginRegistry({this.availablePlugins = const IListConst<UiPluginInfo>([]), this.browserEntries = const IListConst<PluginBrowserEntry>([])});
  

@override@JsonKey() final  IList<UiPluginInfo> availablePlugins;
@override@JsonKey() final  IList<PluginBrowserEntry> browserEntries;

/// Create a copy of PluginRegistry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginRegistryCopyWith<_PluginRegistry> get copyWith => __$PluginRegistryCopyWithImpl<_PluginRegistry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginRegistry&&const DeepCollectionEquality().equals(other.availablePlugins, availablePlugins)&&const DeepCollectionEquality().equals(other.browserEntries, browserEntries));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(availablePlugins),const DeepCollectionEquality().hash(browserEntries));

@override
String toString() {
  return 'PluginRegistry(availablePlugins: $availablePlugins, browserEntries: $browserEntries)';
}


}

/// @nodoc
abstract mixin class _$PluginRegistryCopyWith<$Res> implements $PluginRegistryCopyWith<$Res> {
  factory _$PluginRegistryCopyWith(_PluginRegistry value, $Res Function(_PluginRegistry) _then) = __$PluginRegistryCopyWithImpl;
@override @useResult
$Res call({
 IList<UiPluginInfo> availablePlugins, IList<PluginBrowserEntry> browserEntries
});




}
/// @nodoc
class __$PluginRegistryCopyWithImpl<$Res>
    implements _$PluginRegistryCopyWith<$Res> {
  __$PluginRegistryCopyWithImpl(this._self, this._then);

  final _PluginRegistry _self;
  final $Res Function(_PluginRegistry) _then;

/// Create a copy of PluginRegistry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? availablePlugins = null,Object? browserEntries = null,}) {
  return _then(_PluginRegistry(
availablePlugins: null == availablePlugins ? _self.availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as IList<UiPluginInfo>,browserEntries: null == browserEntries ? _self.browserEntries : browserEntries // ignore: cast_nullable_to_non_nullable
as IList<PluginBrowserEntry>,
  ));
}


}

/// @nodoc
mixin _$PluginState {

 PluginRegistry get registry; ISet<String> get favoriteKeys; ISet<String> get pendingFavoriteKeys;
/// Create a copy of PluginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginStateCopyWith<PluginState> get copyWith => _$PluginStateCopyWithImpl<PluginState>(this as PluginState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginState&&(identical(other.registry, registry) || other.registry == registry)&&const DeepCollectionEquality().equals(other.favoriteKeys, favoriteKeys)&&const DeepCollectionEquality().equals(other.pendingFavoriteKeys, pendingFavoriteKeys));
}


@override
int get hashCode => Object.hash(runtimeType,registry,const DeepCollectionEquality().hash(favoriteKeys),const DeepCollectionEquality().hash(pendingFavoriteKeys));

@override
String toString() {
  return 'PluginState(registry: $registry, favoriteKeys: $favoriteKeys, pendingFavoriteKeys: $pendingFavoriteKeys)';
}


}

/// @nodoc
abstract mixin class $PluginStateCopyWith<$Res>  {
  factory $PluginStateCopyWith(PluginState value, $Res Function(PluginState) _then) = _$PluginStateCopyWithImpl;
@useResult
$Res call({
 PluginRegistry registry, ISet<String> favoriteKeys, ISet<String> pendingFavoriteKeys
});


$PluginRegistryCopyWith<$Res> get registry;

}
/// @nodoc
class _$PluginStateCopyWithImpl<$Res>
    implements $PluginStateCopyWith<$Res> {
  _$PluginStateCopyWithImpl(this._self, this._then);

  final PluginState _self;
  final $Res Function(PluginState) _then;

/// Create a copy of PluginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? registry = null,Object? favoriteKeys = null,Object? pendingFavoriteKeys = null,}) {
  return _then(_self.copyWith(
registry: null == registry ? _self.registry : registry // ignore: cast_nullable_to_non_nullable
as PluginRegistry,favoriteKeys: null == favoriteKeys ? _self.favoriteKeys : favoriteKeys // ignore: cast_nullable_to_non_nullable
as ISet<String>,pendingFavoriteKeys: null == pendingFavoriteKeys ? _self.pendingFavoriteKeys : pendingFavoriteKeys // ignore: cast_nullable_to_non_nullable
as ISet<String>,
  ));
}
/// Create a copy of PluginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginRegistryCopyWith<$Res> get registry {
  
  return $PluginRegistryCopyWith<$Res>(_self.registry, (value) {
    return _then(_self.copyWith(registry: value));
  });
}
}


/// Adds pattern-matching-related methods to [PluginState].
extension PluginStatePatterns on PluginState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PluginState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PluginState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PluginState value)  $default,){
final _that = this;
switch (_that) {
case _PluginState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PluginState value)?  $default,){
final _that = this;
switch (_that) {
case _PluginState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PluginRegistry registry,  ISet<String> favoriteKeys,  ISet<String> pendingFavoriteKeys)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PluginState() when $default != null:
return $default(_that.registry,_that.favoriteKeys,_that.pendingFavoriteKeys);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PluginRegistry registry,  ISet<String> favoriteKeys,  ISet<String> pendingFavoriteKeys)  $default,) {final _that = this;
switch (_that) {
case _PluginState():
return $default(_that.registry,_that.favoriteKeys,_that.pendingFavoriteKeys);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PluginRegistry registry,  ISet<String> favoriteKeys,  ISet<String> pendingFavoriteKeys)?  $default,) {final _that = this;
switch (_that) {
case _PluginState() when $default != null:
return $default(_that.registry,_that.favoriteKeys,_that.pendingFavoriteKeys);case _:
  return null;

}
}

}

/// @nodoc


class _PluginState implements PluginState {
  const _PluginState({this.registry = const PluginRegistry(), this.favoriteKeys = const ISetConst<String>({}), this.pendingFavoriteKeys = const ISetConst<String>({})});
  

@override@JsonKey() final  PluginRegistry registry;
@override@JsonKey() final  ISet<String> favoriteKeys;
@override@JsonKey() final  ISet<String> pendingFavoriteKeys;

/// Create a copy of PluginState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginStateCopyWith<_PluginState> get copyWith => __$PluginStateCopyWithImpl<_PluginState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginState&&(identical(other.registry, registry) || other.registry == registry)&&const DeepCollectionEquality().equals(other.favoriteKeys, favoriteKeys)&&const DeepCollectionEquality().equals(other.pendingFavoriteKeys, pendingFavoriteKeys));
}


@override
int get hashCode => Object.hash(runtimeType,registry,const DeepCollectionEquality().hash(favoriteKeys),const DeepCollectionEquality().hash(pendingFavoriteKeys));

@override
String toString() {
  return 'PluginState(registry: $registry, favoriteKeys: $favoriteKeys, pendingFavoriteKeys: $pendingFavoriteKeys)';
}


}

/// @nodoc
abstract mixin class _$PluginStateCopyWith<$Res> implements $PluginStateCopyWith<$Res> {
  factory _$PluginStateCopyWith(_PluginState value, $Res Function(_PluginState) _then) = __$PluginStateCopyWithImpl;
@override @useResult
$Res call({
 PluginRegistry registry, ISet<String> favoriteKeys, ISet<String> pendingFavoriteKeys
});


@override $PluginRegistryCopyWith<$Res> get registry;

}
/// @nodoc
class __$PluginStateCopyWithImpl<$Res>
    implements _$PluginStateCopyWith<$Res> {
  __$PluginStateCopyWithImpl(this._self, this._then);

  final _PluginState _self;
  final $Res Function(_PluginState) _then;

/// Create a copy of PluginState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? registry = null,Object? favoriteKeys = null,Object? pendingFavoriteKeys = null,}) {
  return _then(_PluginState(
registry: null == registry ? _self.registry : registry // ignore: cast_nullable_to_non_nullable
as PluginRegistry,favoriteKeys: null == favoriteKeys ? _self.favoriteKeys : favoriteKeys // ignore: cast_nullable_to_non_nullable
as ISet<String>,pendingFavoriteKeys: null == pendingFavoriteKeys ? _self.pendingFavoriteKeys : pendingFavoriteKeys // ignore: cast_nullable_to_non_nullable
as ISet<String>,
  ));
}

/// Create a copy of PluginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginRegistryCopyWith<$Res> get registry {
  
  return $PluginRegistryCopyWith<$Res>(_self.registry, (value) {
    return _then(_self.copyWith(registry: value));
  });
}
}

// dart format on
