// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/breakpoint_manager.dart';
import 'package:devtools_app/src/screens/provider/instance_viewer/instance_details.dart';
import 'package:devtools_app/src/screens/provider/instance_viewer/instance_providers.dart';
import 'package:devtools_app/src/screens/provider/provider_nodes.dart';
import 'package:devtools_app/src/shared/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/console/eval/eval_service.dart';
import 'package:devtools_app/src/shared/eval_on_dart_library.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/primitives/storage.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vm_service/vm_service.dart' hide SentinelException;

import '../test_utils.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  late EvalOnDartLibrary evalOnDartLibrary;
  late Disposable isAlive;

  const countPath = InstancePath.fromProviderId(
    '0',
    pathToProperty: [
      PathToProperty.objectProperty(
        name: '_count',
        ownerUri: 'package:provider_app/main.dart',
        ownerName: 'Counter',
      )
    ],
  );

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);

    isAlive = Disposable();
    evalOnDartLibrary = EvalOnDartLibrary(
      'package:provider_app/main.dart',
      env.service,
    );
  });

  tearDown(() async {
    isAlive.dispose();
    evalOnDartLibrary.dispose();
  });

  test(
    'supports edits',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // TODO(rrousselGit) alter the test so that it does not print in the console
      // (eval logs the errors in the console)

      await expectLater(
        evalOnDartLibrary.safeEval(
          "find.text('0').evaluate().first",
          isAlive: isAlive,
        ),
        completes,
      );
      await expectLater(
        evalOnDartLibrary.safeEval(
          "find.text('42').evaluate().first",
          isAlive: isAlive,
        ),
        throwsA(anything),
      );

      // wait for the list of providers to be obtained
      await container
          .listen(sortedProviderNodesProvider.future, (prev, next) {})
          .read();

      final countSub = container.listen(
        instanceProvider(countPath).future,
        (prev, next) {},
      );

      final instance = await countSub.read();

      expect(
        instance,
        isA<NumInstance>()
            .having((e) => e.displayString, 'displayString', '0')
            .having((e) => e.setter, 'setter', isNotNull),
      );

      await instance.setter!('42');

      await expectLater(
        countSub.read(),
        completion(
          isA<NumInstance>()
              .having((e) => e.displayString, 'displayString', '42'),
        ),
      );

      // verify that the UI updated
      await expectLater(
        evalOnDartLibrary.safeEval(
          "find.text('0').evaluate().first",
          isAlive: isAlive,
        ),
        throwsA(anything),
      );
      await expectLater(
        evalOnDartLibrary.safeEval(
          "find.text('42').evaluate().first",
          isAlive: isAlive,
        ),
        completes,
      );
    },
    timeout: const Timeout.factor(12),
  );
}
