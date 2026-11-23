import 'dart:io';

import 'package:cleanverse/src/data/removal.dart';
import 'package:cleanverse/src/features/cleanup/junk_catalog.dart';
import 'package:cleanverse/src/features/uninstall/app_catalog.dart';
import 'package:cleanverse/src/features/uninstall/uninstall_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class FakeTrash implements TrashBackend {
  final moved = <String>[];
  @override
  Future<Map<String, String?>> moveToTrash(List<String> paths) async {
    moved.addAll(paths);
    return {for (final path in paths) path: null};
  }
}

void main() {
  late Directory sandbox;
  late String home;
  late String apps;
  var psOutput = '';

  Future<void> touch(String rel, [int bytes = 10]) async {
    final f = File(p.join(sandbox.path, rel));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(List.filled(bytes, 0));
  }

  /// Fake plutil reads "key=value" lines from the fixture Info.plist.
  Future<ProcessResult> runner(String exe, List<String> args) async {
    if (exe == 'ps') return ProcessResult(1, 0, psOutput, '');
    if (exe == 'plutil') {
      final key = args[1];
      final lines = await File(args.last).readAsLines();
      for (final l in lines) {
        final i = l.indexOf('=');
        if (l.substring(0, i) == key) {
          return ProcessResult(1, 0, l.substring(i + 1), '');
        }
      }
      return ProcessResult(1, 1, '', 'missing');
    }
    throw ProcessException(exe, args);
  }

  AppCatalog catalog() => AppCatalog(
    runner: runner,
    environment: {'HOME': home},
    folders: [apps],
    systemFolders: [p.join(sandbox.path, 'SystemLibrary', 'LaunchDaemons')],
  );

  Future<void> app(String file, String id, String name) async {
    await touch('Applications/$file/Contents/MacOS/bin', 100);
    final plist = File(p.join(apps, file, 'Contents', 'Info.plist'));
    await plist.writeAsString(
      'CFBundleIdentifier=$id\nCFBundleName=$name\nCFBundleShortVersionString=1.2\n',
    );
  }

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('cv_uninstall');
    home = p.join(sandbox.path, 'home');
    apps = p.join(sandbox.path, 'Applications');
    psOutput = '';
    await app('Notely.app', 'com.example.notely', 'Notely');
    await app('Safari.app', 'com.apple.Safari', 'Safari');
    final lib = 'home/Library';
    await touch('$lib/Caches/com.example.notely/c.db');
    await touch('$lib/Caches/com.example.notely.helper/c.db');
    await touch('$lib/Caches/com.example.notelyx/other.db'); // must not match
    await touch('$lib/Preferences/com.example.notely.plist');
    await touch('$lib/Preferences/com.example.notelyfoo.plist'); // no match
    await touch('$lib/Application Support/Notely/notes.sqlite', 500);
    await touch('$lib/Containers/com.example.notely/Data/x');
    await touch('$lib/Group Containers/ABCDE12345.com.example.notely/x');
    await touch('$lib/Saved Application State/com.example.notely.savedState/w');
    await touch('$lib/LaunchAgents/com.example.notely.agent.plist');
    await touch('SystemLibrary/LaunchDaemons/com.example.notely.daemon.plist');
  });
  tearDown(() => sandbox.delete(recursive: true));

  test('bundle id matching needs an exact id or a dot boundary', () {
    expect(matchesBundleId('com.example.app', 'com.example.app'), isTrue);
    expect(
      matchesBundleId('com.example.app.helper', 'com.example.app'),
      isTrue,
    );
    expect(
      matchesBundleId('com.example.application', 'com.example.app'),
      isFalse,
    );
  });

  test('Apple apps are not listed', () async {
    final list = await catalog().listApps();
    expect(list.map((a) => a.bundleId), ['com.example.notely']);
    expect(list.single.version, '1.2');
  });

  test('leftovers are found by bundle id, with risk per kind', () async {
    final c = catalog();
    final notely = (await c.listApps()).single;
    final found = await c.findLeftovers(notely);
    String rel(String path) => p.relative(path, from: sandbox.path);
    final byPath = {for (final l in found) rel(l.path): l};

    expect(
      byPath.keys,
      containsAll([
        'Applications/Notely.app',
        'home/Library/Caches/com.example.notely',
        'home/Library/Caches/com.example.notely.helper',
        'home/Library/Preferences/com.example.notely.plist',
        'home/Library/Containers/com.example.notely',
        'home/Library/Group Containers/ABCDE12345.com.example.notely',
        'home/Library/Saved Application State/com.example.notely.savedState',
        'home/Library/LaunchAgents/com.example.notely.agent.plist',
        'home/Library/Application Support/Notely',
      ]),
    );
    expect(byPath.keys.any((k) => k.contains('notelyx')), isFalse);
    expect(byPath.keys.any((k) => k.contains('notelyfoo')), isFalse);

    expect(
      byPath['home/Library/Caches/com.example.notely']!.risk,
      JunkRisk.safe,
    );
    expect(
      byPath['home/Library/Containers/com.example.notely']!.risk,
      JunkRisk.risky,
    );
    final byName = byPath['home/Library/Application Support/Notely']!;
    expect(byName.byName, isTrue);
    expect(byName.risk, JunkRisk.risky);

    final system =
        byPath['SystemLibrary/LaunchDaemons/com.example.notely.daemon.plist']!;
    expect(system.removable, isFalse);
    expect(
      found.every((l) => l.toItem('x').recommended == RemovalMode.trash),
      isTrue,
    );
  });

  test('nothing is selected and system items cannot be selected', () async {
    final trash = FakeTrash();
    final model = UninstallViewModel(catalog: catalog(), trash: trash);
    addTearDown(model.dispose);
    await model.loadApps();
    await model.open(model.apps!.single);
    expect(model.selected, isEmpty);
    model.toggle(model.systemWide.single, true);
    expect(model.selected, isEmpty);
    model.selectAll(true);
    expect(model.selected.length, model.removable.length);
    expect(model.selected.any((l) => !l.removable), isFalse);
  });

  test('a running app is never removed', () async {
    final trash = FakeTrash();
    final model = UninstallViewModel(catalog: catalog(), trash: trash);
    addTearDown(model.dispose);
    await model.loadApps();
    await model.open(model.apps!.single);
    model.selectAll(true);
    psOutput = '${p.join(apps, 'Notely.app')}/Contents/MacOS/bin --flag\n';
    final outcomes = await model.remove();
    expect(outcomes, isEmpty);
    expect(trash.moved, isEmpty);
    expect(model.running, isTrue);
  });

  test('uninstall moves selected items to the Trash only', () async {
    final trash = FakeTrash();
    final model = UninstallViewModel(catalog: catalog(), trash: trash);
    addTearDown(model.dispose);
    await model.loadApps();
    await model.open(model.apps!.single);
    model.selectAll(true);
    final count = model.selected.length;
    final outcomes = await model.remove(override: RemovalMode.permanent);
    expect(trash.moved.length, count);
    expect(outcomes.every((o) => o.mode == RemovalMode.trash), isTrue);
    // Files are untouched by the fake Trash, so nothing was deleted.
    expect(Directory(p.join(apps, 'Notely.app')).existsSync(), isTrue);
  });
}
