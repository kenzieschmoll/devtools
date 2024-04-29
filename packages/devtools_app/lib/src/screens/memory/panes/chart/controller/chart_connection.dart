// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../shared/primitives/memory_timeline.dart';
import '../data/primitives.dart';
import 'memory_tracker.dart';

/// Connection between chart and application.
///
/// The connection consists of listeners to events from vm and
/// ongoing requests to vm service for current memory usage.
///
/// When user pauses the chart, the data is still collected.
///
/// Does not fail in case of accidental disconnect.
///
/// All interactions between chart and vm are initiated by this class.
/// So, if this class is not instantiated, the interaction does not happen.
class ChartConnection extends DisposableController
    with AutoDisposeControllerMixin {
  ChartConnection(this.timeline, {required this.isAndroidChartVisible});

  final MemoryTimeline timeline;
  final ValueListenable<bool> isAndroidChartVisible;

  late final MemoryTracker _memoryTracker = MemoryTracker(
    timeline,
    isAndroidChartVisible: isAndroidChartVisible,
  );

  Timer? _pollingTimer;

  bool _initialized = false;

  late final bool isDeviceAndroid;

  Future<void> maybeInitialize() async {
    if (_initialized) return;
    await serviceConnection.serviceManager.onServiceAvailable;

    // This should be initialized once we are sure that a VM service connection
    // is available and initialized in the service manager.
    isDeviceAndroid =
        serviceConnection.serviceManager.vm?.operatingSystem == 'android';

    cancelStreamSubscriptions();
    cancelListeners();

    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      final connected =
          serviceConnection.serviceManager.connectedState.value.connected;
      if (!connected) {
        _pollingTimer?.cancel();
      }
    });
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onExtensionEvent
          .listen(_memoryTracker.onMemoryData),
    );
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onGCEvent
          .listen(_memoryTracker.onGCEvent),
    );
    await _startPolling();
    _initialized = true;
  }

  Future<void> _startPolling() async {
    await _memoryTracker.pollMemory();
    _pollingTimer = Timer.periodic(
      chartUpdateDelay,
      (_) => unawaited(_memoryTracker.pollMemory()),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    super.dispose();
  }
}
