// Minimal repro for a macOS-only Process hang with the posix_spawn-based
// dart:io implementation (Dart SDK commit 0171629a5478).
//
// Theory: once stdin hits EOF, dart:io closes fd 0. The next pipe() then
// returns fd 0 for the child's stdin pipe, and
// `posix_spawn_file_actions_adddup2(fd 0 -> fd 0)` does not clear
// FD_CLOEXEC on Darwin, so the child starts with fd 0 *closed*. In the child,
// a later pipe() (e.g. the exit-code pipe for a grandchild) reuses fd 0, and
// anything listening to `stdin` consumes those bytes, so the grandchild's exit
// is never observed.
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  final script = Platform.script.toFilePath();
  if (args.contains('--child')) {
    stderr.writeln('[child] fd0 stat: ${_describeStdin()}');
    // Mirror package:io's sharedStdIn: something in the child listens to stdin.
    final sub = stdin.listen((_) {}, onError: (_) {});
    try {
      final result = await Process.run('/bin/echo', [
        'hello',
      ]).timeout(const Duration(seconds: 30));
      print('[child] REPRO_RESULT=OK exit=${result.exitCode}');
    } on TimeoutException {
      print('[child] REPRO_RESULT=HANG');
      exit(3);
    } finally {
      await sub.cancel();
    }
    return;
  }

  if (args.contains('--drain-stdin')) {
    await stdin.drain<void>();
    stderr.writeln('stdin drained');
  }

  if (args.contains('--nested')) {
    final child = await Process.start(Platform.resolvedExecutable, [
      script,
      '--child',
    ]);
    child.stdout.listen(stdout.add);
    child.stderr.listen(stderr.add);
    final code = await child.exitCode.timeout(
      const Duration(seconds: 60),
      onTimeout: () => -999,
    );
    print('nested child exit=$code');
    return;
  }

  try {
    final result = await Process.run('/bin/echo', [
      'hello',
    ]).timeout(const Duration(seconds: 30));
    print('REPRO_RESULT=OK exit=${result.exitCode} out=${result.stdout}');
  } on TimeoutException {
    print('REPRO_RESULT=HANG');
    exit(3);
  }
}

String _describeStdin() {
  try {
    return '${stdioType(stdin)} hasTerminal=${stdin.hasTerminal}';
  } catch (e) {
    return 'error: $e';
  }
}
