// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../primitives/auto_dispose.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../service/service_manager.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/routing.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../memory/memory_screen.dart';
import '../network/network_controller.dart';
import '../network/network_screen.dart';
import '../performance/performance_model.dart';
import '../performance/performance_screen.dart';
import '../performance/performance_utils.dart';

class OverviewScreen extends Screen {
  const OverviewScreen()
      : super(
          id,
          title: 'Overview',
          icon: Icons.auto_awesome,
        );

  static const id = 'overview';

  @override
  Widget build(BuildContext context) {
    return const _OverviewScreenBody();
  }
}

class _OverviewScreenBody extends StatefulWidget {
  const _OverviewScreenBody();

  @override
  _OverviewScreenBodyState createState() => _OverviewScreenBodyState();
}

class _OverviewScreenBodyState extends State<_OverviewScreenBody>
    with AutoDisposeMixin {
  late OverviewController controller;

  late int totalFrameCount;

  late int lowJankCount;

  late int medJankCount;

  late int highJankCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final networkController = Provider.of<NetworkController>(context);
    controller = Provider.of<OverviewController>(context)
      ..init(
        networkController: networkController,
      );

    totalFrameCount = controller.totalFrameCount.value;
    addAutoDisposeListener(controller.totalFrameCount, () {
      setState(() {
        totalFrameCount = controller.totalFrameCount.value;
      });
    });

    lowJankCount = controller.lowJankFrameCount.value;
    addAutoDisposeListener(controller.lowJankFrameCount, () {
      setState(() {
        lowJankCount = controller.lowJankFrameCount.value;
      });
    });

    medJankCount = controller.medJankFrameCount.value;
    addAutoDisposeListener(controller.medJankFrameCount, () {
      setState(() {
        medJankCount = controller.medJankFrameCount.value;
      });
    });

    highJankCount = controller.highJankFrameCount.value;
    addAutoDisposeListener(controller.highJankFrameCount, () {
      setState(() {
        highJankCount = controller.highJankFrameCount.value;
      });
    });
  }

  String percentJankyFrames() {
    return percent2(_totalJankyFrames / totalFrameCount);
  }

  int get _totalJankyFrames => lowJankCount + medJankCount + highJankCount;

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconLabelButton(
            label: 'Reset',
            icon: Icons.refresh,
            onPressed: controller.reset,
          ),
        ),
        const SizedBox(height: defaultSpacing),
        ..._performance(),
        const SizedBox(height: defaultSpacing),
        ..._memory(),
        const SizedBox(height: defaultSpacing),
        ..._network(),
      ],
    );
  }

  List<Widget> _performance() {
    final theme = Theme.of(context);
    return [
      Text('Performance', style: theme.textTheme.subtitle1),
      const PaddedDivider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: denseSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${percentJankyFrames()} of frames have jank ($_totalJankyFrames / $totalFrameCount)',
                  style: theme.subtleTextStyle,
                ),
                const SizedBox(height: denseSpacing),
                Text(
                  '$lowJankCount - slight jank (missed by < '
                  '${OverviewController.lowJankThreshold} ms)',
                  style: theme.subtleTextStyle.copyWith(
                    color: Colors.amberAccent,
                  ),
                ),
                const SizedBox(height: denseSpacing),
                Text(
                  '$medJankCount - moderate jank (missed by < '
                  '${OverviewController.medJankThreshold} ms)',
                  style: theme.subtleTextStyle.copyWith(
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: denseSpacing),
                Text(
                  '$highJankCount - extreme jank (missed by > '
                  '${OverviewController.medJankThreshold} ms)',
                  style: theme.subtleTextStyle.copyWith(
                    color: devtoolsError,
                  ),
                ),
              ],
            ),
          ),
          IconLabelButton(
            label: 'DevTools Performance Tool',
            icon: Icons.open_in_new,
            outlined: false,
            invertIconLabelOrder: true,
            onPressed: () => _switchToScreen(PerformanceScreen.id),
          ),
        ],
      ),
    ];
  }

  List<Widget> _memory() {
    final theme = Theme.of(context);
    return [
      Text('Memory', style: theme.textTheme.subtitle1),
      const PaddedDivider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TODO',
            style: theme.subtleTextStyle,
          ),
          IconLabelButton(
            label: 'DevTools Memory Tool',
            icon: Icons.open_in_new,
            outlined: false,
            invertIconLabelOrder: true,
            onPressed: () => _switchToScreen(MemoryScreen.id),
          ),
        ],
      ),
    ];
  }

  List<Widget> _network() {
    final theme = Theme.of(context);
    return [
      Text('Network', style: theme.textTheme.subtitle1),
      const PaddedDivider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ValueListenableBuilder(
            valueListenable: controller.failedNetworkRequestCount,
            builder: (context, failedRequestCount, _) {
              return ValueListenableBuilder(
                valueListenable: controller.totalNetworkRequestCount,
                builder: (context, totalRequestCount, _) {
                  return Text(
                    '$failedRequestCount / $totalRequestCount failed network requests',
                    style: theme.subtleTextStyle,
                  );
                },
              );
            },
          ),
          IconLabelButton(
            label: 'DevTools Network Tool',
            icon: Icons.open_in_new,
            outlined: false,
            invertIconLabelOrder: true,
            onPressed: () => _switchToScreen(NetworkScreen.id),
          ),
        ],
      )
    ];
  }

  void _switchToScreen(String screenId) {
    if (isEmbedded()) {
      // TODO: open in new browser. In VS code we might want to open in a tool
      // window instead of a new browser.
    } else {
      final routerDelegate = DevToolsRouterDelegate.of(context);
      routerDelegate.navigateIfNotCurrent(screenId);
    }
  }
}

