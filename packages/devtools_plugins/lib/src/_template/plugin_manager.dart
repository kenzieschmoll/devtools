// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:html' as html;
import 'package:devtools_plugins/devtools_plugins.dart';
import 'package:logging/logging.dart';

import 'connected_app_manager.dart';

final _log = Logger('devtools_plugins/plugin_manager');

class PluginManager {
  final appManager = ConnectedAppManager();

  final _registeredEventHandlers =
      <DevToolsPluginEventType, PluginEventHandler>{};

  void init({required bool connectToVmService}) {
    html.window.addEventListener('message', _handleMessage);
    if (connectToVmService) {
      // Request the vm service uri for the connected app. DevTools will
      // respond with a [DevToolsPluginEventType.connectedVmService] event with
      // containing the currently connected app's vm service URI.
      postMessageToDevTools(
        DevToolsPluginEvent(DevToolsPluginEventType.connectedVmService),
      );
    }
  }

  void dispose() {
    _registeredEventHandlers.clear();
    html.window.removeEventListener('message', _handleMessage);
  }

  void registerEventHandler(
    DevToolsPluginEventType event,
    PluginEventHandler handler,
  ) {
    _registeredEventHandlers[event] = handler;
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      final pluginEvent = DevToolsPluginEvent.tryParse(e.data);
      if (pluginEvent != null) {
        switch (pluginEvent.type) {
          case DevToolsPluginEventType.ping:
            html.window.parent?.postMessage(
              DevToolsPluginEvent.pong.toJson(),
              e.origin,
            );
            break;
          case DevToolsPluginEventType.connectedVmService:
            final vmServiceUri = pluginEvent.data?['uri'] as String?;
            appManager.vmServiceUri = vmServiceUri;
            break;
          case DevToolsPluginEventType.pong:
            // Ignore. DevTools Plugins should not receive/handle these events.
            break;
          case DevToolsPluginEventType.unknown:
            _log.info('Unrecognized event received by plugin: ${e.data}');
            break;
          default:
        }
        _registeredEventHandlers[pluginEvent.type]?.call(pluginEvent);
      }
    }
  }

  void postMessageToDevTools(DevToolsPluginEvent event) {
    html.window.parent?.postMessage(event.toJson(), html.window.origin!);
  }
}
