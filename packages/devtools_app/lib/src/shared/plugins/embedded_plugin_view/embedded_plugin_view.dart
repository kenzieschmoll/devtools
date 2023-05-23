// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '_view_desktop.dart' if (dart.library.html) '_view_web.dart';
import 'embedded_plugin_controller.dart';

class EmbeddedPluginView extends StatelessWidget {
  const EmbeddedPluginView({Key? key, required this.pluginController})
      : super(key: key);

  final EmbeddedPluginController pluginController;

  @override
  Widget build(BuildContext context) {
    return EmbeddedPlugin(
      pluginName: 'plugin name',
      controller: pluginController,
    );
  }
}
