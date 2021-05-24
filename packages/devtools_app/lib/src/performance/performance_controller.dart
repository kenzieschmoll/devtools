// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../auto_dispose.dart';
import '../config_specific/import_export/import_export.dart';
import '../config_specific/logger/allowed_error.dart';
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../http/http_service.dart';
import '../profiler/cpu_profile_controller.dart';
import '../profiler/cpu_profile_service.dart';
import '../profiler/cpu_profile_transformer.dart';
import '../profiler/profile_granularity.dart';
import '../service_manager.dart';
import '../trace_event.dart';
import '../trees.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'performance_model.dart';
import 'performance_screen.dart';
import 'performance_utils.dart';
import 'timeline_event_processor.dart';
import 'timeline_streams.dart';

// TODOs data timing based off of frames or timeline events? maybe make frame data
// event data, and cpu profile data three different things?
// show toast when we select a frame for which we don't have events
// highlight refresh button when new events are available? poll for new timeline
// events?
// make sure export exports frames json. make sure import works.
// tooltips not working for frame bars?
// selected frame painters? find first event on UI thread at timestamp

/// This class contains the business logic for [performance_screen.dart].
///
/// The controller manages the timeline data model and communicates with the
/// view to give and receive data updates. It also manages data processing via
/// [TimelineEventProcessor] and [CpuProfileTransformer].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class PerformanceController implements DisposableController {
  PerformanceController() {
    _init();
  }

  final flutterFramesController = FlutterFramesController();
  final timelineController = TimelineController();
  final performanceCpuProfilerController = PerformanceCpuProfilerController();

  final _exportController = ExportController();

<<<<<<< Updated upstream
  /// The currently selected timeline event.
  ValueListenable<TimelineEvent> get selectedTimelineEvent =>
      _selectedTimelineEventNotifier;
  final _selectedTimelineEventNotifier = ValueNotifier<TimelineEvent>(null);
=======
  /// Whether the timeline is currently being recorded.
  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  /// Performance data loaded via import.
  ///
  /// This is expected to be null when we are not in [offlineMode].
  ///
  /// This will contain the original data from the imported file, regardless of
  /// any selection modifications that occur while the data is displayed.
  OfflinePerformanceData offlinePerformanceData;
>>>>>>> Stashed changes

  Future<void> _initialized;
  Future<void> get initialized => _initialized;

  Future<void> _init() {
    return _initialized = _initHelper();
  }

  Future<void> _initHelper() async {
    await serviceManager.onServiceAvailable;

    performanceCpuProfilerController.init();
    await Future.wait([
      flutterFramesController.init(),
      timelineController.init(),
    ]);
  }

  Future<void> selectTimelineEvent(TimelineEvent event) async {
    if (timelineController.selectedTimelineEvent.value == event) return;
    print('selecting event ${event.time}');
    timelineController.selectTimelineEvent(event);
    await performanceCpuProfilerController.updateForSelectedEvent(event);
  }

  // Future<void> refreshData() async {
  //   // Cache flutter frame related data and reset after clearing.
  //   final currentFrames =
  //       List<FlutterFrame2>.from(data?.frames ?? _pendingFlutterFrames);
  //   final selectedFrame = data?.selectedFrame;
  //
  //   await clearData(clearVmTimeline: false);
  //
  //   data = PerformanceData(displayRefreshRate: _displayRefreshRate.value)
  //     ..frames = currentFrames
  //     ..selectedFrame = selectedFrame;
  // }

  FutureOr<void> processOfflineData(OfflinePerformanceData offlineData) async {
    await clearData();

    flutterFramesController.initDataFromOffline(offlineData);
    await timelineController.initDataFromOffline(offlineData);
    await performanceCpuProfilerController.initDataFromOffline(offlineData);
  }

  /// Exports the current timeline data to a .json file.
  ///
  /// This method returns the name of the file that was downloaded.
  String exportData() {
    final encodedData = _exportController.encode(PerformanceScreen.id, json);
    return _exportController.downloadFile(encodedData);
  }

  /// Clears the timeline data currently stored by the controller.
  ///
  /// [clearVmTimeline] defaults to true, but should be set to false if you want
  /// to clear the data stored by the controller, but do not want to clear the
  /// data currently stored by the VM.
  Future<void> clearData({bool clearVmTimeline = true}) async {
    if (clearVmTimeline && serviceManager.hasConnection) {
      await serviceManager.service.clearVMTimeline();
      flutterFramesController.clear();
    }
    // offlinePerformanceData = null;
    timelineController.clear();
    performanceCpuProfilerController.cpuProfilerController.reset();
    serviceManager.errorBadgeManager.clearErrors(PerformanceScreen.id);
  }

  @override
  void dispose() {
    flutterFramesController.dispose();
    timelineController.dispose();
    performanceCpuProfilerController.dispose();
  }

  Map<String, dynamic> get json => {
        ...flutterFramesController.json,
        ...timelineController.json,
        ...performanceCpuProfilerController.json,
      };
}

