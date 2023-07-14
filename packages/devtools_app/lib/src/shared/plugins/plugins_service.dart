// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../globals.dart';
import '../server_api_client.dart';
import 'plugins_model.dart';

class PluginsService {
  PluginsService(this.serverConnection);

  final DevToolsServerConnection? serverConnection;

  final availablePlugins = <DevToolsPluginConfig>[];

  Future<void> initialize() async {
    if (serverConnection == null) return;

    // TODO(kenz): put this work to fetch the root lib into a helper somewhere.
    // We duplicate this work in several places in DevTools.
    final selectedIsolateRef =
        serviceManager.isolateManager.mainIsolate.value?.id;
    if (selectedIsolateRef == null) return;

    final selectedIsolate =
        await serviceManager.service!.getIsolate(selectedIsolateRef);
    final rootLib = selectedIsolate.rootLib?.uri;
    if (rootLib == null) return;

    await serviceManager.resolvedUriManager
        .fetchFileUris(selectedIsolateRef, [rootLib]);
    var fileUri = serviceManager.resolvedUriManager.lookupFileUri(
      selectedIsolateRef,
      rootLib,
    );
    if (fileUri == null) return;

    // TODO(kenz): this is messy. Find another way to clean up this path
    if (fileUri.startsWith('file:///Users')) {
      fileUri = fileUri.replaceFirst('file:///', '/');
    }
    if (fileUri.endsWith('/lib/main.dart')) {
      fileUri = fileUri.replaceFirst('/lib/main.dart', '');
    }

    final rootPaths = [fileUri];
    await _refreshAvailablePlugins(rootPaths);
  }

  Future<void> vmServiceClosed() async {
    await _refreshAvailablePlugins([]);
  }

  // TODO: we should also refresh the available plugins on some event from the
  // analysis server that is watching the .dart_tool/package_config.json file.
  Future<void> _refreshAvailablePlugins(List<String> rootPaths) async {
    final plugins = await serverConnection!.refreshAvailablePlugins(rootPaths);
    availablePlugins
      ..clear()
      ..addAll(plugins);
  }
}
