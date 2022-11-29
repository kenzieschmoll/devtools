// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('chrome') // Uses web-only Flutter SDK

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/charts/flame_chart.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/primitives/feature_flags.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/perfetto/_perfetto_web.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/perfetto/perfetto.dart';
import 'package:devtools_app/src/screens/performance/tabbed_performance_view.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import '../../../test_infra/matchers/matchers.dart';
import '../../../test_infra/test_data/performance.dart';

void main() {
  FakeServiceManager fakeServiceManager;
  late PerformanceController controller;

  Future<void> _setUpServiceManagerWithTimeline(
    Map<String, dynamic> timelineJson,
  ) async {
    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        timelineData: vm_service.Timeline.parse(timelineJson)!,
      ),
    );
    mockConnectedApp(
      fakeServiceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: true,
      isWebApp: false,
    );
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());
    controller = PerformanceController();
    await controller.timelineEventsController.toggleUseLegacyTraceViewer(false);
  }

  group('$EmbeddedPerfetto', () {
    setUp(() async {
      FeatureFlags.embeddedPerfetto = true;
      await _setUpServiceManagerWithTimeline(testTimelineJson);
    });

    Future<void> pumpPerformanceScreenBody(
      WidgetTester tester, {
      PerformanceController? performanceController,
      bool runAsync = false,
    }) async {
      controller = performanceController ?? controller;

      if (runAsync) {
        // Await a small delay to allow the PerformanceController to complete
        // initialization.
        await Future.delayed(const Duration(seconds: 1));
      }

      await tester.pumpWidget(
        wrapWithControllers(
          const PerformanceScreenBody(),
          performance: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TabbedPerformanceView), findsOneWidget);

      // Ensure the Timeline Events tab is selected.
      final timelineEventsTabFinder = find.text('Timeline Events');
      expect(timelineEventsTabFinder, findsOneWidget);
      await tester.tap(timelineEventsTabFinder);
      await tester.pumpAndSettle();
    }

    const windowSize = Size(2225.0, 1000.0);

    // testWidgetsWithWindowSize('builds header with refresh button', windowSize,
    //     (WidgetTester tester) async {
    //   await tester.runAsync(() async {
    //     await _setUpServiceManagerWithTimeline({});
    //     await pumpPerformanceScreenBody(tester);
    //     await tester.pumpAndSettle();
    //     expect(find.byType(RefreshTimelineEventsButton), findsOneWidget);
    //     // These are only in the header for the legacy trace viewer.
    //     expect(find.byKey(timelineSearchFieldKey), findsNothing);
    //     expect(find.byType(FlameChartHelpButton), findsNothing);
    //   });
    // });

    testWidgetsWithWindowSize('builds embedded perfetto with data', windowSize,
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpPerformanceScreenBody(tester, runAsync: true);
        expect(find.byType(EmbeddedPerfetto), findsOneWidget);
        expect(find.byType(Perfetto), findsOneWidget);
        expect(find.byType(HtmlElementView), findsOneWidget);
        print('in test - awaiting a delay to see if the PONG event ever comes in');
        await Future.delayed(const Duration(seconds: 10));
        await tester.pumpAndSettle(const Duration(seconds: 10));
        print('in test - we waited for the PONG event and it never came in');
      });
      // print('here2');
      // await tester.pumpAndSettle(const Duration(seconds: 10));
      // print('here3');
      // await expectLater(
      //   find.byType(EmbeddedPerfetto),
      //   matchesDevToolsGolden(
      //     '../../../test_infra/goldens/perfetto_with_data.png',
      //   ),
      // );
      // // Await delay for golden comparison.
      // await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}