/// Controller Flutter frames data on the performance page.
class FlutterFramesController implements DisposableController {
  static const framesKey = 'frames';

  static const displayRefreshRateKey = 'displayRefreshRate';

  static const selectedFrameIdKey = 'selectedFrameId';

  /// The flutter frames available.
  ///
  /// These are populated from Flutter.Frame events sent over the service
  /// extension stream.
  ValueListenable<List<FlutterFrame>> get flutterFrames => _flutterFrames;
  final _flutterFrames = ListValueNotifier<FlutterFrame>([]);

  /// The currently selected timeline frame.
  ValueListenable<FlutterFrame> get selectedFrame => _selectedFrame;
  final _selectedFrame = ValueNotifier<FlutterFrame>(null);

  /// Whether flutter frames are currently being recorded.
  ValueListenable<bool> get recordingFrames => _recordingFrames;
  final _recordingFrames = ValueNotifier<bool>(true);

  /// Frames that have been recorded but not shown because the flutter frame
  /// recording has been paused.
  final _pendingFlutterFrames = <FlutterFrame>[];

  StreamSubscription flutterFrameStream;

  ValueListenable<double> get displayRefreshRate => _displayRefreshRate;
  final _displayRefreshRate = ValueNotifier<double>(defaultRefreshRate);

  /// Whether we should add a red badge to the Performance tab when a janky
  /// frame is detected.
  ///
  /// This value is modifiable from the Performance page settings dialog.
  ValueListenable<bool> get badgeTabForJankyFrames => _badgeTabForJankyFrames;
  final _badgeTabForJankyFrames = ValueNotifier<bool>(false);

  int get selectedFrameId => selectedFrame.value?.id;

  Future<void> init() async {
    // Default to true for profile builds only.
    _badgeTabForJankyFrames.value =
        await serviceManager.connectedApp.isProfileBuild;

    // Initialize displayRefreshRate.
    _displayRefreshRate.value =
        await serviceManager.queryDisplayRefreshRate ?? defaultRefreshRate;

    flutterFrameStream =
        serviceManager.service.onExtensionEventWithHistory.listen((event) {
      if (event.extensionKind == 'Flutter.Frame') {
        final frame = FlutterFrame.parse(event.extensionData.data);
        if (_recordingFrames.value) {
          addFrame(frame);
        } else {
          _pendingFlutterFrames.add(frame);
        }
      }
    });
  }

  void addFrame(FlutterFrame frame) {
    if (_pendingFlutterFrames.isNotEmpty) {
      _addPendingFlutterFrames();
    }
    _maybeBadgeTabForJankyFrame(frame);
    _flutterFrames.add(frame);
  }

  void _addPendingFlutterFrames({bool notify = false}) {
    _pendingFlutterFrames.forEach(_maybeBadgeTabForJankyFrame);
    if (notify) {
      _flutterFrames.addAll(_pendingFlutterFrames);
    } else {
      _flutterFrames.value.addAll(_pendingFlutterFrames);
    }
    _pendingFlutterFrames.clear();
  }

