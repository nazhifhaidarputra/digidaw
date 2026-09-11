// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'external_plugins.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiExternalPluginCapabilities {

 bool get controller; bool get editor; bool get sidechain;
/// Create a copy of UiExternalPluginCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiExternalPluginCapabilitiesCopyWith<UiExternalPluginCapabilities> get copyWith => _$UiExternalPluginCapabilitiesCopyWithImpl<UiExternalPluginCapabilities>(this as UiExternalPluginCapabilities, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiExternalPluginCapabilities&&(identical(other.controller, controller) || other.controller == controller)&&(identical(other.editor, editor) || other.editor == editor)&&(identical(other.sidechain, sidechain) || other.sidechain == sidechain));
}


@override
int get hashCode => Object.hash(runtimeType,controller,editor,sidechain);

@override
String toString() {
  return 'UiExternalPluginCapabilities(controller: $controller, editor: $editor, sidechain: $sidechain)';
}


}

/// @nodoc
abstract mixin class $UiExternalPluginCapabilitiesCopyWith<$Res>  {
  factory $UiExternalPluginCapabilitiesCopyWith(UiExternalPluginCapabilities value, $Res Function(UiExternalPluginCapabilities) _then) = _$UiExternalPluginCapabilitiesCopyWithImpl;
@useResult
$Res call({
 bool controller, bool editor, bool sidechain
});




}
/// @nodoc
class _$UiExternalPluginCapabilitiesCopyWithImpl<$Res>
    implements $UiExternalPluginCapabilitiesCopyWith<$Res> {
  _$UiExternalPluginCapabilitiesCopyWithImpl(this._self, this._then);

  final UiExternalPluginCapabilities _self;
  final $Res Function(UiExternalPluginCapabilities) _then;

/// Create a copy of UiExternalPluginCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? controller = null,Object? editor = null,Object? sidechain = null,}) {
  return _then(_self.copyWith(
controller: null == controller ? _self.controller : controller // ignore: cast_nullable_to_non_nullable
as bool,editor: null == editor ? _self.editor : editor // ignore: cast_nullable_to_non_nullable
as bool,sidechain: null == sidechain ? _self.sidechain : sidechain // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UiExternalPluginCapabilities].
extension UiExternalPluginCapabilitiesPatterns on UiExternalPluginCapabilities {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiExternalPluginCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiExternalPluginCapabilities() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiExternalPluginCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _UiExternalPluginCapabilities():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiExternalPluginCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _UiExternalPluginCapabilities() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool controller,  bool editor,  bool sidechain)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiExternalPluginCapabilities() when $default != null:
return $default(_that.controller,_that.editor,_that.sidechain);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool controller,  bool editor,  bool sidechain)  $default,) {final _that = this;
switch (_that) {
case _UiExternalPluginCapabilities():
return $default(_that.controller,_that.editor,_that.sidechain);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool controller,  bool editor,  bool sidechain)?  $default,) {final _that = this;
switch (_that) {
case _UiExternalPluginCapabilities() when $default != null:
return $default(_that.controller,_that.editor,_that.sidechain);case _:
  return null;

}
}

}

/// @nodoc


class _UiExternalPluginCapabilities implements UiExternalPluginCapabilities {
  const _UiExternalPluginCapabilities({required this.controller, required this.editor, required this.sidechain});
  

@override final  bool controller;
@override final  bool editor;
@override final  bool sidechain;

/// Create a copy of UiExternalPluginCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiExternalPluginCapabilitiesCopyWith<_UiExternalPluginCapabilities> get copyWith => __$UiExternalPluginCapabilitiesCopyWithImpl<_UiExternalPluginCapabilities>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiExternalPluginCapabilities&&(identical(other.controller, controller) || other.controller == controller)&&(identical(other.editor, editor) || other.editor == editor)&&(identical(other.sidechain, sidechain) || other.sidechain == sidechain));
}


@override
int get hashCode => Object.hash(runtimeType,controller,editor,sidechain);

@override
String toString() {
  return 'UiExternalPluginCapabilities(controller: $controller, editor: $editor, sidechain: $sidechain)';
}


}

