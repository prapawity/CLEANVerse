import 'dart:io';

import 'package:cleanverse/src/features/developer/docker.dart';
import 'package:flutter_test/flutter_test.dart';

DockerTools fake(int code, String out, String err) =>
    DockerTools(runner: (exe, args) async => ProcessResult(1, code, out, err));

void main() {
  test('stopped Docker Desktop is reported as not running', () async {
    final report = await fake(
      1,
      '',
      'failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine; '
          'check if the path is correct and if the daemon is running: open '
          '//./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.',
    ).usage();
    expect(report.state, DockerState.notRunning);
  });

  test('missing CLI is reported as not installed', () async {
    final tools = DockerTools(
      runner: (exe, args) async => throw const ProcessException('docker', []),
    );
    expect((await tools.usage()).state, DockerState.notInstalled);
  });

  test('usage rows are parsed from JSON lines', () async {
    final report = await fake(
      0,
      '{"Type":"Images","TotalCount":"3","Active":"1","Size":"1.2GB","Reclaimable":"800MB (66%)"}\n'
          '{"Type":"Build Cache","TotalCount":"10","Active":"0","Size":"2GB","Reclaimable":"2GB"}\n',
      '',
    ).usage();
    expect(report.state, DockerState.ready);
    expect(report.rows.map((r) => r.type), ['Images', 'Build Cache']);
    expect(report.rows.first.reclaimable, '800MB (66%)');
  });

  test('prune returns the reclaimed summary', () async {
    final tools = fake(
      0,
      'Deleted build cache objects:\nabc\n\nTotal reclaimed space: 1.5GB\n',
      '',
    );
    expect(
      await tools.prune(DockerPrune.buildCache),
      'Total reclaimed space: 1.5GB',
    );
  });

  test('finds Docker Desktop next to the CLI on another drive', () async {
    final dir = await Directory.systemTemp.createTemp('cv_docker');
    addTearDown(() => dir.delete(recursive: true));
    final exe = File('${dir.path}\\Docker Desktop.exe');
    await exe.writeAsString('x');
    final found = await findWindowsDockerDesktop(
      run: (cmd, args) async => ProcessResult(
        1,
        cmd == 'where' ? 0 : 1,
        cmd == 'where' ? '${dir.path}\\resources\\bin\\docker.exe\r\n' : '',
        '',
      ),
    );
    expect(found, exe.path);
  }, testOn: 'windows');
}