  void selectFrame(FlutterFrame frame) {
    print('selecting frame: ${frame.time}');
    _selectedFrame.value = frame;
  }

  void toggleRecordingFrames(bool recording) {
    _recordingFrames.value = recording;
    if (_recordingFrames.value) {
      _addPendingFlutterFrames(notify: true);
    }
  }

  void _maybeBadgeTabForJankyFrame(FlutterFrame frame) {
    if (_badgeTabForJankyFrames.value) {
      if (frame.isJanky(_displayRefreshRate.value)) {
        serviceManager.errorBadgeManager
            .incrementBadgeCount(PerformanceScreen.id);
      }
    }
  }

  void clear() {
    _flutterFrames.clear();
    _selectedFrame.value = null;
    _pendingFlutterFrames.clear();
  }

  void initDataFromOffline(OfflinePerformanceData offlineData) {
    _flutterFrames
      ..clear()
      ..addAll(offlineData.frames);
    final frameToSelect = offlineData.frames.firstWhere(
      (frame) => frame.id == offlineData.selectedFrameId,
      orElse: () => null,
    );
    if (frameToSelect != null) {
      _selectedFrame.value = frameToSelect;
    }
  }

  Map<String, dynamic> get json => {
        framesKey: _flutterFrames.value.map((f) => f.json).toList(),
        selectedFrameIdKey: _selectedFrame.value?.id,
        displayRefreshRateKey: displayRefreshRate.value,
      };

  @override
  void dispose() {
    flutterFrameStream.cancel();
  }
}

