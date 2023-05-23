// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum DevToolsPluginEventType {
  ping,
  pong,
  connectedVmService,
  // TODO: remove
  testEvent,
  unknown;

  static DevToolsPluginEventType from(String name) {
    for (final event in DevToolsPluginEventType.values) {
      if (event.name == name) {
        return event;
      }
    }
    return unknown;
  }
}
