// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ApplicationDataStore {

 String? get currentFilePath; UiProjectMetadata get metadata; UiTransportState get transport; UiAudioHardwareConfig get hardwareConfig; IMap<int, UiTrack> get tracks; IMap<int, UiGeneratorInstance> get generators; IMap<int, UiPattern> get patterns; mixer_api.UiMixerState get mixer; IMap<int, ModulationLinkDto> get modulationLinks; IMap<int, AutomationLaneDto> get automationPool; IMap<int, ModulationSourceDto> get modulationSources;
/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApplicationDataStoreCopyWith<ApplicationDataStore> get copyWith => _$ApplicationDataStoreCopyWithImpl<ApplicationDataStore>(this as ApplicationDataStore, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApplicationDataStore&&(identical(other.currentFilePath, currentFilePath) || other.currentFilePath == currentFilePath)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.transport, transport) || other.transport == transport)&&(identical(other.hardwareConfig, hardwareConfig) || other.hardwareConfig == hardwareConfig)&&(identical(other.tracks, tracks) || other.tracks == tracks)&&(identical(other.generators, generators) || other.generators == generators)&&(identical(other.patterns, patterns) || other.patterns == patterns)&&(identical(other.mixer, mixer) || other.mixer == mixer)&&(identical(other.modulationLinks, modulationLinks) || other.modulationLinks == modulationLinks)&&(identical(other.automationPool, automationPool) || other.automationPool == automationPool)&&(identical(other.modulationSources, modulationSources) || other.modulationSources == modulationSources));
}


@override
int get hashCode => Object.hash(runtimeType,currentFilePath,metadata,transport,hardwareConfig,tracks,generators,patterns,mixer,modulationLinks,automationPool,modulationSources);

@override
String toString() {
  return 'ApplicationDataStore(currentFilePath: $currentFilePath, metadata: $metadata, transport: $transport, hardwareConfig: $hardwareConfig, tracks: $tracks, generators: $generators, patterns: $patterns, mixer: $mixer, modulationLinks: $modulationLinks, automationPool: $automationPool, modulationSources: $modulationSources)';
}


}

