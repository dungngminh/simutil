// This is a generated file - do not edit.
//
// Generated from emulator_controller.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'emulator_controller.pb.dart' as $0;

export 'emulator_controller.pb.dart';

@$pb.GrpcServiceName('android.emulation.control.EmulatorController')
class EmulatorControllerClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  EmulatorControllerClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$1.Empty> streamInputEvent(
    $async.Stream<$0.InputEvent> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$streamInputEvent, request, options: options)
        .single;
  }

  $grpc.ResponseFuture<$0.Image> getScreenshot(
    $0.ImageFormat request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getScreenshot, request, options: options);
  }

  $grpc.ResponseStream<$0.Image> streamScreenshot(
    $0.ImageFormat request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$streamScreenshot, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$streamInputEvent = $grpc.ClientMethod<$0.InputEvent, $1.Empty>(
      '/android.emulation.control.EmulatorController/streamInputEvent',
      ($0.InputEvent value) => value.writeToBuffer(),
      $1.Empty.fromBuffer);
  static final _$getScreenshot = $grpc.ClientMethod<$0.ImageFormat, $0.Image>(
      '/android.emulation.control.EmulatorController/getScreenshot',
      ($0.ImageFormat value) => value.writeToBuffer(),
      $0.Image.fromBuffer);
  static final _$streamScreenshot =
      $grpc.ClientMethod<$0.ImageFormat, $0.Image>(
          '/android.emulation.control.EmulatorController/streamScreenshot',
          ($0.ImageFormat value) => value.writeToBuffer(),
          $0.Image.fromBuffer);
}

@$pb.GrpcServiceName('android.emulation.control.EmulatorController')
abstract class EmulatorControllerServiceBase extends $grpc.Service {
  $core.String get $name => 'android.emulation.control.EmulatorController';

  EmulatorControllerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.InputEvent, $1.Empty>(
        'streamInputEvent',
        streamInputEvent,
        true,
        false,
        ($core.List<$core.int> value) => $0.InputEvent.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ImageFormat, $0.Image>(
        'getScreenshot',
        getScreenshot_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ImageFormat.fromBuffer(value),
        ($0.Image value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ImageFormat, $0.Image>(
        'streamScreenshot',
        streamScreenshot_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.ImageFormat.fromBuffer(value),
        ($0.Image value) => value.writeToBuffer()));
  }

  $async.Future<$1.Empty> streamInputEvent(
      $grpc.ServiceCall call, $async.Stream<$0.InputEvent> request);

  $async.Future<$0.Image> getScreenshot_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ImageFormat> $request) async {
    return getScreenshot($call, await $request);
  }

  $async.Future<$0.Image> getScreenshot(
      $grpc.ServiceCall call, $0.ImageFormat request);

  $async.Stream<$0.Image> streamScreenshot_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ImageFormat> $request) async* {
    yield* streamScreenshot($call, await $request);
  }

  $async.Stream<$0.Image> streamScreenshot(
      $grpc.ServiceCall call, $0.ImageFormat request);
}
