// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import '_test_app_driver.dart';

const defaultFlutterAppPath = 'test/test_infra/fixtures/flutter_app';
const defaultDartCliAppPath = 'test/test_infra/fixtures/empty_app.dart';

/// Test arguments, defined inside the test file as a comment.
class TestFileArgs {
  factory TestFileArgs(
    String testFilePath, {
    required TestAppDevice testAppDevice,
  }) {
    final content = File(testFilePath).readAsStringSync();
    return TestFileArgs.fromFileContent(content, testAppDevice: testAppDevice);
  }

  /// Returns a [TestFileArgs] parsed from [fileContent].
  ///
  /// Separate from [TestFileArgs.new] for easier testing.
  factory TestFileArgs.fromFileContent(
    String fileContent, {
    required TestAppDevice testAppDevice,
  }) {
    final args = _parseFileContent(fileContent);
    final appPath =
        args[_TestFileArgItems.appPath] ??
        (testAppDevice == TestAppDevice.cli
            ? defaultDartCliAppPath
            : defaultFlutterAppPath);
    return TestFileArgs._parse(args, appPath: appPath);
  }

  TestFileArgs._parse(
    Map<_TestFileArgItems, dynamic> args, {
    required this.appPath,
  }) : experimentsOn = args[_TestFileArgItems.experimentsOn] ?? false,
       startDevToolsServer =
           args[_TestFileArgItems.startDevToolsServer] ?? false;

  /// The path to the application to connect to.
  final String appPath;

  /// Whether experiments are enabled in the test.
  final bool experimentsOn;

  /// Whether the DevTools server should be started and connected to DevTools.
  final bool startDevToolsServer;

  /// Parses 'test-argument' comments in [fileContent].
  static Map<_TestFileArgItems, dynamic> _parseFileContent(String fileContent) {
    return {
      for (final m in _argRegex.allMatches(fileContent))
        _TestFileArgItems.values.byName(m.group(1)!): jsonDecode(m.group(2)!),
    };
  }

  static final _argRegex = RegExp(
    r'^\/\/\s*test-argument\s*:\s*(\w+)\s*=\s*(\S*)\s*$',
    multiLine: true,
  );
}

/// The different arguments accepted as "file args."
enum _TestFileArgItems {
  /// The path to the Dart or Flutter application to run and connect to DevTools
  /// for this test.
  appPath,

  /// Whether to enable DevTools experimental features for this test.
  experimentsOn,

  /// Whether to start the DevTools server and connect it to DevTools for this
  /// test.
  startDevToolsServer,
}