/// @nodoc
abstract mixin class _$UiExternalPluginCapabilitiesCopyWith<$Res> implements $UiExternalPluginCapabilitiesCopyWith<$Res> {
  factory _$UiExternalPluginCapabilitiesCopyWith(_UiExternalPluginCapabilities value, $Res Function(_UiExternalPluginCapabilities) _then) = __$UiExternalPluginCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 bool controller, bool editor, bool sidechain
});




}
/// @nodoc
class __$UiExternalPluginCapabilitiesCopyWithImpl<$Res>
    implements _$UiExternalPluginCapabilitiesCopyWith<$Res> {
  __$UiExternalPluginCapabilitiesCopyWithImpl(this._self, this._then);

  final _UiExternalPluginCapabilities _self;
  final $Res Function(_UiExternalPluginCapabilities) _then;

/// Create a copy of UiExternalPluginCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? controller = null,Object? editor = null,Object? sidechain = null,}) {
  return _then(_UiExternalPluginCapabilities(
controller: null == controller ? _self.controller : controller // ignore: cast_nullable_to_non_nullable
as bool,editor: null == editor ? _self.editor : editor // ignore: cast_nullable_to_non_nullable
as bool,sidechain: null == sidechain ? _self.sidechain : sidechain // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$UiExternalPluginDescriptor {

 String get format; String get nativeId; String get path; String get name; String get vendor; String get version; bool get instrument;
/// Create a copy of UiExternalPluginDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiExternalPluginDescriptorCopyWith<UiExternalPluginDescriptor> get copyWith => _$UiExternalPluginDescriptorCopyWithImpl<UiExternalPluginDescriptor>(this as UiExternalPluginDescriptor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiExternalPluginDescriptor&&(identical(other.format, format) || other.format == format)&&(identical(other.nativeId, nativeId) || other.nativeId == nativeId)&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.version, version) || other.version == version)&&(identical(other.instrument, instrument) || other.instrument == instrument));
}


@override
int get hashCode => Object.hash(runtimeType,format,nativeId,path,name,vendor,version,instrument);

@override
String toString() {
  return 'UiExternalPluginDescriptor(format: $format, nativeId: $nativeId, path: $path, name: $name, vendor: $vendor, version: $version, instrument: $instrument)';
}


}

/// @nodoc
abstract mixin class $UiExternalPluginDescriptorCopyWith<$Res>  {
  factory $UiExternalPluginDescriptorCopyWith(UiExternalPluginDescriptor value, $Res Function(UiExternalPluginDescriptor) _then) = _$UiExternalPluginDescriptorCopyWithImpl;
@useResult
$Res call({
 String format, String nativeId, String path, String name, String vendor, String version, bool instrument
});




}
/// @nodoc
class _$UiExternalPluginDescriptorCopyWithImpl<$Res>
    implements $UiExternalPluginDescriptorCopyWith<$Res> {
  _$UiExternalPluginDescriptorCopyWithImpl(this._self, this._then);

  final UiExternalPluginDescriptor _self;
  final $Res Function(UiExternalPluginDescriptor) _then;

/// Create a copy of UiExternalPluginDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? format = null,Object? nativeId = null,Object? path = null,Object? name = null,Object? vendor = null,Object? version = null,Object? instrument = null,}) {
  return _then(_self.copyWith(
format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,nativeId: null == nativeId ? _self.nativeId : nativeId // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,instrument: null == instrument ? _self.instrument : instrument // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UiExternalPluginDescriptor].
extension UiExternalPluginDescriptorPatterns on UiExternalPluginDescriptor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiExternalPluginDescriptor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiExternalPluginDescriptor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiExternalPluginDescriptor value)  $default,){
final _that = this;
switch (_that) {
case _UiExternalPluginDescriptor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiExternalPluginDescriptor value)?  $default,){
final _that = this;
switch (_that) {
case _UiExternalPluginDescriptor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String format,  String nativeId,  String path,  String name,  String vendor,  String version,  bool instrument)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiExternalPluginDescriptor() when $default != null:
return $default(_that.format,_that.nativeId,_that.path,_that.name,_that.vendor,_that.version,_that.instrument);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String format,  String nativeId,  String path,  String name,  String vendor,  String version,  bool instrument)  $default,) {final _that = this;
switch (_that) {
case _UiExternalPluginDescriptor():
return $default(_that.format,_that.nativeId,_that.path,_that.name,_that.vendor,_that.version,_that.instrument);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String format,  String nativeId,  String path,  String name,  String vendor,  String version,  bool instrument)?  $default,) {final _that = this;
switch (_that) {
case _UiExternalPluginDescriptor() when $default != null:
return $default(_that.format,_that.nativeId,_that.path,_that.name,_that.vendor,_that.version,_that.instrument);case _:
  return null;

}
}

}