class OverviewController extends DisposableController
    with AutoDisposeControllerMixin {
  late NetworkController networkController;

  /// The flutter frames in the current timeline.
  ValueListenable<List<FlutterFrame>> get flutterFrames => _flutterFrames;
  final _flutterFrames = ListValueNotifier<FlutterFrame>([]);

  ValueListenable<double> get displayRefreshRate => _displayRefreshRate;
  final _displayRefreshRate = ValueNotifier<double>(defaultRefreshRate);

  ValueListenable<int> get lowJankFrameCount => _lowJankFrameCount;
  final _lowJankFrameCount = ValueNotifier<int>(0);

  ValueListenable<int> get medJankFrameCount => _medJankFrameCount;
  final _medJankFrameCount = ValueNotifier<int>(0);

  ValueListenable<int> get highJankFrameCount => _highJankFrameCount;
  final _highJankFrameCount = ValueNotifier<int>(0);

  ValueListenable<int> get totalFrameCount => _totalFrameCount;
  final _totalFrameCount = ValueNotifier<int>(0);

  ValueListenable<int> get failedNetworkRequestCount =>
      _failedNetworkRequestCount;
  final _failedNetworkRequestCount = ValueNotifier<int>(0);

  ValueListenable<int> get totalNetworkRequestCount =>
      _totalNetworkRequestCount;
  final _totalNetworkRequestCount = ValueNotifier<int>(0);

  void init({required NetworkController networkController}) async {
    this.networkController = networkController;

    // Initialize displayRefreshRate.
    _displayRefreshRate.value =
        await serviceManager.queryDisplayRefreshRate ?? defaultRefreshRate;

    // Listen for flutter frames.
    autoDisposeStreamSubscription(
        serviceManager.service!.onExtensionEventWithHistory.listen((event) {
      if (event.extensionKind == 'Flutter.Frame') {
        print('Flutter.Frame');
        print(event.extensionData!.data);
        final frame = FlutterFrame.parse(event.extensionData!.data);
        addFrame(frame);
      } else if (event.extensionKind == 'Flutter.RebuiltWidgets') {
        print('Flutter.RebuiltWidgets');
        print(event.extensionData!.data);
        // rebuildCountModel.processRebuildEvent(event.extensionData.data);
      }
    }));

    // Update failed network request count.
    await networkController.startRecording();
    addAutoDisposeListener(networkController.requests, () {
      _totalNetworkRequestCount.value =
          networkController.requests.value.requests.length;
      _failedNetworkRequestCount.value = networkController
          .requests.value.requests
          .where((request) => request.didFail)
          .length;
    });
  }

  static const lowJankThreshold = 5.0;
  static const medJankThreshold = 15.0;
  void addFrame(FlutterFrame frame) {
    _flutterFrames.add(frame);
    _totalFrameCount.value = _flutterFrames.value.length;
    if (frame.isJanky(_displayRefreshRate.value)) {
      final targetMsPerFrame =
          PerformanceUtils.targetMsPerFrame(_displayRefreshRate.value);
      final maxFrameTime = math.max(
        frame.buildTime.inMilliseconds,
        frame.rasterTime.inMilliseconds,
      );
      final frameJankThreshold = maxFrameTime - targetMsPerFrame;
      if (frameJankThreshold <= lowJankThreshold) {
        _lowJankFrameCount.value = _lowJankFrameCount.value + 1;
      } else if (frameJankThreshold <= medJankThreshold) {
        _medJankFrameCount.value = _medJankFrameCount.value + 1;
      } else {
        _highJankFrameCount.value = _highJankFrameCount.value + 1;
      }
    }
  }

  void reset() {
    _flutterFrames.clear();
    _lowJankFrameCount.value = 0;
    _medJankFrameCount.value = 0;
    _highJankFrameCount.value = 0;
    _totalFrameCount.value = 0;

    networkController.clear();
    _failedNetworkRequestCount.value = 0;
    _totalNetworkRequestCount.value = 0;
  }
}
