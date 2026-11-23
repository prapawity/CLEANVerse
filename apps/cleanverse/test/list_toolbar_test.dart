import 'package:cleanverse/src/app/list_toolbar.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

enum _S { a, b }

void main() {
  test('every word must match some field, ignoring case', () {
    expect(matchesQuery('', ['x']), isTrue);
    expect(matchesQuery('Report', ['report-final.pdf']), isTrue);
    expect(matchesQuery('final pdf', ['report-final.pdf', '/Users/x']), isTrue);
    expect(matchesQuery('users pdf', ['report-final.pdf', '/Users/x']), isTrue);
    expect(matchesQuery('final zip', ['report-final.pdf']), isFalse);
    expect(matchesQuery('x', [null, 'X']), isTrue);
  });

  testWidgets('search is debounced, clearable, and sort applies', (
    tester,
  ) async {
    final queries = <String>[];
    var sort = _S.a;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ListToolbar<_S>(
              hint: 'Search files',
              onQuery: queries.add,
              sort: sort,
              sortOptions: const [
                SortOption(_S.a, 'Largest first'),
                SortOption(_S.b, 'Name A to Z'),
              ],
              onSort: (v) => setState(() => sort = v),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'rep');
    await tester.pump(const Duration(milliseconds: 50));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(queries, ['rep']);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(queries.last, '');

    await tester.tap(find.text('Largest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name A to Z').last);
    await tester.pumpAndSettle();
    expect(sort, _S.b);
  });

  testWidgets('toolbar fits a narrow window at 200% text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListToolbar<_S>(
              hint: 'Search files',
              onQuery: (_) {},
              sort: _S.a,
              sortOptions: const [SortOption(_S.a, 'Largest first')],
              onSort: (_) {},
              trailing: const Text('Filter'),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('focusActive focuses the search box and Esc clears it', (
    tester,
  ) async {
    final queries = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListToolbar<_S>(
            hint: 'Search',
            onQuery: queries.add,
            sort: _S.a,
            sortOptions: const [SortOption(_S.a, 'Largest first')],
            onSort: (_) {},
          ),
        ),
      ),
    );
    expect(SearchFocus.focusActive(), isTrue);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(queries.last, '');
    expect(find.text('abc'), findsNothing);

    // Second Esc leaves the box.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(field.focusNode!.hasFocus, isFalse);
  });
}
