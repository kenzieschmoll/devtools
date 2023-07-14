// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../shared/globals.dart';
import '../../shared/plugins/embedded_plugin_view/embedded_plugin_controller.dart';
import '../../shared/plugins/plugins_model.dart';
import '../../shared/primitives/utils.dart';

class PluginsScreenController {
  PluginsScreenController() {
    _selectedPluginNotifier.value = plugins.safeFirst;
    pluginWebViewController = createEmbeddedPluginController(
      selectedPluginNotifier,
    )..init();
  }

  late final EmbeddedPluginController pluginWebViewController;

  List<DevToolsPluginConfig> get plugins => pluginsManager.availablePlugins;

  ValueListenable<DevToolsPluginConfig?> get selectedPluginNotifier =>
      _selectedPluginNotifier;
  final _selectedPluginNotifier = ValueNotifier<DevToolsPluginConfig?>(null);

  ValueListenable<int> get selectedPluginIndex => _selectedPluginIndex;
  final _selectedPluginIndex = ValueNotifier<int>(0);

  void selectPluginAtIndex(int index) {
    _selectedPluginIndex.value = index;
    _selectedPluginNotifier.value = plugins.safeGet(_selectedPluginIndex.value);
  }
}
