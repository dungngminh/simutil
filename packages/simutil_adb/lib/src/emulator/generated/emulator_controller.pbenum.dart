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

import 'package:protobuf/protobuf.dart' as $pb;

class KeyboardEvent_KeyCodeType extends $pb.ProtobufEnum {
  static const KeyboardEvent_KeyCodeType Usb =
      KeyboardEvent_KeyCodeType._(0, _omitEnumNames ? '' : 'Usb');
  static const KeyboardEvent_KeyCodeType Evdev =
      KeyboardEvent_KeyCodeType._(1, _omitEnumNames ? '' : 'Evdev');
  static const KeyboardEvent_KeyCodeType XKB =
      KeyboardEvent_KeyCodeType._(2, _omitEnumNames ? '' : 'XKB');
  static const KeyboardEvent_KeyCodeType Win =
      KeyboardEvent_KeyCodeType._(3, _omitEnumNames ? '' : 'Win');
  static const KeyboardEvent_KeyCodeType Mac =
      KeyboardEvent_KeyCodeType._(4, _omitEnumNames ? '' : 'Mac');

  static const $core.List<KeyboardEvent_KeyCodeType> values =
      <KeyboardEvent_KeyCodeType>[
    Usb,
    Evdev,
    XKB,
    Win,
    Mac,
  ];

  static final $core.List<KeyboardEvent_KeyCodeType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static KeyboardEvent_KeyCodeType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const KeyboardEvent_KeyCodeType._(super.value, super.name);
}

class KeyboardEvent_KeyEventType extends $pb.ProtobufEnum {
  static const KeyboardEvent_KeyEventType keydown =
      KeyboardEvent_KeyEventType._(0, _omitEnumNames ? '' : 'keydown');
  static const KeyboardEvent_KeyEventType keyup =
      KeyboardEvent_KeyEventType._(1, _omitEnumNames ? '' : 'keyup');
  static const KeyboardEvent_KeyEventType keypress =
      KeyboardEvent_KeyEventType._(2, _omitEnumNames ? '' : 'keypress');

  static const $core.List<KeyboardEvent_KeyEventType> values =
      <KeyboardEvent_KeyEventType>[
    keydown,
    keyup,
    keypress,
  ];

  static final $core.List<KeyboardEvent_KeyEventType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static KeyboardEvent_KeyEventType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const KeyboardEvent_KeyEventType._(super.value, super.name);
}

class ImageTransport_TransportChannel extends $pb.ProtobufEnum {
  static const ImageTransport_TransportChannel TRANSPORT_CHANNEL_UNSPECIFIED =
      ImageTransport_TransportChannel._(
          0, _omitEnumNames ? '' : 'TRANSPORT_CHANNEL_UNSPECIFIED');
  static const ImageTransport_TransportChannel MMAP =
      ImageTransport_TransportChannel._(1, _omitEnumNames ? '' : 'MMAP');

  static const $core.List<ImageTransport_TransportChannel> values =
      <ImageTransport_TransportChannel>[
    TRANSPORT_CHANNEL_UNSPECIFIED,
    MMAP,
  ];

  static final $core.List<ImageTransport_TransportChannel?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ImageTransport_TransportChannel? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ImageTransport_TransportChannel._(super.value, super.name);
}

class ImageFormat_ImgFormat extends $pb.ProtobufEnum {
  static const ImageFormat_ImgFormat PNG =
      ImageFormat_ImgFormat._(0, _omitEnumNames ? '' : 'PNG');
  static const ImageFormat_ImgFormat RGBA8888 =
      ImageFormat_ImgFormat._(1, _omitEnumNames ? '' : 'RGBA8888');
  static const ImageFormat_ImgFormat RGB888 =
      ImageFormat_ImgFormat._(2, _omitEnumNames ? '' : 'RGB888');

  static const $core.List<ImageFormat_ImgFormat> values =
      <ImageFormat_ImgFormat>[
    PNG,
    RGBA8888,
    RGB888,
  ];

  static final $core.List<ImageFormat_ImgFormat?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ImageFormat_ImgFormat? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ImageFormat_ImgFormat._(super.value, super.name);
}

class Rotation_SkinRotation extends $pb.ProtobufEnum {
  static const Rotation_SkinRotation PORTRAIT =
      Rotation_SkinRotation._(0, _omitEnumNames ? '' : 'PORTRAIT');
  static const Rotation_SkinRotation LANDSCAPE =
      Rotation_SkinRotation._(1, _omitEnumNames ? '' : 'LANDSCAPE');
  static const Rotation_SkinRotation REVERSE_PORTRAIT =
      Rotation_SkinRotation._(2, _omitEnumNames ? '' : 'REVERSE_PORTRAIT');
  static const Rotation_SkinRotation REVERSE_LANDSCAPE =
      Rotation_SkinRotation._(3, _omitEnumNames ? '' : 'REVERSE_LANDSCAPE');

  static const $core.List<Rotation_SkinRotation> values =
      <Rotation_SkinRotation>[
    PORTRAIT,
    LANDSCAPE,
    REVERSE_PORTRAIT,
    REVERSE_LANDSCAPE,
  ];

  static final $core.List<Rotation_SkinRotation?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Rotation_SkinRotation? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Rotation_SkinRotation._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
