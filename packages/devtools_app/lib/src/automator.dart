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
import 'shared/routing.dart';

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

  Future<void> beginAutomation(DevToolsRouterDelegate router);

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
  Future<void> beginAutomation(DevToolsRouterDelegate router) async {
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

      router.navigateHome(clearScreenParam: true);

      for (var action in AutomationAction.values) {
        print('Automater: ${action.name}');
        await Future.delayed(
          action.delay,
          () async => await _callAction(action),
        );
        if (!_automating.value) {
          // cancel out early if automation has stopped!
          return;
        }
      }
      await Future.delayed(_veryShortDelay);
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

        final things = <String, Duration Function(FrameTiming)>{
          'totalSpan': (ft) => ft.totalSpan,
        };

        for (var thing in things.entries) {
          final timing = _frameTimings
              .map((e) => thing.value(e).inMicroseconds)
              .toList(growable: false)
            ..sort();

          print('*****');
          print(thing.key);
          for (var item in const [50, 90, 95, 99]) {
            final index = timing.length * item ~/ 100.0;
            print(
              [item, (timing[index] / 1000.0).toStringAsFixed(2)]
                  .map((e) => e.toString().padLeft(6))
                  .join('  '),
            );
          }
          print('');
          print('*****');
        }
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
            onPressed: () => automating
                ? Automator.instance.stopAutomation()
                : unawaited(
                    Automator.instance.beginAutomation(
                      DevToolsRouterDelegate.of(context),
                    ),
                  ),
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
  navigateToScreenInspector,
  inspectorScrollSummaryTree,
  inspectorExpandAllInDetailsTree,
  inspectorScrollDetailsTree,
  navigateToScreenPerformance,
  navigateToScreenCpuProfiler,
  cpuProfilerLoadAllSamples,
  cpuProfilerScrollCallTree,
  cpuProfilerOpenFlameChart,
  cpuProfilerScrollFlameChart,
  navigateToScreenMemory;

  Duration get delay => switch (this) {
        AutomationAction.navigateToScreenInspector ||
        AutomationAction.navigateToScreenPerformance ||
        AutomationAction.navigateToScreenCpuProfiler ||
        AutomationAction.navigateToScreenMemory =>
          _moderateDelay,
        _ => _shortDelay,
      };
}

const _veryShortDelay = Duration(seconds: 1);
const _shortDelay = Duration(milliseconds: 1500);
const _moderateDelay = Duration(seconds: 2);

/// A no-op automator to use when [debugPerformanceAutomation] is false.
class _NoopAutomator extends Automator {
  _NoopAutomator._();
  @override
  Widget buildButton() => const SizedBox();

  @override
  ValueListenable<bool> get automating => ValueNotifier<bool>(false);

  @override
  Future<void> beginAutomation(DevToolsRouterDelegate router) async {}

  @override
  void stopAutomation() {}

  @override
  void registerAction(AutomationAction action, VoidCallback callback) {}

  @override
  void dispose() {}
}

extension ScrollingExtensions on ScrollController {
  Future<void> animateToEnd() async {
    await animateTo(
      position.maxScrollExtent,
      duration: const Duration(seconds: 2),
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
