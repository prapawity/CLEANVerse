import 'dart:async';

// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:cleanverse/src/app/theme.dart';

/// True when every whitespace-separated word in [query] appears in at least
/// one of [fields], ignoring case. An empty query matches everything.
bool matchesQuery(String query, Iterable<String?> fields) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final haystack = [
    for (final f in fields)
      if (f != null) f.toLowerCase(),
  ];
  return words.every((w) => haystack.any((h) => h.contains(w)));
}

class SortOption<T> {
  const SortOption(this.value, this.label);
  final T value;
  final String label;
}

/// Search box and sort menu shared by every list page, so they look and
/// behave the same. Search is debounced; sorting applies at once.
class ListToolbar<T> extends StatefulWidget {
  const ListToolbar({
    super.key,
    required this.hint,
    required this.onQuery,
    required this.sort,
    required this.sortOptions,
    required this.onSort,
    this.initialQuery = '',
    this.trailing,
    this.debounce = const Duration(milliseconds: 180),
  });
  final String hint;
  final ValueChanged<String> onQuery;
  final T sort;
  final List<SortOption<T>> sortOptions;
  final ValueChanged<T> onSort;
  final String initialQuery;

  /// Extra control, such as a filter, shown after the sort menu.
  final Widget? trailing;
  final Duration debounce;

  @override
  State<ListToolbar<T>> createState() => _ListToolbarState<T>();
}

class _ListToolbarState<T> extends State<ListToolbar<T>> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {}); // show or hide the clear button
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onQuery(value));
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    setState(() {});
    widget.onQuery('');
  }

  @override
  void didUpdateWidget(ListToolbar<T> old) {
    super.didUpdateWidget(old);
    // Parent cleared the search (e.g. "Clear search" in an empty state).
    if (widget.initialQuery.isEmpty &&
        old.initialQuery.isNotEmpty &&
        _controller.text.isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: _controller,
      onChanged: _changed,
      onSubmitted: (v) {
        _timer?.cancel();
        widget.onQuery(v);
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _clear,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CvRadius.sm),
        ),
      ),
    );
    DropdownButton<T> sortMenu({bool expanded = false}) => DropdownButton<T>(
      value: widget.sort,
      isExpanded: expanded,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(CvRadius.sm),
      icon: const Icon(Icons.swap_vert_rounded, size: 18),
      items: [
        for (final o in widget.sortOptions)
          DropdownMenuItem(
            value: o.value,
            child: Text(o.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) widget.onSort(v);
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Stack the controls when large text would not fit on one row.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final narrow = constraints.maxWidth < 560 * (scale < 1 ? 1 : scale);
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: CvSpace.sm),
              Semantics(label: 'Sort', child: sortMenu(expanded: true)),
              if (widget.trailing != null) ...[
                const SizedBox(height: CvSpace.sm),
                widget.trailing!,
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: CvSpace.md),
            Semantics(label: 'Sort', child: sortMenu()),
            if (widget.trailing != null) ...[
              const SizedBox(width: CvSpace.md),
              Flexible(child: widget.trailing!),
            ],
          ],
        );
      },
    );
  }
}

/// "Showing 12 of 2,000" while searching or filtering; nothing otherwise.
class MatchCount extends StatelessWidget {
  const MatchCount({
    super.key,
    required this.shown,
    required this.total,
    required this.active,
  });
  final int shown;
  final int total;
  final bool active;

  @override
  Widget build(BuildContext context) => !active
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: CvSpace.sm),
          child: Semantics(
            liveRegion: true,
            child: Text(
              'Showing $shown of $total',
              style: const TextStyle(color: CvColors.muted, fontSize: 12),
            ),
          ),
        );
}

/// Empty result for a search, with a way out.
class NoMatches extends StatelessWidget {
  const NoMatches({super.key, required this.query, required this.onClear});
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CvSpace.xl),
    child: Column(
      children: [
        Text('No matches for "$query".', textAlign: TextAlign.center),
        const SizedBox(height: CvSpace.sm),
        TextButton(onPressed: onClear, child: const Text('Clear search')),
      ],
    ),
  );
}
