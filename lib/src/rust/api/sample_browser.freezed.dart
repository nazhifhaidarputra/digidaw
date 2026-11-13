// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sample_browser.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UiSampleFile {

 String get name; String get path;
/// Create a copy of UiSampleFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiSampleFileCopyWith<UiSampleFile> get copyWith => _$UiSampleFileCopyWithImpl<UiSampleFile>(this as UiSampleFile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiSampleFile&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,name,path);

@override
String toString() {
  return 'UiSampleFile(name: $name, path: $path)';
}


}

/// @nodoc
abstract mixin class $UiSampleFileCopyWith<$Res>  {
  factory $UiSampleFileCopyWith(UiSampleFile value, $Res Function(UiSampleFile) _then) = _$UiSampleFileCopyWithImpl;
@useResult
$Res call({
 String name, String path
});




}
/// @nodoc
class _$UiSampleFileCopyWithImpl<$Res>
    implements $UiSampleFileCopyWith<$Res> {
  _$UiSampleFileCopyWithImpl(this._self, this._then);

  final UiSampleFile _self;
  final $Res Function(UiSampleFile) _then;

/// Create a copy of UiSampleFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? path = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UiSampleFile].
extension UiSampleFilePatterns on UiSampleFile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiSampleFile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiSampleFile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiSampleFile value)  $default,){
final _that = this;
switch (_that) {
case _UiSampleFile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiSampleFile value)?  $default,){
final _that = this;
switch (_that) {
case _UiSampleFile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiSampleFile() when $default != null:
return $default(_that.name,_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String path)  $default,) {final _that = this;
switch (_that) {
case _UiSampleFile():
return $default(_that.name,_that.path);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String path)?  $default,) {final _that = this;
switch (_that) {
case _UiSampleFile() when $default != null:
return $default(_that.name,_that.path);case _:
  return null;

}
}

}

/// @nodoc


class _UiSampleFile implements UiSampleFile {
  const _UiSampleFile({required this.name, required this.path});
  

@override final  String name;
@override final  String path;

/// Create a copy of UiSampleFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiSampleFileCopyWith<_UiSampleFile> get copyWith => __$UiSampleFileCopyWithImpl<_UiSampleFile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiSampleFile&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,name,path);

@override
String toString() {
  return 'UiSampleFile(name: $name, path: $path)';
}


}

/// @nodoc
abstract mixin class _$UiSampleFileCopyWith<$Res> implements $UiSampleFileCopyWith<$Res> {
  factory _$UiSampleFileCopyWith(_UiSampleFile value, $Res Function(_UiSampleFile) _then) = __$UiSampleFileCopyWithImpl;
@override @useResult
$Res call({
 String name, String path
});




}
/// @nodoc
class __$UiSampleFileCopyWithImpl<$Res>
    implements _$UiSampleFileCopyWith<$Res> {
  __$UiSampleFileCopyWithImpl(this._self, this._then);

  final _UiSampleFile _self;
  final $Res Function(_UiSampleFile) _then;

/// Create a copy of UiSampleFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = null,}) {
  return _then(_UiSampleFile(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiSampleFolderEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiSampleFolderEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiSampleFolderEvent()';
}


}

/// @nodoc
class $UiSampleFolderEventCopyWith<$Res>  {
$UiSampleFolderEventCopyWith(UiSampleFolderEvent _, $Res Function(UiSampleFolderEvent) __);
}


/// Adds pattern-matching-related methods to [UiSampleFolderEvent].
extension UiSampleFolderEventPatterns on UiSampleFolderEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiSampleFolderEvent_Scanned value)?  scanned,TResult Function( UiSampleFolderEvent_Unavailable value)?  unavailable,TResult Function( UiSampleFolderEvent_Restored value)?  restored,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiSampleFolderEvent_Scanned() when scanned != null:
return scanned(_that);case UiSampleFolderEvent_Unavailable() when unavailable != null:
return unavailable(_that);case UiSampleFolderEvent_Restored() when restored != null:
return restored(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiSampleFolderEvent_Scanned value)  scanned,required TResult Function( UiSampleFolderEvent_Unavailable value)  unavailable,required TResult Function( UiSampleFolderEvent_Restored value)  restored,}){
final _that = this;
switch (_that) {
case UiSampleFolderEvent_Scanned():
return scanned(_that);case UiSampleFolderEvent_Unavailable():
return unavailable(_that);case UiSampleFolderEvent_Restored():
return restored(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiSampleFolderEvent_Scanned value)?  scanned,TResult? Function( UiSampleFolderEvent_Unavailable value)?  unavailable,TResult? Function( UiSampleFolderEvent_Restored value)?  restored,}){
final _that = this;
switch (_that) {
case UiSampleFolderEvent_Scanned() when scanned != null:
return scanned(_that);case UiSampleFolderEvent_Unavailable() when unavailable != null:
return unavailable(_that);case UiSampleFolderEvent_Restored() when restored != null:
return restored(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( UiSampleTree tree)?  scanned,TResult Function( String path)?  unavailable,TResult Function()?  restored,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiSampleFolderEvent_Scanned() when scanned != null:
return scanned(_that.tree);case UiSampleFolderEvent_Unavailable() when unavailable != null:
return unavailable(_that.path);case UiSampleFolderEvent_Restored() when restored != null:
return restored();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( UiSampleTree tree)  scanned,required TResult Function( String path)  unavailable,required TResult Function()  restored,}) {final _that = this;
switch (_that) {
case UiSampleFolderEvent_Scanned():
return scanned(_that.tree);case UiSampleFolderEvent_Unavailable():
return unavailable(_that.path);case UiSampleFolderEvent_Restored():
return restored();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( UiSampleTree tree)?  scanned,TResult? Function( String path)?  unavailable,TResult? Function()?  restored,}) {final _that = this;
switch (_that) {
case UiSampleFolderEvent_Scanned() when scanned != null:
return scanned(_that.tree);case UiSampleFolderEvent_Unavailable() when unavailable != null:
return unavailable(_that.path);case UiSampleFolderEvent_Restored() when restored != null:
return restored();case _:
  return null;

}
}

}

