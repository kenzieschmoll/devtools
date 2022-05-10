// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

const _debugUseLocalPerfetto = true;

class PerfettoController {
  static const viewId = 'embedded-perfetto';

  static const _perfettoUrl = 'https://ui.perfetto.dev';

  /// Url when running Perfetto locally following the instructions here:
  /// https://perfetto.dev/docs/contributing/build-instructions#ui-development
  static const _perfettoUrlLocal = 'http://127.0.0.1:10000';

  String get perfettoUrl =>
      _debugUseLocalPerfetto ? _perfettoUrlLocal : _perfettoUrl;

  late final html.IFrameElement _perfettoIFrame;

  late final Completer<void> _perfettoReady;

  void init() {
    _perfettoReady = Completer();
    _perfettoIFrame = html.IFrameElement()
      ..src = perfettoUrl
      ..allow = 'usb';
    _perfettoIFrame.style
      ..border = 'none'
      ..height = '100%'
      ..width = '100%';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _perfettoIFrame,
    );

    html.window.addEventListener('message', _handleMessage);
  }

  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
  }

  void _postMessage(dynamic message) {
    _perfettoIFrame.contentWindow!.postMessage(
      message,
      perfettoUrl,
    );
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      if (e.data == 'PONG' && !_perfettoReady.isCompleted) {
        _perfettoReady.complete();
      }
    }
  }

  Future<void> loadTrace() async {
    await pingUntilReady();

    const testUrl =
        'https://storage.googleapis.com/perfetto-misc/example_android_trace_15s';
    final request = html.HttpRequest()
      ..open('GET', testUrl, async: true)
      ..responseType = 'arraybuffer';
    request.send();
    await request.onLoad.first;
    final arrayBuffer = (request.response as ByteBuffer).asUint8List();

    _postMessage({
      'perfetto': {
        'buffer': arrayBuffer,
        'title': 'My Loaded Trace',
        'url': '$perfettoUrl#reopen=$testUrl',
      }
    });
  }

  Future<void> pingUntilReady() async {
    while (!_perfettoReady.isCompleted) {
      await Future.delayed(const Duration(microseconds: 100), () async {
        // Once the Perfetto UI is ready, Perfetto will receive this 'PING'
        // message and return a 'PONG' message, handled in [_handleMessage]
        // below.
        _postMessage('PING');
      });
    }
  }
}