/// @nodoc


class _UiExternalPluginDescriptor implements UiExternalPluginDescriptor {
  const _UiExternalPluginDescriptor({required this.format, required this.nativeId, required this.path, required this.name, required this.vendor, required this.version, required this.instrument});
  

@override final  String format;
@override final  String nativeId;
@override final  String path;
@override final  String name;
@override final  String vendor;
@override final  String version;
@override final  bool instrument;

/// Create a copy of UiExternalPluginDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiExternalPluginDescriptorCopyWith<_UiExternalPluginDescriptor> get copyWith => __$UiExternalPluginDescriptorCopyWithImpl<_UiExternalPluginDescriptor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiExternalPluginDescriptor&&(identical(other.format, format) || other.format == format)&&(identical(other.nativeId, nativeId) || other.nativeId == nativeId)&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.vendor, vendor) || other.vendor == vendor)&&(identical(other.version, version) || other.version == version)&&(identical(other.instrument, instrument) || other.instrument == instrument));
}


@override
int get hashCode => Object.hash(runtimeType,format,nativeId,path,name,vendor,version,instrument);

@override
String toString() {
  return 'UiExternalPluginDescriptor(format: $format, nativeId: $nativeId, path: $path, name: $name, vendor: $vendor, version: $version, instrument: $instrument)';
}


}

/// @nodoc
abstract mixin class _$UiExternalPluginDescriptorCopyWith<$Res> implements $UiExternalPluginDescriptorCopyWith<$Res> {
  factory _$UiExternalPluginDescriptorCopyWith(_UiExternalPluginDescriptor value, $Res Function(_UiExternalPluginDescriptor) _then) = __$UiExternalPluginDescriptorCopyWithImpl;
@override @useResult
$Res call({
 String format, String nativeId, String path, String name, String vendor, String version, bool instrument
});




}
/// @nodoc
class __$UiExternalPluginDescriptorCopyWithImpl<$Res>
    implements _$UiExternalPluginDescriptorCopyWith<$Res> {
  __$UiExternalPluginDescriptorCopyWithImpl(this._self, this._then);

  final _UiExternalPluginDescriptor _self;
  final $Res Function(_UiExternalPluginDescriptor) _then;

/// Create a copy of UiExternalPluginDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? format = null,Object? nativeId = null,Object? path = null,Object? name = null,Object? vendor = null,Object? version = null,Object? instrument = null,}) {
  return _then(_UiExternalPluginDescriptor(
format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,nativeId: null == nativeId ? _self.nativeId : nativeId // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,vendor: null == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,instrument: null == instrument ? _self.instrument : instrument // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$UiExternalPluginEntry {

 int get id; bool get available; UiExternalPluginDescriptor get descriptor;
/// Create a copy of UiExternalPluginEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiExternalPluginEntryCopyWith<UiExternalPluginEntry> get copyWith => _$UiExternalPluginEntryCopyWithImpl<UiExternalPluginEntry>(this as UiExternalPluginEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiExternalPluginEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.available, available) || other.available == available)&&(identical(other.descriptor, descriptor) || other.descriptor == descriptor));
}


@override
int get hashCode => Object.hash(runtimeType,id,available,descriptor);

@override
String toString() {
  return 'UiExternalPluginEntry(id: $id, available: $available, descriptor: $descriptor)';
}


}

/// @nodoc
abstract mixin class $UiExternalPluginEntryCopyWith<$Res>  {
  factory $UiExternalPluginEntryCopyWith(UiExternalPluginEntry value, $Res Function(UiExternalPluginEntry) _then) = _$UiExternalPluginEntryCopyWithImpl;
@useResult
$Res call({
 int id, bool available, UiExternalPluginDescriptor descriptor
});


$UiExternalPluginDescriptorCopyWith<$Res> get descriptor;

}
/// @nodoc
class _$UiExternalPluginEntryCopyWithImpl<$Res>
    implements $UiExternalPluginEntryCopyWith<$Res> {
  _$UiExternalPluginEntryCopyWithImpl(this._self, this._then);

  final UiExternalPluginEntry _self;
  final $Res Function(UiExternalPluginEntry) _then;

/// Create a copy of UiExternalPluginEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? available = null,Object? descriptor = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,descriptor: null == descriptor ? _self.descriptor : descriptor // ignore: cast_nullable_to_non_nullable
as UiExternalPluginDescriptor,
  ));
}
/// Create a copy of UiExternalPluginEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiExternalPluginDescriptorCopyWith<$Res> get descriptor {
  
  return $UiExternalPluginDescriptorCopyWith<$Res>(_self.descriptor, (value) {
    return _then(_self.copyWith(descriptor: value));
  });
}
}


