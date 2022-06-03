// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../primitives/trace_event.dart';

const _debugUseLocalPerfetto = true;

class PerfettoController {
  static const viewId = 'embedded-perfetto';

  static const _perfettoUrl = 'https://ui.perfetto.dev/#/?hideSidebar=true';

  /// Url when running Perfetto locally following the instructions here:
  /// https://perfetto.dev/docs/contributing/build-instructions#ui-development
  static const _perfettoUrlLocal =
      'http://127.0.0.1:10000/#!/viewer?hideSidebar=true';

  String get perfettoUrl =>
      '${html.window.location.origin}/assets/perfetto/dist/index.html?mode=embedded';
  // _debugUseLocalPerfetto ? _perfettoUrlLocal : _perfettoUrl;

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

  Future<void> loadTrace(List<TraceEventWrapper> devToolsTraceEvents) async {
    await pingUntilReady();

    final encodedJson = jsonEncode({
      'traceEvents': devToolsTraceEvents
          .map((eventWrapper) => eventWrapper.event.json)
          .toList(),
    });
    final buffer = Uint8List.fromList(encodedJson.codeUnits);

    _postMessage({
      'perfetto': {
        'buffer': buffer,
        'title': 'My Loaded Trace',
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
