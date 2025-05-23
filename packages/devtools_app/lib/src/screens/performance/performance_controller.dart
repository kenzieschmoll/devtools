// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport 'tabbed_performance_view.dart';
library;

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/service_registrations.dart' as registrations;
import '../../shared/diagnostics/inspector_service.dart';
import '../../shared/feature_flags.dart';
import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';
import '../../shared/offline/offline_data.dart';
import 'panes/controls/enhance_tracing/enhance_tracing_controller.dart';
import 'panes/flutter_frames/flutter_frame_model.dart';
import 'panes/flutter_frames/flutter_frames_controller.dart';
import 'panes/rebuild_stats/rebuild_stats_controller.dart';
import 'panes/rebuild_stats/rebuild_stats_model.dart';
import 'panes/timeline_events/timeline_events_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';

/// Screen controller for the Performance screen.
///
/// This controller manages the performance data model and feature controllers,
/// which handle things like data processing and communication with the view
/// to give and receive data updates.
///
/// This controller can be accessed from anywhere in DevTools, as long as it was
/// first registered, by
/// calling `screenControllers.lookup<PerformanceController>()`.
///
/// The controller lifecycle is managed by the [ScreenControllers] class. The
/// `init` method is called lazily upon the first controller access from
/// `screenControllers`. The `dispose` method is called by `screenControllers`
/// when DevTools is destroying a set of DevTools screen controllers.
class PerformanceController extends DevToolsScreenController
    with
        AutoDisposeControllerMixin,
        OfflineScreenControllerMixin<OfflinePerformanceData> {
  @override
  final screenId = ScreenMetaData.performance.id;

  late final FlutterFramesController flutterFramesController;

  late final TimelineEventsController timelineEventsController;

  late final RebuildStatsController rebuildStatsController;

  late List<PerformanceFeatureController> _featureControllers;

  // TODO(jacobr): add the recount controller to [_featureControllers] once your
  // PR for rebuild indicators lands
  //(https://github.com/flutter/devtools/pull/4566).
  final rebuildCountModel = RebuildCountModel();

  /// Index of the selected feature tab.
  ///
  /// This value is used to set the initial tab selection of the
  /// [TabbedPerformanceView]. This widget will be disposed and re-initialized
  /// on DevTools screen changes, so we must store this value in the controller
  /// instead of the widget state.
  int selectedFeatureTabIndex = 0;

  bool _fetchMissingLocationsStarted = false;
  IsolateRef? _currentRebuildWidgetsIsolate;

  final enhanceTracingController = EnhanceTracingController();

  /// Performance screen data loaded via import.
  ///
  /// This is expected to be null when we are not in
  /// [OfflineDataController.showingOfflineData].
  ///
  /// This will contain the original data from the imported file, regardless of
  /// any selection modifications that occur while the data is displayed.
  OfflinePerformanceData? offlinePerformanceData;

  ValueListenable<bool> get impellerEnabled => _impellerEnabled;
  final _impellerEnabled = ValueNotifier<bool>(false);

  Future<void> get initialized => _initialized.future;
  final _initialized = Completer<void>();

  @override
  void init() {
    super.init();
    // TODO(https://github.com/flutter/devtools/issues/5100): clean this up to
    // only create a controller when it is needed,
    flutterFramesController = FlutterFramesController(this);
    timelineEventsController = TimelineEventsController(this);
    rebuildStatsController = RebuildStatsController(this);
    _featureControllers = [
      flutterFramesController,
      timelineEventsController,
      rebuildStatsController,
    ];

    if (serviceConnection.serviceManager.connectedApp?.isDartWebAppNow ??
        false) {
      // Do not perform initialization for web apps.
      return;
    }

    unawaited(_init());
  }

  Future<void> _init() async {
    await _initHelper();
    _initialized.complete();
  }

  Future<void> _initHelper() async {
    await _applyToFeatureControllersAsync((c) => c.init());
    if (!offlineDataController.showingOfflineData.value) {
      await serviceConnection.serviceManager.onServiceAvailable;

      if (serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ??
          false) {
        // Do not await this future because this will hang if the app is paused
        // upon connection.
        unawaited(
          serviceConnection.serviceManager
              .callServiceExtensionOnMainIsolate(
                registrations.isImpellerEnabled,
              )
              .then((response) {
                _impellerEnabled.value = response.json?['enabled'] == true;
              }),
        );
      } else {
        _impellerEnabled.value = false;
      }

      enhanceTracingController.init();

      // Listen for Flutter.Frame events with frame timing data.
      // Listen for Flutter.RebuiltWidgets events.
      autoDisposeStreamSubscription(
        serviceConnection
            .serviceManager
            .service!
            .onExtensionEventWithHistorySafe
            .listen((event) {
              if (event.extensionKind == FlutterEvent.frame) {
                final frame = FlutterFrame.fromJson(event.extensionData!.data);
                enhanceTracingController.assignStateForFrame(frame);
                flutterFramesController.addFrame(frame);
              } else if (event.extensionKind == FlutterEvent.rebuiltWidgets) {
                if (_currentRebuildWidgetsIsolate != event.isolate) {
                  rebuildCountModel.clearFromRestart();
                }
                _currentRebuildWidgetsIsolate = event.isolate;
                // TODO(jacobr): need to make sure we don't get events from before
                // the last hot restart. Their data would be bogus.
                rebuildCountModel.processRebuildEvent(
                  event.extensionData!.data,
                );
                if (!rebuildCountModel.locationMap.locationsResolved.value &&
                    !_fetchMissingLocationsStarted) {
                  _fetchMissingRebuildLocations();
                }
              }
            }),
      );
    } else {
      await maybeLoadOfflineData(
        PerformanceScreen.id,
        // TODO(kenz): make sure DevTools exports can be loaded into the full
        // Perfetto trace viewer (ui.perfetto.dev).
        createData: (json) => OfflinePerformanceData.fromJson(json),
        shouldLoad: (data) => !data.isEmpty,
        loadData: _loadOfflineData,
      );
    }
  }

  Future<void> _loadOfflineData(OfflinePerformanceData data) async {
    await clearData();
    offlinePerformanceData = data;
    await _applyToFeatureControllersAsync(
      (c) => c.setOfflineData(offlinePerformanceData!),
    );
  }

  void _fetchMissingRebuildLocations() async {
    if (_fetchMissingLocationsStarted) return;
    // Some locations are missing. This occurs if rebuilds were
    // enabled before DevTools connected because rebuild events only
    // include locations that have not yet been sent with an event.
    _fetchMissingLocationsStarted = true;
    final inspectorService =
        serviceConnection.inspectorService! as InspectorService;
    final expectedIsolate = _currentRebuildWidgetsIsolate;
    final json = await inspectorService.widgetLocationIdMap();
    // Don't apply the json if the isolate has been restarted
    // while we were waiting for a response.
    if (_currentRebuildWidgetsIsolate == expectedIsolate) {
      // It is strange if unresolved Locations have resolved on their
      // own. This wouldn't be a big deal but suggests a logic bug
      // somewhere.
      assert(!rebuildCountModel.locationMap.locationsResolved.value);
      rebuildCountModel.locationMap.processLocationMap(json);
      // Only one call to fetch missing locations should ever be
      // needed as rebuild events include all associated locations.
      assert(rebuildCountModel.locationMap.locationsResolved.value);
    }
  }

  /// Calls [callback] for each feature controller in [_featureControllers].
  ///
  /// [callback] can return a [Future] or a [FutureOr]
  void _applyToFeatureControllers(
    void Function(PerformanceFeatureController) callback,
  ) {
    _featureControllers.forEach(callback);
  }

  /// Calls [callback] for each feature controller in [_featureControllers].
  ///
  /// [callback] can return a [Future] or a [FutureOr]
  Future<void> _applyToFeatureControllersAsync(
    FutureOr<void> Function(PerformanceFeatureController) callback,
  ) async {
    Future<void> helper(
      FutureOr<void> Function(PerformanceFeatureController) futureOr,
      PerformanceFeatureController controller,
    ) async {
      await futureOr(controller);
    }

    await [
      for (final controller in _featureControllers)
        helper(callback, controller),
    ].wait;
  }

  Future<void> setActiveFeature(
    PerformanceFeatureController? featureController,
  ) async {
    await _applyToFeatureControllersAsync(
      (c) async => await c.setIsActiveFeature(
        featureController != null && c == featureController,
      ),
    );
  }

  /// Clears the timeline data currently stored by the controller as well the
  /// VM timeline if a connected app is present.
  Future<void> clearData({
    bool partial = false,
    bool clearVmTimeline = true,
  }) async {
    if (serviceConnection.serviceManager.connectedAppInitialized &&
        clearVmTimeline) {
      await serviceConnection.serviceManager.service!.clearVMTimeline();
    }
    offlinePerformanceData = null;
    serviceConnection.errorBadgeManager.clearErrorCount(PerformanceScreen.id);
    await _applyToFeatureControllersAsync((c) => c.clearData(partial: partial));
  }

  @override
  void dispose() {
    _applyToFeatureControllers((c) => c.dispose());
    enhanceTracingController.dispose();
    rebuildCountModel.dispose();
    _impellerEnabled.dispose();
    super.dispose();
  }

  @override
  OfflineScreenData prepareOfflineScreenData() => OfflineScreenData(
    screenId: PerformanceScreen.id,
    data: OfflinePerformanceData(
      perfettoTraceBinary: timelineEventsController.fullPerfettoTrace,
      frames: flutterFramesController.flutterFrames.value,
      selectedFrame: flutterFramesController.selectedFrame.value,
      rebuildCountModel: rebuildCountModel,
      displayRefreshRate: flutterFramesController.displayRefreshRate.value,
    ).toJson(),
  );

  @override
  FutureOr<void> releaseMemory({bool partial = false}) async {
    if (FeatureFlags.memoryObserver) {
      await clearData(partial: partial, clearVmTimeline: !partial);
    }
  }
}

abstract class PerformanceFeatureController extends DisposableController {
  PerformanceFeatureController(this.performanceController);

  final PerformanceController performanceController;

  /// Whether this feature is active and visible to the user.
  bool get isActiveFeature => _isActiveFeature;
  bool _isActiveFeature = false;

  Future<void> setIsActiveFeature(bool value) async {
    // Before allowing any feature controller to become "active", verify that
    // the [performanceController] has completed initializing.
    await performanceController.initialized;
    _isActiveFeature = value;
    if (value) {
      onBecomingActive();
    }
  }

  void onBecomingActive();

  Future<void> setOfflineData(OfflinePerformanceData offlineData);

  FutureOr<void> clearData({bool partial = false});

  void handleSelectedFrame(FlutterFrame frame);
}
