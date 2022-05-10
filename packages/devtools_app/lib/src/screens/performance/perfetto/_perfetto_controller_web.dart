// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
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

  html.IFrameElement get perfettoIFrame => _perfettoIFrame;

  late final html.IFrameElement _perfettoIFrame;

  void init() {
    _perfettoIFrame = html.IFrameElement()
      ..src = perfettoUrl
      ..allow = 'usb';
    _perfettoIFrame.style
      ..border = 'none'
      ..height = '100%'
      ..width = '100%';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'embedded-perfetto',
      (int viewId) => _perfettoIFrame,
    );
  }
}
