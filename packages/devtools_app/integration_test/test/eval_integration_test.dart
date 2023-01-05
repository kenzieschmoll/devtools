// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/eval_on_dart_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  print('in eval main');

  late TestApp testApp;
  late Disposable isAlive;

  setUpAll(() async {
    print('eval test setup all');
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
    await testApp.init();
  });

  setUp(() {
    isAlive = Disposable();
  });

  tearDown(() async {
    isAlive.dispose();
    // await env.tearDownEnvironment(force: true);
  });

  tearDownAll(() async {
    await testApp.dispose();
  });

  testWidgets('EvalOnDartLibrary', (tester) async {
    await pumpDevTools(tester);
    await connectToTestApp(tester, testApp);

    logStatus('getHashCode');
    var eval = EvalOnDartLibrary('dart:core', testApp.vmService!);

    var instance = await eval.safeEval('42', isAlive: isAlive);

    await expectLater(
      eval.getHashCode(instance, isAlive: isAlive),
      completion(anyOf(isPositive, 0)),
    );

    logStatus(
        'asyncEval supports expresions that do not start with the await keyword');
    eval = EvalOnDartLibrary(
      'dart:core',
      testApp.vmService!,
    );

    instance = (await eval.asyncEval('42', isAlive: isAlive))!;
    expect(instance.valueAsString, '42');

    final instance2 =
        (await eval.asyncEval('Future.value(42)', isAlive: isAlive))!;
    expect(instance2.classRef!.name, '_Future');

    logStatus('asyncEval returns the result of the future completion');
    final mainIsolate = serviceManager.isolateManager.mainIsolate;
    expect(mainIsolate, isNotNull);

    eval = EvalOnDartLibrary(
      'dart:core',
      testApp.vmService!,
      isolate: mainIsolate,
    );

    instance = (await eval.asyncEval(
      // The delay asserts that there is no issue with garbage collection
      'await Future<int>.delayed(const Duration(milliseconds: 500), () => 42)',
      isAlive: isAlive,
    ))!;

    expect(instance.valueAsString, '42');

    logStatus(
        'asyncEval throws FutureFailedException when the future is rejected');
    eval = EvalOnDartLibrary(
      'dart:core',
      testApp.vmService!,
    );

    final exception = await eval
        .asyncEval(
          'await Future.error(StateError("foo"), StackTrace.current)',
          isAlive: isAlive,
        )
        .then<FutureFailedException>(
          (_) => throw Exception(
            'The FutureFailedException was not thrown as expected.',
          ),
          onError: (err) => err,
        );

    expect(
      exception.expression,
      'await Future.error(StateError("foo"), StackTrace.current)',
    );

    final stack = await eval.safeEval(
      'stack.toString()',
      isAlive: isAlive,
      scope: {
        'stack': exception.stacktraceRef.id!,
      },
    );
    expect(
      stack.valueAsString,
      startsWith('#0      Eval.<anonymous closure> ()'),
    );

    final error = await eval.safeEval(
      'error.message',
      isAlive: isAlive,
      scope: {'error': exception.errorRef.id!},
    );
    expect(error.valueAsString, 'foo');
  });
}