/// @nodoc
abstract mixin class $ApplicationDataStoreCopyWith<$Res>  {
  factory $ApplicationDataStoreCopyWith(ApplicationDataStore value, $Res Function(ApplicationDataStore) _then) = _$ApplicationDataStoreCopyWithImpl;
@useResult
$Res call({
 String? currentFilePath, UiProjectMetadata metadata, UiTransportState transport, UiAudioHardwareConfig hardwareConfig, IMap<int, UiTrack> tracks, IMap<int, UiGeneratorInstance> generators, IMap<int, UiPattern> patterns, mixer_api.UiMixerState mixer, IMap<int, ModulationLinkDto> modulationLinks, IMap<int, AutomationLaneDto> automationPool, IMap<int, ModulationSourceDto> modulationSources
});


$UiProjectMetadataCopyWith<$Res> get metadata;$UiTransportStateCopyWith<$Res> get transport;$UiAudioHardwareConfigCopyWith<$Res> get hardwareConfig;$UiMixerStateCopyWith<$Res> get mixer;

}
/// @nodoc
class _$ApplicationDataStoreCopyWithImpl<$Res>
    implements $ApplicationDataStoreCopyWith<$Res> {
  _$ApplicationDataStoreCopyWithImpl(this._self, this._then);

  final ApplicationDataStore _self;
  final $Res Function(ApplicationDataStore) _then;

/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentFilePath = freezed,Object? metadata = null,Object? transport = null,Object? hardwareConfig = null,Object? tracks = null,Object? generators = null,Object? patterns = null,Object? mixer = null,Object? modulationLinks = null,Object? automationPool = null,Object? modulationSources = null,}) {
  return _then(_self.copyWith(
currentFilePath: freezed == currentFilePath ? _self.currentFilePath : currentFilePath // ignore: cast_nullable_to_non_nullable
as String?,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as UiProjectMetadata,transport: null == transport ? _self.transport : transport // ignore: cast_nullable_to_non_nullable
as UiTransportState,hardwareConfig: null == hardwareConfig ? _self.hardwareConfig : hardwareConfig // ignore: cast_nullable_to_non_nullable
as UiAudioHardwareConfig,tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as IMap<int, UiTrack>,generators: null == generators ? _self.generators : generators // ignore: cast_nullable_to_non_nullable
as IMap<int, UiGeneratorInstance>,patterns: null == patterns ? _self.patterns : patterns // ignore: cast_nullable_to_non_nullable
as IMap<int, UiPattern>,mixer: null == mixer ? _self.mixer : mixer // ignore: cast_nullable_to_non_nullable
as mixer_api.UiMixerState,modulationLinks: null == modulationLinks ? _self.modulationLinks : modulationLinks // ignore: cast_nullable_to_non_nullable
as IMap<int, ModulationLinkDto>,automationPool: null == automationPool ? _self.automationPool : automationPool // ignore: cast_nullable_to_non_nullable
as IMap<int, AutomationLaneDto>,modulationSources: null == modulationSources ? _self.modulationSources : modulationSources // ignore: cast_nullable_to_non_nullable
as IMap<int, ModulationSourceDto>,
  ));
}
/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiProjectMetadataCopyWith<$Res> get metadata {
  
  return $UiProjectMetadataCopyWith<$Res>(_self.metadata, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiTransportStateCopyWith<$Res> get transport {
  
  return $UiTransportStateCopyWith<$Res>(_self.transport, (value) {
    return _then(_self.copyWith(transport: value));
  });
}/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiAudioHardwareConfigCopyWith<$Res> get hardwareConfig {
  
  return $UiAudioHardwareConfigCopyWith<$Res>(_self.hardwareConfig, (value) {
    return _then(_self.copyWith(hardwareConfig: value));
  });
}/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiMixerStateCopyWith<$Res> get mixer {
  
  return $UiMixerStateCopyWith<$Res>(_self.mixer, (value) {
    return _then(_self.copyWith(mixer: value));
  });
}
}


/// Adds pattern-matching-related methods to [ApplicationDataStore].
extension ApplicationDataStorePatterns on ApplicationDataStore {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApplicationDataStore value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApplicationDataStore() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApplicationDataStore value)  $default,){
final _that = this;
switch (_that) {
case _ApplicationDataStore():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApplicationDataStore value)?  $default,){
final _that = this;
switch (_that) {
case _ApplicationDataStore() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? currentFilePath,  UiProjectMetadata metadata,  UiTransportState transport,  UiAudioHardwareConfig hardwareConfig,  IMap<int, UiTrack> tracks,  IMap<int, UiGeneratorInstance> generators,  IMap<int, UiPattern> patterns,  mixer_api.UiMixerState mixer,  IMap<int, ModulationLinkDto> modulationLinks,  IMap<int, AutomationLaneDto> automationPool,  IMap<int, ModulationSourceDto> modulationSources)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApplicationDataStore() when $default != null:
return $default(_that.currentFilePath,_that.metadata,_that.transport,_that.hardwareConfig,_that.tracks,_that.generators,_that.patterns,_that.mixer,_that.modulationLinks,_that.automationPool,_that.modulationSources);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? currentFilePath,  UiProjectMetadata metadata,  UiTransportState transport,  UiAudioHardwareConfig hardwareConfig,  IMap<int, UiTrack> tracks,  IMap<int, UiGeneratorInstance> generators,  IMap<int, UiPattern> patterns,  mixer_api.UiMixerState mixer,  IMap<int, ModulationLinkDto> modulationLinks,  IMap<int, AutomationLaneDto> automationPool,  IMap<int, ModulationSourceDto> modulationSources)  $default,) {final _that = this;
switch (_that) {
case _ApplicationDataStore():
return $default(_that.currentFilePath,_that.metadata,_that.transport,_that.hardwareConfig,_that.tracks,_that.generators,_that.patterns,_that.mixer,_that.modulationLinks,_that.automationPool,_that.modulationSources);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? currentFilePath,  UiProjectMetadata metadata,  UiTransportState transport,  UiAudioHardwareConfig hardwareConfig,  IMap<int, UiTrack> tracks,  IMap<int, UiGeneratorInstance> generators,  IMap<int, UiPattern> patterns,  mixer_api.UiMixerState mixer,  IMap<int, ModulationLinkDto> modulationLinks,  IMap<int, AutomationLaneDto> automationPool,  IMap<int, ModulationSourceDto> modulationSources)?  $default,) {final _that = this;
switch (_that) {
case _ApplicationDataStore() when $default != null:
return $default(_that.currentFilePath,_that.metadata,_that.transport,_that.hardwareConfig,_that.tracks,_that.generators,_that.patterns,_that.mixer,_that.modulationLinks,_that.automationPool,_that.modulationSources);case _:
  return null;

}
}

}