/// Controller for Timeline data on the performance page.
class TimelineController extends DisposableController
    with SearchControllerMixin<TimelineEvent>, AutoDisposeControllerMixin {
  TimelineController() {
    processor = TimelineEventProcessor(this);
  }
  static const traceEventsKey = 'traceEvents';

  static const selectedEventKey = 'selectedEvent';

  static const uiKey = 'UI';

  static const rasterKey = 'Raster';

  static const gcKey = 'GC';

  static const unknownKey = 'Unknown';

  TimelineEventProcessor processor;

  /// Trace events in the current timeline.
  List<TraceEventWrapper> traceEvents = [];

  bool get isDataEmpty => traceEvents.isEmpty;

  /// Trace events that have been collected but have not yet been processed into
  /// timeline events [timelineEvents].
  List<TraceEventWrapper> unprocessedTraceEvents = [];

  /// Timeline events that have been processed.
  ///
  /// This may not include all of the trace events that have been collected.
  /// Some may be unprocessed and sitting in [unprocessedTraceEvents].
  ValueListenable<List<TimelineEvent>> get timelineEvents => _timelineEvents;
  final _timelineEvents = ListValueNotifier<TimelineEvent>(<TimelineEvent>[]);

  final SplayTreeMap<String, TimelineEventGroup> eventGroups =
      SplayTreeMap(eventGroupComparator);

  /// The currently selected timeline event.
  ValueListenable<TimelineEvent> get selectedTimelineEvent =>
      _selectedTimelineEvent;
  final _selectedTimelineEvent = ValueNotifier<TimelineEvent>(null);

  /// Whether the recorded timeline data is currently being processed.
  ValueListenable<bool> get processing => _processing;
  final _processing = ValueNotifier<bool>(false);

  // TODO(jacobr): this isn't accurate. Another page of DevTools
  // or a different instance of DevTools could change this value. We need to
  // sync the value with the server like we do for other vm service extensions
  // that we track with the vm service extension manager.
  // See https://github.com/dart-lang/sdk/issues/41823.
  /// Whether http timeline logging is enabled.
  ValueListenable<bool> get httpTimelineLoggingEnabled =>
      _httpTimelineLoggingEnabled;
  final _httpTimelineLoggingEnabled = ValueNotifier<bool>(false);

  /// Whether the displayed timeline data is stale.
  ValueListenable<bool> get staleData => _staleData;
  final _staleData = ValueNotifier<bool>(false);

  TimeRange time = TimeRange(singleAssignment: false);

  // TODO(kenz): switch to use VmFlagManager-like pattern once
  // https://github.com/dart-lang/sdk/issues/41822 is fixed.
  /// Recorded timeline stream values.
  final recordedStreams = [
    dartTimelineStream,
    embedderTimelineStream,
    gcTimelineStream,
    apiTimelineStream,
    compilerTimelineStream,
    compilerVerboseTimelineStream,
    debuggerTimelineStream,
    isolateTimelineStream,
    vmTimelineStream,
  ];

  final threadNamesById = <int, String>{};
<<<<<<< Updated upstream

  /// Active timeline data.
  ///
  /// This is the true source of data for the UI. In the case of an offline
  /// import, this will begin as a copy of [offlinePerformanceData] (the original
  /// data from the imported file). If any modifications are made while the data
  /// is displayed (e.g. change in selected timeline event, selected frame,
  /// etc.), those changes will be tracked here.
  PerformanceData data;

  /// Timeline data loaded via import.
  ///
  /// This is expected to be null when we are not in [offlineMode].
  ///
  /// This will contain the original data from the imported file, regardless of
  /// any selection modifications that occur while the data is displayed. [data]
  /// will start as a copy of offlineTimelineData in this case, and will track
  /// any data modifications that occur while the data is displayed (e.g. change
  /// in selected timeline event, selected frame, etc.).
  PerformanceData offlinePerformanceData;
=======
>>>>>>> Stashed changes

  /// The end timestamp for the data in this timeline.
  ///
  /// Track it here so that we can cache the value as we add timeline events,
  /// and eventually set [time.end] to this value after the data is processed.
  int get endTimestampMicros => _endTimestampMicros;
  int _endTimestampMicros = -1;

<<<<<<< Updated upstream
    unawaited(allowedError(
      serviceManager.service.setProfilePeriod(mediumProfilePeriod),
      logError: false,
    ));
=======
  Future<void> init() async {
>>>>>>> Stashed changes
    await setTimelineStreams([
      dartTimelineStream,
      embedderTimelineStream,
      gcTimelineStream,
    ]);
    await toggleHttpRequestLogging(true);

    // Request all available timeline events.
    final timeline = await serviceManager.service.getVMTimeline();
    primeThreadIds(timeline);

    _processing.value = true;
    await processor.processTimeline(
      timeline.traceEvents
          .map((e) => TraceEventWrapper(
                TraceEvent(e.json),
                DateTime.now().millisecondsSinceEpoch,
              ))
          .toList(),
      firstProcess: true,
    );
    initializeEventGroups();
    _processing.value = false;

    autoDispose(serviceManager.service.onTimelineEvent.listen((event) {
      final eventBatch = <TraceEventWrapper>[];
      if (event.json['kind'] == 'TimelineEvents') {
        final List<dynamic> traceEvents = event.json['timelineEvents']
            .map(
              (e) => TraceEventWrapper(
                TraceEvent(e),
                DateTime.now().millisecondsSinceEpoch,
              ),
            )
            .toList();
        final List<TraceEventWrapper> wrappedTraceEvents =
            traceEvents.cast<TraceEventWrapper>();
        eventBatch.addAll(wrappedTraceEvents);
      }
      unprocessedTraceEvents.addAll(eventBatch);
      _staleData.value = true;
    }));
  }

  FutureOr<void> processAvailableEvents() async {
    final lastProcessedTimelineEventIndex = _timelineEvents.value.length - 1;
    print(
        'in processAvailableEvents and lastProcessedTimelineEventIndex = $lastProcessedTimelineEventIndex');
    final unprocessed = List<TraceEventWrapper>.from(unprocessedTraceEvents);
    print('unprocessed events: ${unprocessed.length}');
    unprocessedTraceEvents.clear();

    _processing.value = true;
    await processor.processTimeline(unprocessed);
    initializeEventGroups(startIndex: lastProcessedTimelineEventIndex + 1);
    _processing.value = false;
    print('done processing available events');
    _staleData.value = unprocessedTraceEvents.isEmpty;
  }

<<<<<<< Updated upstream
  ValueListenable<double> get displayRefreshRate => _displayRefreshRate;
  final _displayRefreshRate = ValueNotifier<double>(defaultRefreshRate);

  Future<void> toggleSelectedFrame(FlutterFrame frame) async {
    if (frame == null || data == null) {
      return;
    }

    // Unselect [frame] if is already selected.
    if (data.selectedFrame == frame) {
      data.selectedFrame = null;
      _selectedFrameNotifier.value = null;
      return;
    }

    data.selectedFrame = frame;
    _selectedFrameNotifier.value = frame;

    await selectTimelineEvent(frame.uiEventFlow);

    if (debugTimeline && frame != null) {
      final buf = StringBuffer();
      buf.writeln('UI timeline event for frame ${frame.id}:');
      frame.uiEventFlow.format(buf, '  ');
      buf.writeln('\nUI trace for frame ${frame.id}');
      frame.uiEventFlow.writeTraceToBuffer(buf);
      buf.writeln('\Raster timeline event frame ${frame.id}:');
      frame.rasterEventFlow.format(buf, '  ');
      buf.writeln('\nRaster trace for frame ${frame.id}');
      frame.rasterEventFlow.writeTraceToBuffer(buf);
      log(buf.toString());
=======
  void initializeEventGroups({int startIndex = 0}) {
    for (int i = startIndex; i < _timelineEvents.value.length; i++) {
      final event = _timelineEvents.value[i];
      eventGroups.putIfAbsent(computeEventGroupKey(event, threadNamesById),
          () => TimelineEventGroup())
        ..addEventAtCalculatedRow(event);
>>>>>>> Stashed changes
    }
  }

  void addTimelineEvent(TimelineEvent event, {bool notify = false}) {
    assert(event.isWellFormedDeep);
    _timelineEvents.add(event, notify: notify);
    _endTimestampMicros = math.max(_endTimestampMicros, event.maxEndMicros);
  }

  void selectTimelineEvent(TimelineEvent event) async {
    _selectedTimelineEvent.value = event;
  }

  void sortTimelineEventsAndNotify([
    Function(TimelineEvent a, TimelineEvent b) compare,
  ]) {
    _timelineEvents.sort(compare);
  }

  Future<void> toggleHttpRequestLogging(bool state) async {
    await HttpService.toggleHttpRequestLogging(state);
    _httpTimelineLoggingEnabled.value = state;
  }

  Future<void> setTimelineStreams(List<RecordedTimelineStream> streams) async {
    for (final stream in streams) {
      assert(recordedStreams.contains(stream));
      stream.toggle(true);
    }
    await serviceManager.service
        .setVMTimelineFlags(streams.map((s) => s.name).toList());
  }

  // TODO(kenz): this is not as robust as we'd like. Revisit once
  // https://github.com/dart-lang/sdk/issues/41822 is addressed.
  Future<void> toggleTimelineStream(RecordedTimelineStream stream) async {
    final newValue = !stream.enabled.value;
    final timelineFlags =
        (await serviceManager.service.getVMTimelineFlags()).recordedStreams;
    if (timelineFlags.contains(stream.name) && !newValue) {
      timelineFlags.remove(stream.name);
    } else if (!timelineFlags.contains(stream.name) && newValue) {
      timelineFlags.add(stream.name);
    }
    await serviceManager.service.setVMTimelineFlags(timelineFlags);
    stream.toggle(newValue);
  }

  void primeThreadIds(vm_service.Timeline timeline) {
    threadNamesById.clear();
    final threadNameEvents = timeline.traceEvents
        .map((event) => TraceEvent(event.json))
        .where((TraceEvent event) {
      return event.phase == 'M' && event.name == 'thread_name';
    }).toList();

    // TODO(kenz): Remove this logic once ui/raster distinction changes are
    // available in the engine.
    int uiThreadId;
    int rasterThreadId;
    for (TraceEvent event in threadNameEvents) {
      final name = event.args['name'];

      // Android: "1.ui (12652)"
      // iOS: "io.flutter.1.ui (12652)"
      // MacOS, Linux, Windows, Dream (g3): "io.flutter.ui (225695)"
      if (name.contains('.ui')) {
        uiThreadId = event.threadId;
      }

      // Android: "1.raster (12651)"
      // iOS: "io.flutter.1.raster (12651)"
      // Linux, Windows, Dream (g3): "io.flutter.raster (12651)"
      // MacOS: Does not exist
      // Also look for .gpu here for older versions of Flutter.
      // TODO(kenz): remove check for .gpu name in April 2021.
      if (name.contains('.raster') || name.contains('.gpu')) {
        rasterThreadId = event.threadId;
      }

      // Android: "1.platform (22585)"
      // iOS: "io.flutter.1.platform (22585)"
      // MacOS, Linux, Windows, Dream (g3): "io.flutter.platform (22596)"
      if (name.contains('.platform')) {
        // MacOS and Flutter apps with platform views do not have a .gpu thread.
        // In these cases, the "Raster" events will come on the .platform thread
        // instead.
        rasterThreadId ??= event.threadId;
      }

      threadNamesById[event.threadId] = name;
    }

    if (uiThreadId == null || rasterThreadId == null) {
      log('Could not find UI thread and / or Raster thread from names: '
          '${threadNamesById.values}');
    }

    processor.primeThreadIds(
      uiThreadId: uiThreadId,
      rasterThreadId: rasterThreadId,
    );
  }

  @override
  List<TimelineEvent> matchesForSearch(String search) {
    if (search?.isEmpty ?? true) return [];
    final matches = <TimelineEvent>[];
    for (final event in _timelineEvents.value) {
      breadthFirstTraversal<TimelineEvent>(event, action: (TimelineEvent e) {
        if (e.name.caseInsensitiveContains(search)) {
          matches.add(e);
        }
      });
    }
    return matches;
  }

<<<<<<< Updated upstream
  FutureOr<void> processTraceEvents(List<TraceEventWrapper> traceEvents) async {
    await processor.processTimeline(traceEvents);
    data.initializeEventGroups(threadNamesById);
    if (data.eventGroups.isEmpty) {
      _emptyTimeline.value = true;
=======
  // TODO(kenz): simplify this comparator if possible.
  @visibleForTesting
  static int eventGroupComparator(String a, String b) {
    if (a == b) return 0;

    // Order Unknown buckets last.
    if (a == unknownKey) return 1;
    if (b == unknownKey) return -1;

    // Order the Raster event bucket after the UI event bucket.
    if ((a == uiKey && b == rasterKey) || (a == rasterKey && b == uiKey)) {
      return -1 * a.compareTo(b);
>>>>>>> Stashed changes
    }

    // Order non-UI and non-raster buckets after the UI / Raster buckets.
    if (a == uiKey || a == rasterKey) return -1;
    if (b == uiKey || b == rasterKey) return 1;

    // Alphabetize all other buckets.
    return a.compareTo(b);
  }

  void clear() {
    traceEvents.clear();
    unprocessedTraceEvents.clear();
    _selectedTimelineEvent.value = null;
    _timelineEvents.clear();
    eventGroups.clear();
    time = TimeRange(singleAssignment: false);
    _endTimestampMicros = -1;
    _processing.value = false;
    processor?.reset();
  }

  Future<void> initDataFromOffline(OfflinePerformanceData offlineData) async {
    final wrappedTraceEvents = [
      for (var trace in offlineData.traceEvents)
        TraceEventWrapper(
          TraceEvent(trace),
          DateTime.now().microsecondsSinceEpoch,
        ),
    ];

    // TODO(kenz): once each trace event has a ui/raster distinction bit added to
    // the trace, we will not need to infer thread ids. This is not robust.
    final uiThreadId = _threadIdForEvents({uiEventName}, wrappedTraceEvents);
    final rasterThreadId =
        _threadIdForEvents({rasterEventName}, wrappedTraceEvents);

    // Process offline data.
    processor.primeThreadIds(
      uiThreadId: uiThreadId,
      rasterThreadId: rasterThreadId,
    );
    await processor.processTimeline(
      wrappedTraceEvents,
      firstProcess: true,
    );

    if (offlineData.selectedEvent != null) {
      for (var timelineEvent in _timelineEvents.value) {
        final eventToSelect = timelineEvent.firstChildWithCondition((event) {
          return event.name == offlineData.selectedEvent.name &&
              event.time == offlineData.selectedEvent.time;
        });
        if (eventToSelect != null) {
          _selectedTimelineEvent.value = eventToSelect;
          break;
        }
      }
    }
  }

  int _threadIdForEvents(
    Set<String> targetEventNames,
    List<TraceEventWrapper> traceEvents,
  ) {
    const invalidThreadId = -1;
    return traceEvents
            .firstWhere(
              (trace) => targetEventNames.contains(trace.event.name),
              orElse: () => null,
            )
            ?.event
            ?.threadId ??
        invalidThreadId;
  }

  Map<String, dynamic> get json => {
        traceEventsKey:
            traceEvents.map((eventWrapper) => eventWrapper.event.json).toList(),
        selectedEventKey: selectedTimelineEvent.value?.json ?? {},
      };
}

<<<<<<< Updated upstream
    if (offlinePerformanceData.cpuProfileData != null) {
      cpuProfilerController.loadProcessedData(
        offlinePerformanceData.cpuProfileData,
      );
    }
  }
=======
/// Controller for CPU profile data on the performance page.
class PerformanceCpuProfilerController extends DisposableController
    with CpuProfilerControllerProviderMixin {
  static const cpuProfileKey = 'cpuProfile';
>>>>>>> Stashed changes

  final _cpuProfilerService = CpuProfilerService();

<<<<<<< Updated upstream
  @override
  List<TimelineEvent> matchesForSearch(String search) {
    if (search?.isEmpty ?? true) return [];
    final matches = <TimelineEvent>[];
    for (final event in data.timelineEvents) {
      breadthFirstTraversal<TimelineEvent>(event, action: (TimelineEvent e) {
        if (e.name.caseInsensitiveContains(search)) {
          matches.add(e);
          e.isSearchMatch = true;
        } else {
          e.isSearchMatch = false;
        }
      });
    }
    return matches;
=======
  void init() {
    unawaited(allowedError(
      _cpuProfilerService.setProfilePeriod(mediumProfilePeriod),
      logError: false,
    ));
>>>>>>> Stashed changes
  }

  Future<void> updateForSelectedEvent(TimelineEvent event) async {
    cpuProfilerController.reset();

    // Fetch a profile if not in offline mode and if the profiler is enabled.
    if (!offlineMode && cpuProfilerController.profilerEnabled) {
      if (!event.isUiEvent) return;
      await cpuProfilerController.pullAndProcessProfile(
        startMicros: event.time.start.inMicroseconds,
        extentMicros: event.time.duration.inMicroseconds,
        processId: '${event.traceEvents.first.id}',
      );
    }
  }

  bool hasCpuProfileData() {
    final cpuProfileData = cpuProfilerController.dataNotifier.value;
    return cpuProfileData != null && cpuProfileData.stackFrames.isNotEmpty;
  }

  Future<void> initDataFromOffline(OfflinePerformanceData offlineData) async {
    if (offlineData.cpuProfileData != null) {
      await cpuProfilerController.transformer
          .processData(offlineData.cpuProfileData);
      cpuProfilerController.loadOfflineData(offlineData.cpuProfileData);
    }
  }

  Map<String, dynamic> get json => {
        cpuProfileKey: cpuProfilerController.dataNotifier.value?.json ?? {},
      };

  @override
  void dispose() {
    cpuProfilerController.dispose();
    super.dispose();
  }
}
