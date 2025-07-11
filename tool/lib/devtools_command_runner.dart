// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:devtools_tool/commands/build.dart';
import 'package:devtools_tool/commands/fix_goldens.dart';
import 'package:devtools_tool/commands/generate_code.dart';
import 'package:devtools_tool/commands/release_notes_helper.dart';
import 'package:devtools_tool/commands/run.dart';
import 'package:devtools_tool/commands/serve.dart';
import 'package:devtools_tool/commands/sync.dart';
import 'package:devtools_tool/commands/tag_version.dart';
import 'package:devtools_tool/commands/update_flutter_sdk.dart';
import 'package:devtools_tool/commands/update_perfetto.dart';
import 'package:devtools_tool/model.dart';

import 'commands/analyze.dart';
import 'commands/list.dart';
import 'commands/pub_get.dart';
import 'commands/release_helper.dart';
import 'commands/repo_check.dart';
import 'commands/rollback.dart';
import 'commands/update_dart_sdk_deps.dart';
import 'commands/update_version.dart';

const _flutterFromPathFlag = 'flutter-from-path';

const _flutterSdkPathFlag = 'flutter-sdk-path';

class DevToolsCommandRunner extends CommandRunner {
  DevToolsCommandRunner()
    : super('dt', 'A repo management tool for DevTools.') {
    addCommand(AnalyzeCommand());
    addCommand(BuildCommand());
    addCommand(FixGoldensCommand());
    addCommand(GenerateCodeCommand());
    addCommand(ListCommand());
    addCommand(PubGetCommand());
    addCommand(ReleaseHelperCommand());
    addCommand(ReleaseNotesCommand());
    addCommand(RepoCheckCommand());
    addCommand(RollbackCommand());
    addCommand(RunCommand());
    addCommand(ServeCommand());
    addCommand(SyncCommand());
    addCommand(TagVersionCommand());
    addCommand(UpdateDartSdkDepsCommand());
    addCommand(UpdateDevToolsVersionCommand());
    addCommand(UpdateFlutterSdkCommand());
    addCommand(UpdatePerfettoCommand());

    argParser
      ..addFlag(
        _flutterFromPathFlag,
        abbr: 'p',
        negatable: false,
        help:
            'Use the Flutter SDK on PATH for any `flutter`, `dart` and '
            '`dt` commands spawned by this process, instead of the '
            'Flutter SDK from tool/flutter-sdk which is used by default. '
            'This is incompatible with the `$_flutterSdkPathFlag` flag.',
      )
      ..addOption(
        _flutterSdkPathFlag,
        help:
            'Use the Flutter SDK from the specified path for any `flutter`, '
            '`dart`, and `dt` commands spawned by this process, instead of the '
            'Flutter SDK from tool/flutter-sdk which is used by default. '
            'This is incompatible with the `$_flutterFromPathFlag` flag.',
      );
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) {
    if (topLevelResults.flag(_flutterFromPathFlag) &&
        topLevelResults.wasParsed(_flutterSdkPathFlag)) {
      throw ArgParserException(
        'Only one of `$_flutterFromPathFlag` and `$_flutterSdkPathFlag` may be passed',
      );
    }
    if (topLevelResults.wasParsed(_flutterSdkPathFlag)) {
      FlutterSdk.useFromPath(topLevelResults.option(_flutterSdkPathFlag)!);
    } else if (topLevelResults.flag(_flutterFromPathFlag)) {
      FlutterSdk.useFromPathEnvironmentVariable();
    } else {
      FlutterSdk.useFromCurrentVm();
    }
    print('Using Flutter SDK from ${FlutterSdk.current.sdkPath}');

    return super.runCommand(topLevelResults);
  }
}