/// @nodoc


class _ApplicationDataStore implements ApplicationDataStore {
  const _ApplicationDataStore({this.currentFilePath, required this.metadata, required this.transport, required this.hardwareConfig, required this.tracks, required this.generators, required this.patterns, required this.mixer, required this.modulationLinks, required this.automationPool, required this.modulationSources});
  

@override final  String? currentFilePath;
@override final  UiProjectMetadata metadata;
@override final  UiTransportState transport;
@override final  UiAudioHardwareConfig hardwareConfig;
@override final  IMap<int, UiTrack> tracks;
@override final  IMap<int, UiGeneratorInstance> generators;
@override final  IMap<int, UiPattern> patterns;
@override final  mixer_api.UiMixerState mixer;
@override final  IMap<int, ModulationLinkDto> modulationLinks;
@override final  IMap<int, AutomationLaneDto> automationPool;
@override final  IMap<int, ModulationSourceDto> modulationSources;

/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApplicationDataStoreCopyWith<_ApplicationDataStore> get copyWith => __$ApplicationDataStoreCopyWithImpl<_ApplicationDataStore>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApplicationDataStore&&(identical(other.currentFilePath, currentFilePath) || other.currentFilePath == currentFilePath)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.transport, transport) || other.transport == transport)&&(identical(other.hardwareConfig, hardwareConfig) || other.hardwareConfig == hardwareConfig)&&(identical(other.tracks, tracks) || other.tracks == tracks)&&(identical(other.generators, generators) || other.generators == generators)&&(identical(other.patterns, patterns) || other.patterns == patterns)&&(identical(other.mixer, mixer) || other.mixer == mixer)&&(identical(other.modulationLinks, modulationLinks) || other.modulationLinks == modulationLinks)&&(identical(other.automationPool, automationPool) || other.automationPool == automationPool)&&(identical(other.modulationSources, modulationSources) || other.modulationSources == modulationSources));
}


@override
int get hashCode => Object.hash(runtimeType,currentFilePath,metadata,transport,hardwareConfig,tracks,generators,patterns,mixer,modulationLinks,automationPool,modulationSources);

@override
String toString() {
  return 'ApplicationDataStore(currentFilePath: $currentFilePath, metadata: $metadata, transport: $transport, hardwareConfig: $hardwareConfig, tracks: $tracks, generators: $generators, patterns: $patterns, mixer: $mixer, modulationLinks: $modulationLinks, automationPool: $automationPool, modulationSources: $modulationSources)';
}


}

