// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:devtools_plugins/devtools_plugins.dart';
import 'package:flutter/foundation.dart';

import '../plugins_model.dart';
import 'embedded_plugin_controller.dart';

/// Incrementer for the Perfetto iFrame view that will live for the entire
/// DevTools lifecycle.
///
/// A new instance of [PerfettoController] will be created for each connected
/// app and for each load of offline data. Each time [PerfettoController.init]
/// is called, we create a new [html.IFrameElement] and register it to
/// [PerfettoController.viewId] via
/// [ui.platformViewRegistry.registerViewFactory]. Each new [html.IFrameElement]
/// must have a unique id in the [PlatformViewRegistry], which
/// [_viewIdIncrementer] is used to create.
var _viewIdIncrementer = 0;

class EmbeddedPluginControllerImpl extends EmbeddedPluginController {
  EmbeddedPluginControllerImpl(this.selectedPluginNotifier);

  final ValueListenable<DevToolsPluginConfig?> selectedPluginNotifier;

  /// The view id for the Perfetto iFrame.
  ///
  /// See [_viewIdIncrementer] for an explanation of why we use an incrementer
  /// in the id.
  late final viewId =
      'devtools-plugin-${_viewIdIncrementer++}'; // this needs name

  String get pluginUrl {
    assert(selectedPluginNotifier.value != null);
    final pluginName = selectedPluginNotifier.value!.name;
    return '${html.window.location.origin}/devtools_plugins/$pluginName/index.html';
  }

  html.IFrameElement get pluginIFrame => _pluginIFrame;

  late final html.IFrameElement _pluginIFrame;

  final pluginPostEventStream =
      StreamController<DevToolsPluginEvent>.broadcast();

  bool _initialized = false;

  @override
  void init() {
    assert(
      !_initialized,
      'PluginWebViewController.init() should only be called once.',
    );
    _initialized = true;

    _pluginIFrame = html.IFrameElement()
      // This url is safe because we built it ourselves and it does not include
      // any user input.
      // ignore: unsafe_html
      ..src = pluginUrl
      ..allow = 'usb';
    _pluginIFrame.style
      ..border = 'none'
      ..height = '100%'
      ..width = '100%';

    // This ignore is required due to
    // https://github.com/flutter/flutter/issues/41563
    // ignore: undefined_prefixed_name
    final registered = ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _pluginIFrame,
    );
    assert(registered, 'Failed to register view factory for $viewId.');
  }

  @override
  void postMessage(String message) {
    pluginPostEventStream.add(
      DevToolsPluginEvent(
        DevToolsPluginEventType.testEvent,
        data: {'message': message},
      ),
    );
  }

  @override
  void dispose() async {
    await pluginPostEventStream.close();
    super.dispose();
  }
}