/// Adds pattern-matching-related methods to [UiExternalPluginEntry].
extension UiExternalPluginEntryPatterns on UiExternalPluginEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiExternalPluginEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiExternalPluginEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiExternalPluginEntry value)  $default,){
final _that = this;
switch (_that) {
case _UiExternalPluginEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiExternalPluginEntry value)?  $default,){
final _that = this;
switch (_that) {
case _UiExternalPluginEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  bool available,  UiExternalPluginDescriptor descriptor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiExternalPluginEntry() when $default != null:
return $default(_that.id,_that.available,_that.descriptor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  bool available,  UiExternalPluginDescriptor descriptor)  $default,) {final _that = this;
switch (_that) {
case _UiExternalPluginEntry():
return $default(_that.id,_that.available,_that.descriptor);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  bool available,  UiExternalPluginDescriptor descriptor)?  $default,) {final _that = this;
switch (_that) {
case _UiExternalPluginEntry() when $default != null:
return $default(_that.id,_that.available,_that.descriptor);case _:
  return null;

}
}

}

/// @nodoc


class _UiExternalPluginEntry implements UiExternalPluginEntry {
  const _UiExternalPluginEntry({required this.id, required this.available, required this.descriptor});
  

@override final  int id;
@override final  bool available;
@override final  UiExternalPluginDescriptor descriptor;

/// Create a copy of UiExternalPluginEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiExternalPluginEntryCopyWith<_UiExternalPluginEntry> get copyWith => __$UiExternalPluginEntryCopyWithImpl<_UiExternalPluginEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiExternalPluginEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.available, available) || other.available == available)&&(identical(other.descriptor, descriptor) || other.descriptor == descriptor));
}


@override
int get hashCode => Object.hash(runtimeType,id,available,descriptor);

@override
String toString() {
  return 'UiExternalPluginEntry(id: $id, available: $available, descriptor: $descriptor)';
}


}

/// @nodoc
abstract mixin class _$UiExternalPluginEntryCopyWith<$Res> implements $UiExternalPluginEntryCopyWith<$Res> {
  factory _$UiExternalPluginEntryCopyWith(_UiExternalPluginEntry value, $Res Function(_UiExternalPluginEntry) _then) = __$UiExternalPluginEntryCopyWithImpl;
@override @useResult
$Res call({
 int id, bool available, UiExternalPluginDescriptor descriptor
});


@override $UiExternalPluginDescriptorCopyWith<$Res> get descriptor;

}
/// @nodoc
class __$UiExternalPluginEntryCopyWithImpl<$Res>
    implements _$UiExternalPluginEntryCopyWith<$Res> {
  __$UiExternalPluginEntryCopyWithImpl(this._self, this._then);

  final _UiExternalPluginEntry _self;
  final $Res Function(_UiExternalPluginEntry) _then;

/// Create a copy of UiExternalPluginEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? available = null,Object? descriptor = null,}) {
  return _then(_UiExternalPluginEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,descriptor: null == descriptor ? _self.descriptor : descriptor // ignore: cast_nullable_to_non_nullable
as UiExternalPluginDescriptor,
  ));
}

/// Create a copy of UiExternalPluginEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiExternalPluginDescriptorCopyWith<$Res> get descriptor {
  
  return $UiExternalPluginDescriptorCopyWith<$Res>(_self.descriptor, (value) {
    return _then(_self.copyWith(descriptor: value));
  });
}
}

/// @nodoc
mixin _$UiPluginScanEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginScanEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiPluginScanEvent()';
}


}

/// @nodoc
class $UiPluginScanEventCopyWith<$Res>  {
$UiPluginScanEventCopyWith(UiPluginScanEvent _, $Res Function(UiPluginScanEvent) __);
}


