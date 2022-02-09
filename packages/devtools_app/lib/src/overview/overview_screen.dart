import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../devtools_app.dart';
import '../auto_dispose.dart';
import '../common_widgets.dart';
import '../globals.dart';
import '../memory/memory_screen.dart';
import '../network/network_controller.dart';
import '../network/network_screen.dart';
import '../performance/performance_model.dart';
import '../performance/performance_screen.dart';
import '../screen.dart';
import '../service_manager.dart';
import '../theme.dart';
import '../utils.dart';

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

class _OverviewScreenBodyState extends State<_OverviewScreenBody> {
  OverviewController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final networkController = Provider.of<NetworkController>(context);
    controller = OverviewController(networkController: networkController);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        Text('Performance', style: theme.textTheme.subtitle1),
        const PaddedDivider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder(
              valueListenable: controller.jankyFrameCount,
              builder: (context, jankyFrameCount, _) {
                return ValueListenableBuilder(
                  valueListenable: controller.totalFrameCount,
                  builder: (context, totalFrameCount, _) {
                    return Text(
                      '$jankyFrameCount / $totalFrameCount frames with jank',
                      style: theme.subtleTextStyle,
                    );
                  },
                );
              },
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
        const SizedBox(height: defaultSpacing),
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
        const SizedBox(height: defaultSpacing),
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
        ),
      ],
    );
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
  OverviewController({this.networkController}) {
    _init();
  }

  final NetworkController networkController;

  /// The flutter frames in the current timeline.
  ValueListenable<List<FlutterFrame>> get flutterFrames => _flutterFrames;
  final _flutterFrames = ListValueNotifier<FlutterFrame>([]);

  ValueListenable<double> get displayRefreshRate => _displayRefreshRate;
  final _displayRefreshRate = ValueNotifier<double>(defaultRefreshRate);

  ValueListenable<int> get jankyFrameCount => _jankyFrameCount;
  final _jankyFrameCount = ValueNotifier<int>(0);

  ValueListenable<int> get totalFrameCount => _totalFrameCount;
  final _totalFrameCount = ValueNotifier<int>(0);

  ValueListenable<int> get failedNetworkRequestCount =>
      _failedNetworkRequestCount;
  final _failedNetworkRequestCount = ValueNotifier<int>(0);

  ValueListenable<int> get totalNetworkRequestCount =>
      _totalNetworkRequestCount;
  final _totalNetworkRequestCount = ValueNotifier<int>(0);

  void _init() async {
    // Initialize displayRefreshRate.
    _displayRefreshRate.value =
        await serviceManager.queryDisplayRefreshRate ?? defaultRefreshRate;

    // Listen for flutter frames.
    autoDisposeStreamSubscription(
        serviceManager.service.onExtensionEventWithHistory.listen((event) {
      if (event.extensionKind == 'Flutter.Frame') {
        print('Flutter.Frame');
        print(event.extensionData.data);
        final frame = FlutterFrame.parse(event.extensionData.data);
        addFrame(frame);
      } else if (event.extensionKind == 'Flutter.RebuiltWidgets') {
        print('Flutter.RebuiltWidgets');
        print(event.extensionData.data);
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

  void addFrame(FlutterFrame frame) {
    _flutterFrames.add(frame);
    _totalFrameCount.value = _flutterFrames.value.length;
    if (frame.isJanky(_displayRefreshRate.value)) {
      _jankyFrameCount.value = _jankyFrameCount.value + 1;
    }
  }

  void reset() {
    _flutterFrames.clear();
    _jankyFrameCount.value = 0;
    _totalFrameCount.value = 0;

    networkController.clear();
    _failedNetworkRequestCount.value = 0;
    _totalNetworkRequestCount.value = 0;
  }
}