/// @nodoc


class UiSampleFolderEvent_Scanned extends UiSampleFolderEvent {
  const UiSampleFolderEvent_Scanned({required this.tree}): super._();
  

 final  UiSampleTree tree;

/// Create a copy of UiSampleFolderEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiSampleFolderEvent_ScannedCopyWith<UiSampleFolderEvent_Scanned> get copyWith => _$UiSampleFolderEvent_ScannedCopyWithImpl<UiSampleFolderEvent_Scanned>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiSampleFolderEvent_Scanned&&(identical(other.tree, tree) || other.tree == tree));
}


@override
int get hashCode => Object.hash(runtimeType,tree);

@override
String toString() {
  return 'UiSampleFolderEvent.scanned(tree: $tree)';
}


}

/// @nodoc
abstract mixin class $UiSampleFolderEvent_ScannedCopyWith<$Res> implements $UiSampleFolderEventCopyWith<$Res> {
  factory $UiSampleFolderEvent_ScannedCopyWith(UiSampleFolderEvent_Scanned value, $Res Function(UiSampleFolderEvent_Scanned) _then) = _$UiSampleFolderEvent_ScannedCopyWithImpl;
@useResult
$Res call({
 UiSampleTree tree
});


$UiSampleTreeCopyWith<$Res> get tree;

}
/// @nodoc
class _$UiSampleFolderEvent_ScannedCopyWithImpl<$Res>
    implements $UiSampleFolderEvent_ScannedCopyWith<$Res> {
  _$UiSampleFolderEvent_ScannedCopyWithImpl(this._self, this._then);

  final UiSampleFolderEvent_Scanned _self;
  final $Res Function(UiSampleFolderEvent_Scanned) _then;

/// Create a copy of UiSampleFolderEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tree = null,}) {
  return _then(UiSampleFolderEvent_Scanned(
tree: null == tree ? _self.tree : tree // ignore: cast_nullable_to_non_nullable
as UiSampleTree,
  ));
}

/// Create a copy of UiSampleFolderEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UiSampleTreeCopyWith<$Res> get tree {
  
  return $UiSampleTreeCopyWith<$Res>(_self.tree, (value) {
    return _then(_self.copyWith(tree: value));
  });
}
}

/// @nodoc


class UiSampleFolderEvent_Unavailable extends UiSampleFolderEvent {
  const UiSampleFolderEvent_Unavailable({required this.path}): super._();
  

 final  String path;

/// Create a copy of UiSampleFolderEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiSampleFolderEvent_UnavailableCopyWith<UiSampleFolderEvent_Unavailable> get copyWith => _$UiSampleFolderEvent_UnavailableCopyWithImpl<UiSampleFolderEvent_Unavailable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiSampleFolderEvent_Unavailable&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'UiSampleFolderEvent.unavailable(path: $path)';
}


}

/// @nodoc
abstract mixin class $UiSampleFolderEvent_UnavailableCopyWith<$Res> implements $UiSampleFolderEventCopyWith<$Res> {
  factory $UiSampleFolderEvent_UnavailableCopyWith(UiSampleFolderEvent_Unavailable value, $Res Function(UiSampleFolderEvent_Unavailable) _then) = _$UiSampleFolderEvent_UnavailableCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$UiSampleFolderEvent_UnavailableCopyWithImpl<$Res>
    implements $UiSampleFolderEvent_UnavailableCopyWith<$Res> {
  _$UiSampleFolderEvent_UnavailableCopyWithImpl(this._self, this._then);

  final UiSampleFolderEvent_Unavailable _self;
  final $Res Function(UiSampleFolderEvent_Unavailable) _then;

/// Create a copy of UiSampleFolderEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(UiSampleFolderEvent_Unavailable(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class UiSampleFolderEvent_Restored extends UiSampleFolderEvent {
  const UiSampleFolderEvent_Restored(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiSampleFolderEvent_Restored);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UiSampleFolderEvent.restored()';
}


}