/// Adds pattern-matching-related methods to [UiPluginScanEvent].
extension UiPluginScanEventPatterns on UiPluginScanEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiPluginScanEvent_Started value)?  started,TResult Function( UiPluginScanEvent_Progress value)?  progress,TResult Function( UiPluginScanEvent_Finished value)?  finished,TResult Function( UiPluginScanEvent_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiPluginScanEvent_Started() when started != null:
return started(_that);case UiPluginScanEvent_Progress() when progress != null:
return progress(_that);case UiPluginScanEvent_Finished() when finished != null:
return finished(_that);case UiPluginScanEvent_Failed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiPluginScanEvent_Started value)  started,required TResult Function( UiPluginScanEvent_Progress value)  progress,required TResult Function( UiPluginScanEvent_Finished value)  finished,required TResult Function( UiPluginScanEvent_Failed value)  failed,}){
final _that = this;
switch (_that) {
case UiPluginScanEvent_Started():
return started(_that);case UiPluginScanEvent_Progress():
return progress(_that);case UiPluginScanEvent_Finished():
return finished(_that);case UiPluginScanEvent_Failed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiPluginScanEvent_Started value)?  started,TResult? Function( UiPluginScanEvent_Progress value)?  progress,TResult? Function( UiPluginScanEvent_Finished value)?  finished,TResult? Function( UiPluginScanEvent_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case UiPluginScanEvent_Started() when started != null:
return started(_that);case UiPluginScanEvent_Progress() when progress != null:
return progress(_that);case UiPluginScanEvent_Finished() when finished != null:
return finished(_that);case UiPluginScanEvent_Failed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int id)?  started,TResult Function( int completed,  int total,  String path,  String? error)?  progress,TResult Function( List<UiExternalPluginDescriptor> plugins,  List<UiPluginScanFailure> failures,  bool cancelled)?  finished,TResult Function( String message)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiPluginScanEvent_Started() when started != null:
return started(_that.id);case UiPluginScanEvent_Progress() when progress != null:
return progress(_that.completed,_that.total,_that.path,_that.error);case UiPluginScanEvent_Finished() when finished != null:
return finished(_that.plugins,_that.failures,_that.cancelled);case UiPluginScanEvent_Failed() when failed != null:
return failed(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int id)  started,required TResult Function( int completed,  int total,  String path,  String? error)  progress,required TResult Function( List<UiExternalPluginDescriptor> plugins,  List<UiPluginScanFailure> failures,  bool cancelled)  finished,required TResult Function( String message)  failed,}) {final _that = this;
switch (_that) {
case UiPluginScanEvent_Started():
return started(_that.id);case UiPluginScanEvent_Progress():
return progress(_that.completed,_that.total,_that.path,_that.error);case UiPluginScanEvent_Finished():
return finished(_that.plugins,_that.failures,_that.cancelled);case UiPluginScanEvent_Failed():
return failed(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int id)?  started,TResult? Function( int completed,  int total,  String path,  String? error)?  progress,TResult? Function( List<UiExternalPluginDescriptor> plugins,  List<UiPluginScanFailure> failures,  bool cancelled)?  finished,TResult? Function( String message)?  failed,}) {final _that = this;
switch (_that) {
case UiPluginScanEvent_Started() when started != null:
return started(_that.id);case UiPluginScanEvent_Progress() when progress != null:
return progress(_that.completed,_that.total,_that.path,_that.error);case UiPluginScanEvent_Finished() when finished != null:
return finished(_that.plugins,_that.failures,_that.cancelled);case UiPluginScanEvent_Failed() when failed != null:
return failed(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class UiPluginScanEvent_Started extends UiPluginScanEvent {
  const UiPluginScanEvent_Started({required this.id}): super._();
  

 final  int id;

/// Create a copy of UiPluginScanEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginScanEvent_StartedCopyWith<UiPluginScanEvent_Started> get copyWith => _$UiPluginScanEvent_StartedCopyWithImpl<UiPluginScanEvent_Started>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginScanEvent_Started&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'UiPluginScanEvent.started(id: $id)';
}


}

/// @nodoc
abstract mixin class $UiPluginScanEvent_StartedCopyWith<$Res> implements $UiPluginScanEventCopyWith<$Res> {
  factory $UiPluginScanEvent_StartedCopyWith(UiPluginScanEvent_Started value, $Res Function(UiPluginScanEvent_Started) _then) = _$UiPluginScanEvent_StartedCopyWithImpl;
@useResult
$Res call({
 int id
});




}
/// @nodoc
class _$UiPluginScanEvent_StartedCopyWithImpl<$Res>
    implements $UiPluginScanEvent_StartedCopyWith<$Res> {
  _$UiPluginScanEvent_StartedCopyWithImpl(this._self, this._then);

  final UiPluginScanEvent_Started _self;
  final $Res Function(UiPluginScanEvent_Started) _then;

/// Create a copy of UiPluginScanEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(UiPluginScanEvent_Started(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class UiPluginScanEvent_Progress extends UiPluginScanEvent {
  const UiPluginScanEvent_Progress({required this.completed, required this.total, required this.path, this.error}): super._();
  

 final  int completed;
 final  int total;
 final  String path;
 final  String? error;

/// Create a copy of UiPluginScanEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginScanEvent_ProgressCopyWith<UiPluginScanEvent_Progress> get copyWith => _$UiPluginScanEvent_ProgressCopyWithImpl<UiPluginScanEvent_Progress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginScanEvent_Progress&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.total, total) || other.total == total)&&(identical(other.path, path) || other.path == path)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,completed,total,path,error);

@override
String toString() {
  return 'UiPluginScanEvent.progress(completed: $completed, total: $total, path: $path, error: $error)';
}


}

/// @nodoc
abstract mixin class $UiPluginScanEvent_ProgressCopyWith<$Res> implements $UiPluginScanEventCopyWith<$Res> {
  factory $UiPluginScanEvent_ProgressCopyWith(UiPluginScanEvent_Progress value, $Res Function(UiPluginScanEvent_Progress) _then) = _$UiPluginScanEvent_ProgressCopyWithImpl;
@useResult
$Res call({
 int completed, int total, String path, String? error
});




}
/// @nodoc
class _$UiPluginScanEvent_ProgressCopyWithImpl<$Res>
    implements $UiPluginScanEvent_ProgressCopyWith<$Res> {
  _$UiPluginScanEvent_ProgressCopyWithImpl(this._self, this._then);

  final UiPluginScanEvent_Progress _self;
  final $Res Function(UiPluginScanEvent_Progress) _then;

/// Create a copy of UiPluginScanEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? completed = null,Object? total = null,Object? path = null,Object? error = freezed,}) {
  return _then(UiPluginScanEvent_Progress(
completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class UiPluginScanEvent_Finished extends UiPluginScanEvent {
  const UiPluginScanEvent_Finished({required final  List<UiExternalPluginDescriptor> plugins, required final  List<UiPluginScanFailure> failures, required this.cancelled}): _plugins = plugins,_failures = failures,super._();
  

 final  List<UiExternalPluginDescriptor> _plugins;
 List<UiExternalPluginDescriptor> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}

 final  List<UiPluginScanFailure> _failures;
 List<UiPluginScanFailure> get failures {
  if (_failures is EqualUnmodifiableListView) return _failures;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_failures);
}

 final  bool cancelled;

/// Create a copy of UiPluginScanEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginScanEvent_FinishedCopyWith<UiPluginScanEvent_Finished> get copyWith => _$UiPluginScanEvent_FinishedCopyWithImpl<UiPluginScanEvent_Finished>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginScanEvent_Finished&&const DeepCollectionEquality().equals(other._plugins, _plugins)&&const DeepCollectionEquality().equals(other._failures, _failures)&&(identical(other.cancelled, cancelled) || other.cancelled == cancelled));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_plugins),const DeepCollectionEquality().hash(_failures),cancelled);

@override
String toString() {
  return 'UiPluginScanEvent.finished(plugins: $plugins, failures: $failures, cancelled: $cancelled)';
}


}

/// @nodoc
abstract mixin class $UiPluginScanEvent_FinishedCopyWith<$Res> implements $UiPluginScanEventCopyWith<$Res> {
  factory $UiPluginScanEvent_FinishedCopyWith(UiPluginScanEvent_Finished value, $Res Function(UiPluginScanEvent_Finished) _then) = _$UiPluginScanEvent_FinishedCopyWithImpl;
@useResult
$Res call({
 List<UiExternalPluginDescriptor> plugins, List<UiPluginScanFailure> failures, bool cancelled
});




}
/// @nodoc
class _$UiPluginScanEvent_FinishedCopyWithImpl<$Res>
    implements $UiPluginScanEvent_FinishedCopyWith<$Res> {
  _$UiPluginScanEvent_FinishedCopyWithImpl(this._self, this._then);

  final UiPluginScanEvent_Finished _self;
  final $Res Function(UiPluginScanEvent_Finished) _then;

/// Create a copy of UiPluginScanEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? plugins = null,Object? failures = null,Object? cancelled = null,}) {
  return _then(UiPluginScanEvent_Finished(
plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<UiExternalPluginDescriptor>,failures: null == failures ? _self._failures : failures // ignore: cast_nullable_to_non_nullable
as List<UiPluginScanFailure>,cancelled: null == cancelled ? _self.cancelled : cancelled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class UiPluginScanEvent_Failed extends UiPluginScanEvent {
  const UiPluginScanEvent_Failed({required this.message}): super._();
  

 final  String message;

/// Create a copy of UiPluginScanEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginScanEvent_FailedCopyWith<UiPluginScanEvent_Failed> get copyWith => _$UiPluginScanEvent_FailedCopyWithImpl<UiPluginScanEvent_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginScanEvent_Failed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'UiPluginScanEvent.failed(message: $message)';
}


}

/// @nodoc
abstract mixin class $UiPluginScanEvent_FailedCopyWith<$Res> implements $UiPluginScanEventCopyWith<$Res> {
  factory $UiPluginScanEvent_FailedCopyWith(UiPluginScanEvent_Failed value, $Res Function(UiPluginScanEvent_Failed) _then) = _$UiPluginScanEvent_FailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$UiPluginScanEvent_FailedCopyWithImpl<$Res>
    implements $UiPluginScanEvent_FailedCopyWith<$Res> {
  _$UiPluginScanEvent_FailedCopyWithImpl(this._self, this._then);

  final UiPluginScanEvent_Failed _self;
  final $Res Function(UiPluginScanEvent_Failed) _then;

/// Create a copy of UiPluginScanEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(UiPluginScanEvent_Failed(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiPluginScanFailure {

 String get path; String get reason;
/// Create a copy of UiPluginScanFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginScanFailureCopyWith<UiPluginScanFailure> get copyWith => _$UiPluginScanFailureCopyWithImpl<UiPluginScanFailure>(this as UiPluginScanFailure, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginScanFailure&&(identical(other.path, path) || other.path == path)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,path,reason);

@override
String toString() {
  return 'UiPluginScanFailure(path: $path, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $UiPluginScanFailureCopyWith<$Res>  {
  factory $UiPluginScanFailureCopyWith(UiPluginScanFailure value, $Res Function(UiPluginScanFailure) _then) = _$UiPluginScanFailureCopyWithImpl;
@useResult
$Res call({
 String path, String reason
});




}
/// @nodoc
class _$UiPluginScanFailureCopyWithImpl<$Res>
    implements $UiPluginScanFailureCopyWith<$Res> {
  _$UiPluginScanFailureCopyWithImpl(this._self, this._then);

  final UiPluginScanFailure _self;
  final $Res Function(UiPluginScanFailure) _then;

/// Create a copy of UiPluginScanFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? reason = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiPluginScanFailure].
extension UiPluginScanFailurePatterns on UiPluginScanFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiPluginScanFailure value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiPluginScanFailure() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiPluginScanFailure value)  $default,){
final _that = this;
switch (_that) {
case _UiPluginScanFailure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiPluginScanFailure value)?  $default,){
final _that = this;
switch (_that) {
case _UiPluginScanFailure() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiPluginScanFailure() when $default != null:
return $default(_that.path,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String reason)  $default,) {final _that = this;
switch (_that) {
case _UiPluginScanFailure():
return $default(_that.path,_that.reason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String reason)?  $default,) {final _that = this;
switch (_that) {
case _UiPluginScanFailure() when $default != null:
return $default(_that.path,_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class _UiPluginScanFailure implements UiPluginScanFailure {
  const _UiPluginScanFailure({required this.path, required this.reason});
  

@override final  String path;
@override final  String reason;

/// Create a copy of UiPluginScanFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiPluginScanFailureCopyWith<_UiPluginScanFailure> get copyWith => __$UiPluginScanFailureCopyWithImpl<_UiPluginScanFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiPluginScanFailure&&(identical(other.path, path) || other.path == path)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,path,reason);

@override
String toString() {
  return 'UiPluginScanFailure(path: $path, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$UiPluginScanFailureCopyWith<$Res> implements $UiPluginScanFailureCopyWith<$Res> {
  factory _$UiPluginScanFailureCopyWith(_UiPluginScanFailure value, $Res Function(_UiPluginScanFailure) _then) = __$UiPluginScanFailureCopyWithImpl;
@override @useResult
$Res call({
 String path, String reason
});




}
/// @nodoc
class __$UiPluginScanFailureCopyWithImpl<$Res>
    implements _$UiPluginScanFailureCopyWith<$Res> {
  __$UiPluginScanFailureCopyWithImpl(this._self, this._then);

  final _UiPluginScanFailure _self;
  final $Res Function(_UiPluginScanFailure) _then;

/// Create a copy of UiPluginScanFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? reason = null,}) {
  return _then(_UiPluginScanFailure(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiPluginScanSettings {

 List<String> get directories; int get timeoutSeconds;
/// Create a copy of UiPluginScanSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiPluginScanSettingsCopyWith<UiPluginScanSettings> get copyWith => _$UiPluginScanSettingsCopyWithImpl<UiPluginScanSettings>(this as UiPluginScanSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiPluginScanSettings&&const DeepCollectionEquality().equals(other.directories, directories)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(directories),timeoutSeconds);

@override
String toString() {
  return 'UiPluginScanSettings(directories: $directories, timeoutSeconds: $timeoutSeconds)';
}


}

/// @nodoc
abstract mixin class $UiPluginScanSettingsCopyWith<$Res>  {
  factory $UiPluginScanSettingsCopyWith(UiPluginScanSettings value, $Res Function(UiPluginScanSettings) _then) = _$UiPluginScanSettingsCopyWithImpl;
@useResult
$Res call({
 List<String> directories, int timeoutSeconds
});




}
/// @nodoc
class _$UiPluginScanSettingsCopyWithImpl<$Res>
    implements $UiPluginScanSettingsCopyWith<$Res> {
  _$UiPluginScanSettingsCopyWithImpl(this._self, this._then);

  final UiPluginScanSettings _self;
  final $Res Function(UiPluginScanSettings) _then;

/// Create a copy of UiPluginScanSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? directories = null,Object? timeoutSeconds = null,}) {
  return _then(_self.copyWith(
directories: null == directories ? _self.directories : directories // ignore: cast_nullable_to_non_nullable
as List<String>,timeoutSeconds: null == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UiPluginScanSettings].
extension UiPluginScanSettingsPatterns on UiPluginScanSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiPluginScanSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiPluginScanSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiPluginScanSettings value)  $default,){
final _that = this;
switch (_that) {
case _UiPluginScanSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiPluginScanSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UiPluginScanSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> directories,  int timeoutSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiPluginScanSettings() when $default != null:
return $default(_that.directories,_that.timeoutSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> directories,  int timeoutSeconds)  $default,) {final _that = this;
switch (_that) {
case _UiPluginScanSettings():
return $default(_that.directories,_that.timeoutSeconds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> directories,  int timeoutSeconds)?  $default,) {final _that = this;
switch (_that) {
case _UiPluginScanSettings() when $default != null:
return $default(_that.directories,_that.timeoutSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _UiPluginScanSettings implements UiPluginScanSettings {
  const _UiPluginScanSettings({required final  List<String> directories, required this.timeoutSeconds}): _directories = directories;
  

 final  List<String> _directories;
@override List<String> get directories {
  if (_directories is EqualUnmodifiableListView) return _directories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_directories);
}

@override final  int timeoutSeconds;

/// Create a copy of UiPluginScanSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiPluginScanSettingsCopyWith<_UiPluginScanSettings> get copyWith => __$UiPluginScanSettingsCopyWithImpl<_UiPluginScanSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiPluginScanSettings&&const DeepCollectionEquality().equals(other._directories, _directories)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_directories),timeoutSeconds);

@override
String toString() {
  return 'UiPluginScanSettings(directories: $directories, timeoutSeconds: $timeoutSeconds)';
}


}

/// @nodoc
abstract mixin class _$UiPluginScanSettingsCopyWith<$Res> implements $UiPluginScanSettingsCopyWith<$Res> {
  factory _$UiPluginScanSettingsCopyWith(_UiPluginScanSettings value, $Res Function(_UiPluginScanSettings) _then) = __$UiPluginScanSettingsCopyWithImpl;
@override @useResult
$Res call({
 List<String> directories, int timeoutSeconds
});




}
/// @nodoc
class __$UiPluginScanSettingsCopyWithImpl<$Res>
    implements _$UiPluginScanSettingsCopyWith<$Res> {
  __$UiPluginScanSettingsCopyWithImpl(this._self, this._then);

  final _UiPluginScanSettings _self;
  final $Res Function(_UiPluginScanSettings) _then;

/// Create a copy of UiPluginScanSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? directories = null,Object? timeoutSeconds = null,}) {
  return _then(_UiPluginScanSettings(
directories: null == directories ? _self._directories : directories // ignore: cast_nullable_to_non_nullable
as List<String>,timeoutSeconds: null == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
