import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

/// Android OTP auto-fill using Google's SMS User Consent API.
///
/// When the OTP SMS arrives, Android shows a one-tap "Allow" popup; after the
/// user allows, the 6-digit code is filled into the OTP boxes. No SMS read
/// permission is needed. Talks to MainActivity.kt over a method channel.
class SmsUserConsentRetriever implements SmsRetriever {
  SmsUserConsentRetriever({this.codeLength = 6});

  static const MethodChannel _channel =
      MethodChannel('yunido/sms_user_consent');

  final int codeLength;
  Completer<String?>? _completer;
  bool _disposed = false;

  static bool get isSupported => Platform.isAndroid;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    final completer = _completer;
    if (completer == null || completer.isCompleted) return;
    switch (call.method) {
      case 'onSms':
        completer.complete(_extractCode(call.arguments as String?));
        break;
      case 'onTimeout':
      case 'onDenied':
        completer.complete(null);
        break;
    }
  }

  String? _extractCode(String? message) {
    if (message == null) return null;
    final match = RegExp('(?<!\\d)\\d{$codeLength}(?!\\d)').firstMatch(message);
    return match?.group(0);
  }

  @override
  Future<String?> getSmsCode() async {
    // Never complete after dispose so Pinput's listen loop stops cleanly.
    if (_disposed || !isSupported) return Completer<String?>().future;

    _completer = Completer<String?>();
    _channel.setMethodCallHandler(_onNativeCall);
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {
      return Completer<String?>().future;
    }
    final code = await _completer!.future;
    if (_disposed) return Completer<String?>().future;
    if (code == null) {
      // Session ended without a code (timeout / user denied) — small pause
      // before listening again.
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return code;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final completer = _completer;
    if (completer != null && !completer.isCompleted) completer.complete(null);
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Keep listening so a resent OTP is also auto-filled.
  @override
  bool get listenForMultipleSms => true;
}
