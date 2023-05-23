// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../primitives/auto_dispose.dart';
import '../plugins_model.dart';
import '_controller_desktop.dart' if (dart.library.html) '_controller_web.dart';

EmbeddedPluginControllerImpl createEmbeddedPluginController(
  ValueListenable<DevToolsPluginConfig?> selectedPluginNotifier,
) {
  return EmbeddedPluginControllerImpl(selectedPluginNotifier);
}

abstract class EmbeddedPluginController extends DisposableController {
  void init() {}

  void postMessage(String message) {}
}
