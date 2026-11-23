import 'dart:io';

import 'package:cleanverse/src/features/developer/tool_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing tool is reported as not installed', () async {
    final tools = ToolCommands(
      runner: (exe, args) async => throw ProcessException(exe, args),
    );
    expect(await tools.status(ToolCommand.npm), ToolStatus.notInstalled);
  });

  test('clean runs only the tool\'s official command', () async {
    final calls = <String>[];
    final tools = ToolCommands(
      runner: (exe, args) async {
        calls.add('$exe ${args.join(' ')}');
        return ProcessResult(1, 0, 'Removing: old.tar.gz\n', '');
      },
    );
    final preview = await tools.preview(ToolCommand.homebrew);
    final result = await tools.clean(ToolCommand.homebrew);
    expect(calls, ['brew cleanup --dry-run', 'brew cleanup']);
    expect(preview.output, 'Removing: old.tar.gz');
    expect(result.ok, isTrue);
  });

  test('tools without a dry run do not execute anything for preview', () async {
    var ran = false;
    final tools = ToolCommands(
      runner: (exe, args) async {
        ran = true;
        return ProcessResult(1, 0, '', '');
      },
    );
    await tools.preview(ToolCommand.npm);
    expect(ran, isFalse);
  });

  test('failures report the exit code', () async {
    final tools = ToolCommands(
      runner: (exe, args) async => ProcessResult(1, 2, '', 'EACCES'),
    );
    final r = await tools.clean(ToolCommand.pub);
    expect(r.ok, isFalse);
    expect(r.output, contains('exit 2'));
    expect(r.output, contains('EACCES'));
  });

  test('Homebrew is hidden on Windows', () {
    expect(ToolCommand.homebrew.supportedOn(windows: true), isFalse);
    expect(ToolCommand.npm.supportedOn(windows: true), isTrue);
  });

  test('long output is shortened', () {
    final text = List.generate(30, (i) => 'line $i').join('\n');
    expect(summarize(text), endsWith('… 18 more lines'));
  });
}
