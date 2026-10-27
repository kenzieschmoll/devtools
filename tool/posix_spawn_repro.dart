// Minimal repro for a macOS-only Process hang with the posix_spawn-based
// dart:io implementation (Dart SDK commit 0171629a5478).
//
// Theory: once stdin hits EOF and dart:io closes fd 0, the next pipe() call
// reuses fd 0, which confuses the posix_spawn file actions so the parent never
// observes the child's exit.
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.contains('--drain-stdin')) {
    await stdin.drain<void>();
    stderr.writeln('stdin drained');
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