/// @nodoc
mixin _$UiSampleTree {

 String get name; String get path; List<UiSampleTree> get directories; List<UiSampleFile> get samples;
/// Create a copy of UiSampleTree
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiSampleTreeCopyWith<UiSampleTree> get copyWith => _$UiSampleTreeCopyWithImpl<UiSampleTree>(this as UiSampleTree, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UiSampleTree&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.directories, directories)&&const DeepCollectionEquality().equals(other.samples, samples));
}


@override
int get hashCode => Object.hash(runtimeType,name,path,const DeepCollectionEquality().hash(directories),const DeepCollectionEquality().hash(samples));

@override
String toString() {
  return 'UiSampleTree(name: $name, path: $path, directories: $directories, samples: $samples)';
}


}

/// @nodoc
abstract mixin class $UiSampleTreeCopyWith<$Res>  {
  factory $UiSampleTreeCopyWith(UiSampleTree value, $Res Function(UiSampleTree) _then) = _$UiSampleTreeCopyWithImpl;
@useResult
$Res call({
 String name, String path, List<UiSampleTree> directories, List<UiSampleFile> samples
});




}
/// @nodoc
class _$UiSampleTreeCopyWithImpl<$Res>
    implements $UiSampleTreeCopyWith<$Res> {
  _$UiSampleTreeCopyWithImpl(this._self, this._then);

  final UiSampleTree _self;
  final $Res Function(UiSampleTree) _then;

/// Create a copy of UiSampleTree
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? path = null,Object? directories = null,Object? samples = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,directories: null == directories ? _self.directories : directories // ignore: cast_nullable_to_non_nullable
as List<UiSampleTree>,samples: null == samples ? _self.samples : samples // ignore: cast_nullable_to_non_nullable
as List<UiSampleFile>,
  ));
}

}


/// Adds pattern-matching-related methods to [UiSampleTree].
extension UiSampleTreePatterns on UiSampleTree {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UiSampleTree value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UiSampleTree() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UiSampleTree value)  $default,){
final _that = this;
switch (_that) {
case _UiSampleTree():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UiSampleTree value)?  $default,){
final _that = this;
switch (_that) {
case _UiSampleTree() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String path,  List<UiSampleTree> directories,  List<UiSampleFile> samples)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UiSampleTree() when $default != null:
return $default(_that.name,_that.path,_that.directories,_that.samples);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String path,  List<UiSampleTree> directories,  List<UiSampleFile> samples)  $default,) {final _that = this;
switch (_that) {
case _UiSampleTree():
return $default(_that.name,_that.path,_that.directories,_that.samples);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String path,  List<UiSampleTree> directories,  List<UiSampleFile> samples)?  $default,) {final _that = this;
switch (_that) {
case _UiSampleTree() when $default != null:
return $default(_that.name,_that.path,_that.directories,_that.samples);case _:
  return null;

}
}

}

/// @nodoc


class _UiSampleTree implements UiSampleTree {
  const _UiSampleTree({required this.name, required this.path, required final  List<UiSampleTree> directories, required final  List<UiSampleFile> samples}): _directories = directories,_samples = samples;
  

@override final  String name;
@override final  String path;
 final  List<UiSampleTree> _directories;
@override List<UiSampleTree> get directories {
  if (_directories is EqualUnmodifiableListView) return _directories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_directories);
}

 final  List<UiSampleFile> _samples;
@override List<UiSampleFile> get samples {
  if (_samples is EqualUnmodifiableListView) return _samples;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_samples);
}


/// Create a copy of UiSampleTree
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UiSampleTreeCopyWith<_UiSampleTree> get copyWith => __$UiSampleTreeCopyWithImpl<_UiSampleTree>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UiSampleTree&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other._directories, _directories)&&const DeepCollectionEquality().equals(other._samples, _samples));
}


@override
int get hashCode => Object.hash(runtimeType,name,path,const DeepCollectionEquality().hash(_directories),const DeepCollectionEquality().hash(_samples));

@override
String toString() {
  return 'UiSampleTree(name: $name, path: $path, directories: $directories, samples: $samples)';
}


}

/// @nodoc
abstract mixin class _$UiSampleTreeCopyWith<$Res> implements $UiSampleTreeCopyWith<$Res> {
  factory _$UiSampleTreeCopyWith(_UiSampleTree value, $Res Function(_UiSampleTree) _then) = __$UiSampleTreeCopyWithImpl;
@override @useResult
$Res call({
 String name, String path, List<UiSampleTree> directories, List<UiSampleFile> samples
});




}
/// @nodoc
class __$UiSampleTreeCopyWithImpl<$Res>
    implements _$UiSampleTreeCopyWith<$Res> {
  __$UiSampleTreeCopyWithImpl(this._self, this._then);

  final _UiSampleTree _self;
  final $Res Function(_UiSampleTree) _then;

/// Create a copy of UiSampleTree
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = null,Object? directories = null,Object? samples = null,}) {
  return _then(_UiSampleTree(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,directories: null == directories ? _self._directories : directories // ignore: cast_nullable_to_non_nullable
as List<UiSampleTree>,samples: null == samples ? _self._samples : samples // ignore: cast_nullable_to_non_nullable
as List<UiSampleFile>,
  ));
}


}

// dart format on
