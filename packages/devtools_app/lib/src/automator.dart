// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'shared/development_helpers.dart';
import 'shared/primitives/flutter_widgets/linked_scroll_controller.dart';

abstract class Automator {
  /// An automator for DevTools that performs registered actions at set time
  /// intervals.
  ///
  /// This will be a no-op automator when [debugPerformanceAutomation] is false,
  /// which will always be the case for a release build of DevTools shipped to
  /// end users.
  static final instance = debugPerformanceAutomation
      ? _PerformanceAutomator._()
      : _NoopAutomator._();

  ValueListenable<bool> get automating;

  Future<void> beginAutomation();

  void stopAutomation();

  void registerAction(
    AutomationAction action,
    FutureOr<void> Function() callback,
  );

  Widget buildButton();

  void dispose();
}

/// A helper class for automating actions in DevTools.
///
/// This is for reproducing consistent scenarios for recording performance
/// profiles in Chrome DevTools and collecting Flutter frame time information.
class _PerformanceAutomator extends Automator {
  _PerformanceAutomator._();

  final _actions = <AutomationAction, FutureOr<void> Function()>{};

  late final _bindings = WidgetsFlutterBinding.ensureInitialized();

  final _frameTimings = <FrameTiming>[];

  final _stopWatch = Stopwatch();

  @override
  ValueListenable<bool> get automating => _automating;
  final _automating = ValueNotifier(false);

  @override
  Future<void> beginAutomation() async {
    if (_automating.value) {
      // short-circuit
      return;
    }
    try {
      _automating.value = true;
      _stopWatch
        ..reset()
        ..start();

      _frameTimings.clear();
      _bindings.addTimingsCallback(_timingsCallback);

      final actions = AutomationAction.values
          .where((a) => !AutomationAction._skip.contains(a));
      print('running actions: ${actions.toList()}');
      for (final action in actions) {
        await Future.delayed(
          _shortDelay,
          () async {
            print('Automator: ${action.name}');
            await _callAction(action);
          },
        );
        if (!_automating.value) {
          // cancel out early if automation has stopped!
          return;
        }
        await Future.delayed(action.afterDelay);
      }
      await Future.delayed(_moderateDelay);
    } finally {
      stopAutomation();
    }
  }

  @override
  void stopAutomation() {
    if (_automating.value) {
      _automating.value = false;
      _stopWatch.stop();

      _bindings.removeTimingsCallback(_timingsCallback);

      if (_frameTimings.isNotEmpty) {
        print('####');
        print('Frame count: ${_frameTimings.length}');
        print('Wall time: ${_stopWatch.elapsed}');

        final measurements = <String, Duration Function(FrameTiming)>{
          'totalTime': (ft) => ft.totalSpan,
          'buildDuration': (ft) => ft.buildDuration,
          'rasterDuration': (ft) => ft.rasterDuration,
        };

        print('*****');
        for (final measure in measurements.entries) {
          final timings = _frameTimings
              .map((ft) => measure.value(ft).inMicroseconds)
              .toList(growable: false)
            ..sort();

          print(measure.key);
          for (final p in const [50, 90, 95, 99]) {
            final index = timings.length * p ~/ 100.0;
            print(
              ['p$p', (timings[index] / 1000.0).toStringAsFixed(2)]
                  .map((e) => e.toString().padLeft(6))
                  .join('  '),
            );
          }
          print('');
        }
        print('*****');
      }
    }
  }

  @override
  Widget buildButton() => ValueListenableBuilder<bool>(
        valueListenable: Automator.instance.automating,
        builder: (context, automating, _) => DevToolsTooltip(
          message: 'Run Performance Automator',
          child: IconButton.filled(
            icon: Icon(
              automating ? Icons.stop : Icons.play_arrow,
              size: defaultIconSize,
            ),
            color: Colors.white,
            onPressed: automating
                ? Automator.instance.stopAutomation
                : Automator.instance.beginAutomation,
          ),
        ),
      );

  @override
  void registerAction(
    AutomationAction action,
    FutureOr<void> Function() callback,
  ) {
    _actions[action] = callback;
  }

  Future<void> _callAction(AutomationAction action) async {
    final callback = _actions[action];
    await callback?.call();
  }

  void _timingsCallback(List<FrameTiming> timings) {
    assert(
      _automating.value,
      'Automation should be running when these events are fired',
    );
    _frameTimings.addAll(timings);
  }

  @override
  void dispose() {
    _bindings.removeTimingsCallback(_timingsCallback);
    _frameTimings.clear();
    _stopWatch.stop();
    _automating.dispose();
  }
}

enum AutomationAction {
  navigateToHome,
  navigateToScreenInspector,
  inspectorSelectRoot,
  inspectorScrollSummaryTree,
  inspectorExpandAllInDetailsTree,
  inspectorScrollDetailsTree,
  navigateToScreenPerformance,
  navigateToScreenCpuProfiler,
  cpuProfilerLoadAllSamples,
  cpuProfilerScrollBottomUp,
  cpuProfilerOpenFlameChart,
  cpuProfilerScrollFlameChart,
  navigateToScreenMemory;

  Duration get afterDelay => switch (this) {
        navigateToScreenInspector ||
        navigateToScreenPerformance ||
        navigateToScreenCpuProfiler ||
        navigateToScreenMemory ||
        cpuProfilerLoadAllSamples =>
          _longDelay,
        _ => _veryShortDelay,
      };

  /// The set of automation actions to skip.
  ///
  /// All of these should be commented out to run the full automation, but you
  /// can uncomment actions to skip them locally.
  static const _skip = <AutomationAction>{
    // navigateToHome,
    // navigateToScreenInspector,
    // inspectorSelectRoot,
    // inspectorScrollSummaryTree,
    // inspectorExpandAllInDetailsTree,
    // inspectorScrollDetailsTree,
    // navigateToScreenPerformance,
    // navigateToScreenCpuProfiler,
    // cpuProfilerLoadAllSamples,
    // cpuProfilerScrollBottomUp,
    // cpuProfilerOpenFlameChart,
    // cpuProfilerScrollFlameChart,
    // navigateToScreenMemory,
  };
}

const _veryShortDelay = Duration(milliseconds: 500);
const _shortDelay = Duration(milliseconds: 1000);
const _moderateDelay = Duration(seconds: 2);
const _longDelay = Duration(seconds: 4);

/// A no-op automator to use when [debugPerformanceAutomation] is false.
class _NoopAutomator extends Automator {
  _NoopAutomator._();
  @override
  Widget buildButton() => const SizedBox();

  @override
  ValueListenable<bool> get automating => ValueNotifier<bool>(false);

  @override
  Future<void> beginAutomation() async {}

  @override
  void stopAutomation() {}

  @override
  void registerAction(AutomationAction action, VoidCallback callback) {}

  @override
  void dispose() {}
}

extension ScrollingExtensions on ScrollController {
  Future<void> animateToEnd({bool fast = false}) async {
    await animateTo(
      position.maxScrollExtent,
      duration: Duration(seconds: fast ? 1 : 2),
      curve: Curves.linear,
    );
  }
}

extension LinkedScrollingExtensions on LinkedScrollControllerGroup {
  Future<void> animateToEnd() async {
    await animateTo(
      position.maxScrollExtent,
      duration: const Duration(seconds: 2),
      curve: Curves.linear,
    );
  }
}
