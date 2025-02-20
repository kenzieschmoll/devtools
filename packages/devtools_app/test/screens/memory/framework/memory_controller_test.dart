// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/scenes/memory/default.dart';

final _filter1 = ClassFilter(
  except: 'filter1',
  filterType: ClassFilterType.except,
  only: 'filter1',
);

final _filter2 = ClassFilter(
  except: 'filter2',
  filterType: ClassFilterType.except,
  only: 'filter2',
);

Future<void> _pumpScene(WidgetTester tester, MemoryDefaultScene scene) async {
  await scene.pump(tester);
  await scene.goToDiffTab(tester);
}

// Set a wide enough screen width that we do not run into overflow.
const _windowSize = Size(2225.0, 1000.0);

void _verifyFiltersAreEqual(MemoryDefaultScene scene, [ClassFilter? filter]) {
  expect(
    scene.controller.diff.core.classFilter.value,
    equals(scene.controller.profile!.classFilter.value),
  );

  if (filter != null) {
    expect(scene.controller.diff.core.classFilter.value, equals(filter));
  }
}

void main() {
  late MemoryDefaultScene scene;
  setUp(() async {
    scene = MemoryDefaultScene();
    await scene.setUp();
  });

  tearDown(() {
    scene.tearDown();
  });

  testWidgetsWithWindowSize(
    '$ClassFilter is shared between diff and profile.',
    _windowSize,
    (WidgetTester tester) async {
      await _pumpScene(tester, scene);
      await scene.takeSnapshot(tester);

      _verifyFiltersAreEqual(scene);

      scene.controller.diff.derived.applyFilter(_filter1);
      _verifyFiltersAreEqual(scene, _filter1);

      scene.controller.profile!.setFilter(_filter2);
      _verifyFiltersAreEqual(scene, _filter2);
    },
  );
}
