// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:html' as html;

import 'package:devtools_plugins/devtools_plugins.dart';
import 'package:flutter/material.dart';

import '../../../../devtools_app.dart';
import '_controller_web.dart';
import 'embedded_plugin_controller.dart';

class EmbeddedPlugin extends StatefulWidget {
  const EmbeddedPlugin({
    super.key,
    required this.pluginName,
    required this.controller,
  });

  final String pluginName;
  final EmbeddedPluginController controller;

  @override
  State<EmbeddedPlugin> createState() => _EmbeddedPluginState();
}

class _EmbeddedPluginState extends State<EmbeddedPlugin> {
  late final EmbeddedPluginControllerImpl _embeddedPluginController;
  late final _PluginIFrameController iFrameController;

  @override
  void initState() {
    super.initState();
    _embeddedPluginController =
        widget.controller as EmbeddedPluginControllerImpl;
    iFrameController = _PluginIFrameController(_embeddedPluginController)
      ..init();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: HtmlElementView(
        viewType: _embeddedPluginController.viewId,
      ),
    );
  }
}

class _PluginIFrameController extends DisposableController
    with AutoDisposeControllerMixin {
  _PluginIFrameController(this.embeddedPluginController);

  final EmbeddedPluginControllerImpl embeddedPluginController;

  /// Completes when the plugin iFrame has received the first event on the
  /// 'onLoad' stream.
  late final Completer<void> _iFrameReady;

  /// Completes when the plugin's postMessage handler is ready, which is
  /// signaled by receiving a [_pluginPong] event in response to sending a
  /// [_pluginPing] event.
  late final Completer<void> _pluginHandlerReady;

  /// Timer that will poll until [_pluginHandlerReady] is complete or until
  /// [_pollUntilReadyTimeout] has passed.
  Timer? _pollForPluginHandlerReady;

  static const _pollUntilReadyTimeout = Duration(seconds: 10);

  // TODO(kenz): set up pong handler in the DevTools plugin template so that we
  // can have a ping/pong communication to verify connection readiness.

  void init() {
    _iFrameReady = Completer<void>();
    _pluginHandlerReady = Completer<void>();

    unawaited(
      embeddedPluginController.pluginIFrame.onLoad.first.then((_) {
        _iFrameReady.complete();
      }),
    );

    html.window.addEventListener('message', _handleMessage);

    autoDisposeStreamSubscription(
      embeddedPluginController.pluginPostEventStream.stream
          .listen((event) async {
        await _pingPluginUntilReady();
        _postMessage(event);
      }),
    );
  }

  void _postMessage(DevToolsPluginEvent event) async {
    await _iFrameReady.future;
    final message = event.toJson();
    assert(
      embeddedPluginController.pluginIFrame.contentWindow != null,
      'Something went wrong. The iFrame\'s contentWindow is null after the'
      ' _perfettoIFrameReady future completed.',
    );
    print('posting $message to iFrameContent window');
    embeddedPluginController.pluginIFrame.contentWindow!.postMessage(
      message,
      embeddedPluginController.pluginUrl,
    );
    print('after posting message to iFrame');
  }

  // void _postMessageWithId(
  //   String id, {
  //   Map<String, Object> args = const {},
  // }) {
  //   final message = <String, Object>{
  //     'msgId': id,
  //   }..addAll(args);
  //   _postMessage(message);
  // }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      final pluginEvent = DevToolsPluginEvent.tryParse(e.data);
      if (pluginEvent != null) {
        switch (pluginEvent.type) {
          case DevToolsPluginEventType.pong:
            if (!_pluginHandlerReady.isCompleted) {
              _pluginHandlerReady.complete();
            }
            break;
          case DevToolsPluginEventType.connectedVmService:
            final service = serviceManager.service;
            if (service == null) break;
            _postMessage(
              DevToolsPluginEvent(
                DevToolsPluginEventType.connectedVmService,
                data: {'uri': service.connectedUri.toString()},
              ),
            );
            break;
          default:
            print('DevTools: message received: ${e.data}');
            notificationService.push('${e.data}');
        }
      }
    }
  }

  Future<void> _pingPluginUntilReady() async {
    if (!_pluginHandlerReady.isCompleted) {
      _pollForPluginHandlerReady =
          Timer.periodic(const Duration(milliseconds: 200), (_) {
        // Once the plugin UI is ready, the plugin will receive this
        // [DevToolsPluginEvent.ping] message and return a
        // [DevToolsPluginEvent.pong] message, handled in [_handleMessage].
        _postMessage(DevToolsPluginEvent.ping);
      });

      await _pluginHandlerReady.future.timeout(
        _pollUntilReadyTimeout,
        onTimeout: () => _pollForPluginHandlerReady?.cancel(),
      );
      _pollForPluginHandlerReady?.cancel();
    }
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
    _pollForPluginHandlerReady?.cancel();
    super.dispose();
  }
}
