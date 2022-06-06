// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../primitives/auto_dispose.dart';
import '../../../primitives/trace_event.dart';
import '../../../shared/globals.dart';

const _debugUseLocalPerfetto = false;

class PerfettoController extends DisposableController
    with AutoDisposeControllerMixin {
  static const viewId = 'embedded-perfetto';

  String get _bundledPerfettoUrl =>
      '${html.window.location.origin}/assets/perfetto/dist/index.html$_embeddedModeQuery';

  /// Url when running Perfetto locally following the instructions here:
  /// https://perfetto.dev/docs/contributing/build-instructions#ui-development
  static const _debugPerfettoUrl = 'http://127.0.0.1:10000/$_embeddedModeQuery';

  static const _embeddedModeQuery = '?mode=embedded';

  String get perfettoUrl =>
      _debugUseLocalPerfetto ? _debugPerfettoUrl : _bundledPerfettoUrl;

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

    print('supported?');
    print(_perfettoIFrame.style.supportsProperty('overscroll-behavior-x'));
    _perfettoIFrame.style.setProperty('overscrollBehaviorX', 'none');

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _perfettoIFrame,
    );

    html.window.addEventListener('message', _handleMessage);

    addAutoDisposeListener(preferences.darkModeTheme, () async {
      final useDarkMode = preferences.darkModeTheme.value;
      await setStyle(useDarkMode);
    });
  }

  static const _darkModeStylesheetId = 'devtools-dark';
  static const _lightModeStylesheetId = 'devtools-light';
  Future<void> setStyle(bool darkMode) async {
    print('calling set style: ${darkMode ? 'dark' : 'light'}');
    await _pingUntilReady();
    _postMessage({
      'perfetto': {
        'addStyle': darkMode ? _darkModeStylesheetId : _lightModeStylesheetId,
        'removeStyle':
            darkMode ? _lightModeStylesheetId : _darkModeStylesheetId,
      },
    });
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
    super.dispose();
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

  Future<void> loadTrace(
    List<TraceEventWrapper> devToolsTraceEvents,
    Map<String, dynamic> stackFramesJson,
  ) async {
    print('entering load trace');
    await _pingUntilReady();

    final encodedJson = jsonEncode({
      'traceEvents': devToolsTraceEvents
          .map((eventWrapper) => eventWrapper.event.json)
          .toList(),
      'stackFrames': stackFramesJson,
    });
    final buffer = Uint8List.fromList(encodedJson.codeUnits);

    print('posting trace');
    _postMessage({
      'perfetto': {
        'buffer': buffer,
        'title': 'My Loaded Trace',
      }
    });
  }

  Future<void> clear() async {
    await loadTrace([], {});
  }

  Future<void> _pingUntilReady() async {
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
