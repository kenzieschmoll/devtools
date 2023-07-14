// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

// TODO: this is duplicated (sort of) in devtools_server; find a way to share.
class DevToolsPluginConfig {
  DevToolsPluginConfig._({
    required this.name,
    required this.path,
    required this.issueTrackerLink,
    required this.version,
    required this.materialIconCodePoint,
  });

  factory DevToolsPluginConfig.parse(Map<String, Object?> json) {
    // Defaults to the code point for [Icons.extensions_outlined] if null.
    final codePoint = json[materialIconCodePointKey] as int? ?? 0xf03f;
    return DevToolsPluginConfig._(
      name: json[nameKey]! as String,
      path: json[pathKey]! as String,
      issueTrackerLink: json[issueTrackerKey]! as String,
      version: json[versionKey]! as String,
      materialIconCodePoint: codePoint,
    );
  }

  static const nameKey = 'name';
  static const pathKey = 'path';
  static const issueTrackerKey = 'issueTracker';
  static const versionKey = 'version';
  static const materialIconCodePointKey = 'materialIconCodePoint';

  final String name;
  final String path;
  final String issueTrackerLink;
  final String version;
  final int materialIconCodePoint;

  Map<String, Object?> toJson() => {
        nameKey: name,
        pathKey: path,
        issueTrackerKey: issueTrackerLink,
        versionKey: version,
        materialIconCodePointKey: materialIconCodePoint,
      };
}

extension PluginExtension on DevToolsPluginConfig {
  IconData get icon => IconData(
        materialIconCodePoint,
        fontFamily: 'MaterialIcons',
      );
}

// TODO do not check in
final List<DevToolsPluginConfig> debugPlugins = [
  // DevToolsPlugin(
  //   indexLocation: 'foo/location/index.html',
  //   config:

  DevToolsPluginConfig.parse({
    DevToolsPluginConfig.nameKey: 'foo',
    DevToolsPluginConfig.issueTrackerKey: 'www.google.com',
    DevToolsPluginConfig.versionKey: '1.0.0',
    DevToolsPluginConfig.pathKey: '/path/to/foo',
  }),
  // ),
  // DevToolsPlugin(
  // indexLocation: 'bar/location/index.html',
  // config:
  DevToolsPluginConfig.parse({
    DevToolsPluginConfig.nameKey: 'bar',
    DevToolsPluginConfig.issueTrackerKey: 'www.google.com',
    DevToolsPluginConfig.versionKey: '2.0.0',
    DevToolsPluginConfig.materialIconCodePointKey: 0xe638,
    DevToolsPluginConfig.pathKey: '/path/to/bar',
  }),
  // ),
  // DevToolsPluginConfig(
  //   indexLocation: 'provider/location/index.html',
  //   config:
  DevToolsPluginConfig.parse({
    DevToolsPluginConfig.nameKey: 'provider',
    DevToolsPluginConfig.issueTrackerKey:
        'https://github.com/rrousselGit/provider/issues',
    DevToolsPluginConfig.versionKey: '3.0.0',
    DevToolsPluginConfig.materialIconCodePointKey: 0xe50a,
    DevToolsPluginConfig.pathKey: '/path/to/provider',
  }),
  // ),
];
