// This is a generated file - do not edit.
//
// Generated from emulator_controller.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'emulator_controller.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'emulator_controller.pbenum.dart';

class Touch extends $pb.GeneratedMessage {
  factory Touch({
    $core.int? x,
    $core.int? y,
    $core.int? identifier,
    $core.int? pressure,
    $core.int? touchMajor,
    $core.int? touchMinor,
  }) {
    final result = Touch._();
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (identifier != null) result.identifier = identifier;
    if (pressure != null) result.pressure = pressure;
    if (touchMajor != null) result.touchMajor = touchMajor;
    if (touchMinor != null) result.touchMinor = touchMinor;
    return result;
  }

  Touch._();

  factory Touch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Touch()..mergeFromBuffer(data, registry);
  factory Touch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Touch()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Touch',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: Touch.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'x')
    ..aI(2, _omitFieldNames ? '' : 'y')
    ..aI(3, _omitFieldNames ? '' : 'identifier')
    ..aI(4, _omitFieldNames ? '' : 'pressure')
    ..aI(5, _omitFieldNames ? '' : 'touchMajor')
    ..aI(6, _omitFieldNames ? '' : 'touchMinor')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Touch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Touch copyWith(void Function(Touch) updates) =>
      super.copyWith((message) => updates(message as Touch)) as Touch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Touch() / Touch.new instead')
  static Touch create() => Touch._();
  static $pb.GeneratedMessage $_createMessage() => Touch._();
  @$core.override
  Touch createEmptyInstance() => Touch._();
  @$core.pragma('dart2js:noInline')
  static Touch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Touch>(Touch.$_createMessage);
  static Touch? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get x => $_getIZ(0);
  @$pb.TagNumber(1)
  set x($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasX() => $_has(0);
  @$pb.TagNumber(1)
  void clearX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get y => $_getIZ(1);
  @$pb.TagNumber(2)
  set y($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasY() => $_has(1);
  @$pb.TagNumber(2)
  void clearY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get identifier => $_getIZ(2);
  @$pb.TagNumber(3)
  set identifier($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIdentifier() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdentifier() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get pressure => $_getIZ(3);
  @$pb.TagNumber(4)
  set pressure($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPressure() => $_has(3);
  @$pb.TagNumber(4)
  void clearPressure() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get touchMajor => $_getIZ(4);
  @$pb.TagNumber(5)
  set touchMajor($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTouchMajor() => $_has(4);
  @$pb.TagNumber(5)
  void clearTouchMajor() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get touchMinor => $_getIZ(5);
  @$pb.TagNumber(6)
  set touchMinor($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTouchMinor() => $_has(5);
  @$pb.TagNumber(6)
  void clearTouchMinor() => $_clearField(6);
}

class TouchEvent extends $pb.GeneratedMessage {
  factory TouchEvent({
    $core.Iterable<Touch>? touches,
    $core.int? display,
  }) {
    final result = TouchEvent._();
    if (touches != null) result.touches.addAll(touches);
    if (display != null) result.display = display;
    return result;
  }

  TouchEvent._();

  factory TouchEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TouchEvent()..mergeFromBuffer(data, registry);
  factory TouchEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TouchEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TouchEvent',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: TouchEvent.$_createMessage)
    ..pPM<Touch>(1, _omitFieldNames ? '' : 'touches',
        subBuilder: Touch.$_createMessage)
    ..aI(2, _omitFieldNames ? '' : 'display')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TouchEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TouchEvent copyWith(void Function(TouchEvent) updates) =>
      super.copyWith((message) => updates(message as TouchEvent)) as TouchEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TouchEvent() / TouchEvent.new instead')
  static TouchEvent create() => TouchEvent._();
  static $pb.GeneratedMessage $_createMessage() => TouchEvent._();
  @$core.override
  TouchEvent createEmptyInstance() => TouchEvent._();
  @$core.pragma('dart2js:noInline')
  static TouchEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TouchEvent>(TouchEvent.$_createMessage);
  static TouchEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Touch> get touches => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get display => $_getIZ(1);
  @$pb.TagNumber(2)
  set display($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplay() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplay() => $_clearField(2);
}

class MouseEvent extends $pb.GeneratedMessage {
  factory MouseEvent({
    $core.int? x,
    $core.int? y,
    $core.int? buttons,
    $core.int? display,
  }) {
    final result = MouseEvent._();
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (buttons != null) result.buttons = buttons;
    if (display != null) result.display = display;
    return result;
  }

  MouseEvent._();

  factory MouseEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MouseEvent()..mergeFromBuffer(data, registry);
  factory MouseEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MouseEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MouseEvent',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: MouseEvent.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'x')
    ..aI(2, _omitFieldNames ? '' : 'y')
    ..aI(3, _omitFieldNames ? '' : 'buttons')
    ..aI(4, _omitFieldNames ? '' : 'display')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MouseEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MouseEvent copyWith(void Function(MouseEvent) updates) =>
      super.copyWith((message) => updates(message as MouseEvent)) as MouseEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MouseEvent() / MouseEvent.new instead')
  static MouseEvent create() => MouseEvent._();
  static $pb.GeneratedMessage $_createMessage() => MouseEvent._();
  @$core.override
  MouseEvent createEmptyInstance() => MouseEvent._();
  @$core.pragma('dart2js:noInline')
  static MouseEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MouseEvent>(MouseEvent.$_createMessage);
  static MouseEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get x => $_getIZ(0);
  @$pb.TagNumber(1)
  set x($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasX() => $_has(0);
  @$pb.TagNumber(1)
  void clearX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get y => $_getIZ(1);
  @$pb.TagNumber(2)
  set y($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasY() => $_has(1);
  @$pb.TagNumber(2)
  void clearY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get buttons => $_getIZ(2);
  @$pb.TagNumber(3)
  set buttons($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasButtons() => $_has(2);
  @$pb.TagNumber(3)
  void clearButtons() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get display => $_getIZ(3);
  @$pb.TagNumber(4)
  set display($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDisplay() => $_has(3);
  @$pb.TagNumber(4)
  void clearDisplay() => $_clearField(4);
}

class KeyboardEvent extends $pb.GeneratedMessage {
  factory KeyboardEvent({
    KeyboardEvent_KeyCodeType? codeType,
    KeyboardEvent_KeyEventType? eventType,
    $core.int? keyCode,
    $core.String? key,
    $core.String? text,
  }) {
    final result = KeyboardEvent._();
    if (codeType != null) result.codeType = codeType;
    if (eventType != null) result.eventType = eventType;
    if (keyCode != null) result.keyCode = keyCode;
    if (key != null) result.key = key;
    if (text != null) result.text = text;
    return result;
  }

  KeyboardEvent._();

  factory KeyboardEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeyboardEvent()..mergeFromBuffer(data, registry);
  factory KeyboardEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeyboardEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyboardEvent',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: KeyboardEvent.$_createMessage)
    ..aE<KeyboardEvent_KeyCodeType>(1, _omitFieldNames ? '' : 'codeType',
        protoName: 'codeType', enumValues: KeyboardEvent_KeyCodeType.values)
    ..aE<KeyboardEvent_KeyEventType>(2, _omitFieldNames ? '' : 'eventType',
        protoName: 'eventType', enumValues: KeyboardEvent_KeyEventType.values)
    ..aI(3, _omitFieldNames ? '' : 'keyCode', protoName: 'keyCode')
    ..aOS(4, _omitFieldNames ? '' : 'key')
    ..aOS(5, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyboardEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyboardEvent copyWith(void Function(KeyboardEvent) updates) =>
      super.copyWith((message) => updates(message as KeyboardEvent))
          as KeyboardEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KeyboardEvent() / KeyboardEvent.new instead')
  static KeyboardEvent create() => KeyboardEvent._();
  static $pb.GeneratedMessage $_createMessage() => KeyboardEvent._();
  @$core.override
  KeyboardEvent createEmptyInstance() => KeyboardEvent._();
  @$core.pragma('dart2js:noInline')
  static KeyboardEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeyboardEvent>(
          KeyboardEvent.$_createMessage);
  static KeyboardEvent? _defaultInstance;

  @$pb.TagNumber(1)
  KeyboardEvent_KeyCodeType get codeType => $_getN(0);
  @$pb.TagNumber(1)
  set codeType(KeyboardEvent_KeyCodeType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCodeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearCodeType() => $_clearField(1);

  @$pb.TagNumber(2)
  KeyboardEvent_KeyEventType get eventType => $_getN(1);
  @$pb.TagNumber(2)
  set eventType(KeyboardEvent_KeyEventType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasEventType() => $_has(1);
  @$pb.TagNumber(2)
  void clearEventType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get keyCode => $_getIZ(2);
  @$pb.TagNumber(3)
  set keyCode($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKeyCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearKeyCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get key => $_getSZ(3);
  @$pb.TagNumber(4)
  set key($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearKey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get text => $_getSZ(4);
  @$pb.TagNumber(5)
  set text($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasText() => $_has(4);
  @$pb.TagNumber(5)
  void clearText() => $_clearField(5);
}

enum InputEvent_Type { keyEvent, touchEvent, mouseEvent, notSet }

class InputEvent extends $pb.GeneratedMessage {
  factory InputEvent({
    KeyboardEvent? keyEvent,
    TouchEvent? touchEvent,
    MouseEvent? mouseEvent,
  }) {
    final result = InputEvent._();
    if (keyEvent != null) result.keyEvent = keyEvent;
    if (touchEvent != null) result.touchEvent = touchEvent;
    if (mouseEvent != null) result.mouseEvent = mouseEvent;
    return result;
  }

  InputEvent._();

  factory InputEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InputEvent()..mergeFromBuffer(data, registry);
  factory InputEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InputEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, InputEvent_Type> _InputEvent_TypeByTag = {
    1: InputEvent_Type.keyEvent,
    2: InputEvent_Type.touchEvent,
    3: InputEvent_Type.mouseEvent,
    0: InputEvent_Type.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InputEvent',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: InputEvent.$_createMessage)
    ..oo(0, [1, 2, 3])
    ..aOM<KeyboardEvent>(1, _omitFieldNames ? '' : 'keyEvent',
        subBuilder: KeyboardEvent.$_createMessage)
    ..aOM<TouchEvent>(2, _omitFieldNames ? '' : 'touchEvent',
        subBuilder: TouchEvent.$_createMessage)
    ..aOM<MouseEvent>(3, _omitFieldNames ? '' : 'mouseEvent',
        subBuilder: MouseEvent.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InputEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InputEvent copyWith(void Function(InputEvent) updates) =>
      super.copyWith((message) => updates(message as InputEvent)) as InputEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use InputEvent() / InputEvent.new instead')
  static InputEvent create() => InputEvent._();
  static $pb.GeneratedMessage $_createMessage() => InputEvent._();
  @$core.override
  InputEvent createEmptyInstance() => InputEvent._();
  @$core.pragma('dart2js:noInline')
  static InputEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InputEvent>(InputEvent.$_createMessage);
  static InputEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  InputEvent_Type whichType() => _InputEvent_TypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearType() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  KeyboardEvent get keyEvent => $_getN(0);
  @$pb.TagNumber(1)
  set keyEvent(KeyboardEvent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyEvent() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyEvent() => $_clearField(1);
  @$pb.TagNumber(1)
  KeyboardEvent ensureKeyEvent() => $_ensure(0);

  @$pb.TagNumber(2)
  TouchEvent get touchEvent => $_getN(1);
  @$pb.TagNumber(2)
  set touchEvent(TouchEvent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTouchEvent() => $_has(1);
  @$pb.TagNumber(2)
  void clearTouchEvent() => $_clearField(2);
  @$pb.TagNumber(2)
  TouchEvent ensureTouchEvent() => $_ensure(1);

  @$pb.TagNumber(3)
  MouseEvent get mouseEvent => $_getN(2);
  @$pb.TagNumber(3)
  set mouseEvent(MouseEvent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMouseEvent() => $_has(2);
  @$pb.TagNumber(3)
  void clearMouseEvent() => $_clearField(3);
  @$pb.TagNumber(3)
  MouseEvent ensureMouseEvent() => $_ensure(2);
}

class ImageTransport extends $pb.GeneratedMessage {
  factory ImageTransport({
    ImageTransport_TransportChannel? channel,
    $core.String? handle,
  }) {
    final result = ImageTransport._();
    if (channel != null) result.channel = channel;
    if (handle != null) result.handle = handle;
    return result;
  }

  ImageTransport._();

  factory ImageTransport.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageTransport()..mergeFromBuffer(data, registry);
  factory ImageTransport.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageTransport()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageTransport',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: ImageTransport.$_createMessage)
    ..aE<ImageTransport_TransportChannel>(1, _omitFieldNames ? '' : 'channel',
        enumValues: ImageTransport_TransportChannel.values)
    ..aOS(2, _omitFieldNames ? '' : 'handle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageTransport clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageTransport copyWith(void Function(ImageTransport) updates) =>
      super.copyWith((message) => updates(message as ImageTransport))
          as ImageTransport;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImageTransport() / ImageTransport.new instead')
  static ImageTransport create() => ImageTransport._();
  static $pb.GeneratedMessage $_createMessage() => ImageTransport._();
  @$core.override
  ImageTransport createEmptyInstance() => ImageTransport._();
  @$core.pragma('dart2js:noInline')
  static ImageTransport getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImageTransport>(
          ImageTransport.$_createMessage);
  static ImageTransport? _defaultInstance;

  @$pb.TagNumber(1)
  ImageTransport_TransportChannel get channel => $_getN(0);
  @$pb.TagNumber(1)
  set channel(ImageTransport_TransportChannel value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasChannel() => $_has(0);
  @$pb.TagNumber(1)
  void clearChannel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get handle => $_getSZ(1);
  @$pb.TagNumber(2)
  set handle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHandle() => $_has(1);
  @$pb.TagNumber(2)
  void clearHandle() => $_clearField(2);
}

class ImageFormat extends $pb.GeneratedMessage {
  factory ImageFormat({
    ImageFormat_ImgFormat? format,
    Rotation? rotation,
    $core.int? width,
    $core.int? height,
    $core.int? display,
    ImageTransport? transport,
  }) {
    final result = ImageFormat._();
    if (format != null) result.format = format;
    if (rotation != null) result.rotation = rotation;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (display != null) result.display = display;
    if (transport != null) result.transport = transport;
    return result;
  }

  ImageFormat._();

  factory ImageFormat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageFormat()..mergeFromBuffer(data, registry);
  factory ImageFormat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageFormat()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageFormat',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: ImageFormat.$_createMessage)
    ..aE<ImageFormat_ImgFormat>(1, _omitFieldNames ? '' : 'format',
        enumValues: ImageFormat_ImgFormat.values)
    ..aOM<Rotation>(2, _omitFieldNames ? '' : 'rotation',
        subBuilder: Rotation.$_createMessage)
    ..aI(3, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'display', fieldType: $pb.PbFieldType.OU3)
    ..aOM<ImageTransport>(6, _omitFieldNames ? '' : 'transport',
        subBuilder: ImageTransport.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageFormat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageFormat copyWith(void Function(ImageFormat) updates) =>
      super.copyWith((message) => updates(message as ImageFormat))
          as ImageFormat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImageFormat() / ImageFormat.new instead')
  static ImageFormat create() => ImageFormat._();
  static $pb.GeneratedMessage $_createMessage() => ImageFormat._();
  @$core.override
  ImageFormat createEmptyInstance() => ImageFormat._();
  @$core.pragma('dart2js:noInline')
  static ImageFormat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImageFormat>(
          ImageFormat.$_createMessage);
  static ImageFormat? _defaultInstance;

  @$pb.TagNumber(1)
  ImageFormat_ImgFormat get format => $_getN(0);
  @$pb.TagNumber(1)
  set format(ImageFormat_ImgFormat value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFormat() => $_has(0);
  @$pb.TagNumber(1)
  void clearFormat() => $_clearField(1);

  @$pb.TagNumber(2)
  Rotation get rotation => $_getN(1);
  @$pb.TagNumber(2)
  set rotation(Rotation value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRotation() => $_has(1);
  @$pb.TagNumber(2)
  void clearRotation() => $_clearField(2);
  @$pb.TagNumber(2)
  Rotation ensureRotation() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.int get width => $_getIZ(2);
  @$pb.TagNumber(3)
  set width($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWidth() => $_has(2);
  @$pb.TagNumber(3)
  void clearWidth() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get height => $_getIZ(3);
  @$pb.TagNumber(4)
  set height($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearHeight() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get display => $_getIZ(4);
  @$pb.TagNumber(5)
  set display($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDisplay() => $_has(4);
  @$pb.TagNumber(5)
  void clearDisplay() => $_clearField(5);

  @$pb.TagNumber(6)
  ImageTransport get transport => $_getN(5);
  @$pb.TagNumber(6)
  set transport(ImageTransport value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTransport() => $_has(5);
  @$pb.TagNumber(6)
  void clearTransport() => $_clearField(6);
  @$pb.TagNumber(6)
  ImageTransport ensureTransport() => $_ensure(5);
}

class Image extends $pb.GeneratedMessage {
  factory Image({
    ImageFormat? format,
    $core.List<$core.int>? image,
    $core.int? seq,
    $fixnum.Int64? timestampUs,
  }) {
    final result = Image._();
    if (format != null) result.format = format;
    if (image != null) result.image = image;
    if (seq != null) result.seq = seq;
    if (timestampUs != null) result.timestampUs = timestampUs;
    return result;
  }

  Image._();

  factory Image.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Image()..mergeFromBuffer(data, registry);
  factory Image.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Image()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Image',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: Image.$_createMessage)
    ..aOM<ImageFormat>(1, _omitFieldNames ? '' : 'format',
        subBuilder: ImageFormat.$_createMessage)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'image', $pb.PbFieldType.OY)
    ..aI(5, _omitFieldNames ? '' : 'seq', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'timestampUs', $pb.PbFieldType.OU6,
        protoName: 'timestampUs', defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Image clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Image copyWith(void Function(Image) updates) =>
      super.copyWith((message) => updates(message as Image)) as Image;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Image() / Image.new instead')
  static Image create() => Image._();
  static $pb.GeneratedMessage $_createMessage() => Image._();
  @$core.override
  Image createEmptyInstance() => Image._();
  @$core.pragma('dart2js:noInline')
  static Image getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Image>(Image.$_createMessage);
  static Image? _defaultInstance;

  @$pb.TagNumber(1)
  ImageFormat get format => $_getN(0);
  @$pb.TagNumber(1)
  set format(ImageFormat value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFormat() => $_has(0);
  @$pb.TagNumber(1)
  void clearFormat() => $_clearField(1);
  @$pb.TagNumber(1)
  ImageFormat ensureFormat() => $_ensure(0);

  @$pb.TagNumber(4)
  $core.List<$core.int> get image => $_getN(1);
  @$pb.TagNumber(4)
  set image($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(4)
  $core.bool hasImage() => $_has(1);
  @$pb.TagNumber(4)
  void clearImage() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get seq => $_getIZ(2);
  @$pb.TagNumber(5)
  set seq($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(5)
  $core.bool hasSeq() => $_has(2);
  @$pb.TagNumber(5)
  void clearSeq() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get timestampUs => $_getI64(3);
  @$pb.TagNumber(6)
  set timestampUs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(6)
  $core.bool hasTimestampUs() => $_has(3);
  @$pb.TagNumber(6)
  void clearTimestampUs() => $_clearField(6);
}

class Rotation extends $pb.GeneratedMessage {
  factory Rotation({
    Rotation_SkinRotation? rotation,
  }) {
    final result = Rotation._();
    if (rotation != null) result.rotation = rotation;
    return result;
  }

  Rotation._();

  factory Rotation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Rotation()..mergeFromBuffer(data, registry);
  factory Rotation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Rotation()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Rotation',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'android.emulation.control'),
      createEmptyInstance: Rotation.$_createMessage)
    ..aE<Rotation_SkinRotation>(1, _omitFieldNames ? '' : 'rotation',
        enumValues: Rotation_SkinRotation.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rotation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Rotation copyWith(void Function(Rotation) updates) =>
      super.copyWith((message) => updates(message as Rotation)) as Rotation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Rotation() / Rotation.new instead')
  static Rotation create() => Rotation._();
  static $pb.GeneratedMessage $_createMessage() => Rotation._();
  @$core.override
  Rotation createEmptyInstance() => Rotation._();
  @$core.pragma('dart2js:noInline')
  static Rotation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Rotation>(Rotation.$_createMessage);
  static Rotation? _defaultInstance;

  @$pb.TagNumber(1)
  Rotation_SkinRotation get rotation => $_getN(0);
  @$pb.TagNumber(1)
  set rotation(Rotation_SkinRotation value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRotation() => $_has(0);
  @$pb.TagNumber(1)
  void clearRotation() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