/// @nodoc
abstract mixin class _$ApplicationDataStoreCopyWith<$Res> implements $ApplicationDataStoreCopyWith<$Res> {
  factory _$ApplicationDataStoreCopyWith(_ApplicationDataStore value, $Res Function(_ApplicationDataStore) _then) = __$ApplicationDataStoreCopyWithImpl;
@override @useResult
$Res call({
 String? currentFilePath, UiProjectMetadata metadata, UiTransportState transport, UiAudioHardwareConfig hardwareConfig, IMap<int, UiTrack> tracks, IMap<int, UiGeneratorInstance> generators, IMap<int, UiPattern> patterns, mixer_api.UiMixerState mixer, IMap<int, ModulationLinkDto> modulationLinks, IMap<int, AutomationLaneDto> automationPool, IMap<int, ModulationSourceDto> modulationSources
});


@override $UiProjectMetadataCopyWith<$Res> get metadata;@override $UiTransportStateCopyWith<$Res> get transport;@override $UiAudioHardwareConfigCopyWith<$Res> get hardwareConfig;@override $UiMixerStateCopyWith<$Res> get mixer;

}
/// @nodoc
class __$ApplicationDataStoreCopyWithImpl<$Res>
    implements _$ApplicationDataStoreCopyWith<$Res> {
  __$ApplicationDataStoreCopyWithImpl(this._self, this._then);

  final _ApplicationDataStore _self;
  final $Res Function(_ApplicationDataStore) _then;

/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentFilePath = freezed,Object? metadata = null,Object? transport = null,Object? hardwareConfig = null,Object? tracks = null,Object? generators = null,Object? patterns = null,Object? mixer = null,Object? modulationLinks = null,Object? automationPool = null,Object? modulationSources = null,}) {
  return _then(_ApplicationDataStore(
currentFilePath: freezed == currentFilePath ? _self.currentFilePath : currentFilePath // ignore: cast_nullable_to_non_nullable
as String?,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as UiProjectMetadata,transport: null == transport ? _self.transport : transport // ignore: cast_nullable_to_non_nullable
as UiTransportState,hardwareConfig: null == hardwareConfig ? _self.hardwareConfig : hardwareConfig // ignore: cast_nullable_to_non_nullable
as UiAudioHardwareConfig,tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as IMap<int, UiTrack>,generators: null == generators ? _self.generators : generators // ignore: cast_nullable_to_non_nullable
as IMap<int, UiGeneratorInstance>,patterns: null == patterns ? _self.patterns : patterns // ignore: cast_nullable_to_non_nullable
as IMap<int, UiPattern>,mixer: null == mixer ? _self.mixer : mixer // ignore: cast_nullable_to_non_nullable
as mixer_api.UiMixerState,modulationLinks: null == modulationLinks ? _self.modulationLinks : modulationLinks // ignore: cast_nullable_to_non_nullable
as IMap<int, ModulationLinkDto>,automationPool: null == automationPool ? _self.automationPool : automationPool // ignore: cast_nullable_to_non_nullable
as IMap<int, AutomationLaneDto>,modulationSources: null == modulationSources ? _self.modulationSources : modulationSources // ignore: cast_nullable_to_non_nullable
as IMap<int, ModulationSourceDto>,
  ));
}

/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiProjectMetadataCopyWith<$Res> get metadata {
  
  return $UiProjectMetadataCopyWith<$Res>(_self.metadata, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiTransportStateCopyWith<$Res> get transport {
  
  return $UiTransportStateCopyWith<$Res>(_self.transport, (value) {
    return _then(_self.copyWith(transport: value));
  });
}/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiAudioHardwareConfigCopyWith<$Res> get hardwareConfig {
  
  return $UiAudioHardwareConfigCopyWith<$Res>(_self.hardwareConfig, (value) {
    return _then(_self.copyWith(hardwareConfig: value));
  });
}/// Create a copy of ApplicationDataStore
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiMixerStateCopyWith<$Res> get mixer {
  
  return $UiMixerStateCopyWith<$Res>(_self.mixer, (value) {
    return _then(_self.copyWith(mixer: value));
  });
}
}

// dart format on
