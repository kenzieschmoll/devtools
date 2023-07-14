// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'embedded_plugin_controller.dart';

class EmbeddedPlugin extends StatelessWidget {
  const EmbeddedPlugin({
    super.key,
    required this.pluginName,
    required this.controller,
  });

  final String pluginName;
  final EmbeddedPluginController controller;

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): if web view support for desktop is ever added, use that here.
    return const Center(
      child: Text(
        'Cannot display the DevTools plugin.'
        ' IFrames are not supported on desktop platforms.',
      ),
    );
  }
}
