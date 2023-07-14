// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'api.dart';

class DevToolsPluginEvent {
  DevToolsPluginEvent(this.type, {this.data});

  factory DevToolsPluginEvent.parse(Map<String, Object?> json) {
    final eventType = DevToolsPluginEventType.from(json[_typeKey]! as String);
    final data = (json[_dataKey] as Map?)?.cast<String, Object?>();
    return DevToolsPluginEvent(eventType, data: data);
  }

  static DevToolsPluginEvent? tryParse(Object data) {
    try {
      final dataAsMap = (data as Map).cast<String, Object?>();
      return DevToolsPluginEvent.parse(dataAsMap);
    } catch (_) {
      return null;
    }
  }

  static const _typeKey = 'type';
  static const _dataKey = 'data';

  static DevToolsPluginEvent ping =
      DevToolsPluginEvent(DevToolsPluginEventType.ping);

  static DevToolsPluginEvent pong =
      DevToolsPluginEvent(DevToolsPluginEventType.pong);

  final DevToolsPluginEventType type;

  final Map<String, Object?>? data;

  Map<String, Object?> toJson() {
    return {
      _typeKey: type.name,
      if (data != null) _dataKey: data!,
    };
  }
}

typedef PluginEventHandler = void Function(DevToolsPluginEvent event);