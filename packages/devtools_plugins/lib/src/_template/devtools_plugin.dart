// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_plugins/devtools_plugins.dart';
import 'package:flutter/widgets.dart';

import 'plugin_manager.dart';

PluginManager get pluginManager => _pluginManager;
late final PluginManager _pluginManager;

class DevToolsPlugin extends StatefulWidget {
  const DevToolsPlugin({
    super.key,
    required this.child,
    this.eventHandlers = const {},
    this.requiresRunningApplication = true,
  });

  final Widget child;

  final Map<DevToolsPluginEventType, PluginEventHandler> eventHandlers;

  final bool requiresRunningApplication;

  @override
  State<DevToolsPlugin> createState() => _DevToolsPluginState();
}

class _DevToolsPluginState extends State<DevToolsPlugin> {
  @override
  void initState() {
    super.initState();
    _pluginManager = PluginManager()
      ..init(connectToVmService: widget.requiresRunningApplication);
    for (final handler in widget.eventHandlers.entries) {
      _pluginManager.registerEventHandler(handler.key, handler.value);
    }
  }

  @override
  void dispose() {
    _pluginManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
