import 'dart:async';

import 'package:flutter/material.dart';

// A bottom-sheet picker backed by a debounced async search call (e.g.
// CitySearchRepository) rather than filtering an in-memory list — for
// option sets too large to preload. Includes a "Use <typed text>" row so a
// real value missing from the search results can still be entered, the
// same pick-or-type leniency the backend validation already allows.
// Originally built for the Nikah wizard's City field (nikah_step1_screen.dart)
// and extracted here once Account > Edit Profile needed the identical
// picker for its own City field.
class AsyncSearchablePicker extends StatefulWidget {
  final String title;
  final Future<List<String>> Function(String query) search;
  const AsyncSearchablePicker({super.key, required this.title, required this.search});

  @override
  State<AsyncSearchablePicker> createState() => _AsyncSearchablePickerState();
}

class _AsyncSearchablePickerState extends State<AsyncSearchablePicker> {
  final _searchController = TextEditingController();
  List<String> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      try {
        final results = await widget.search(query);
        if (mounted) setState(() => _results = results);
      } catch (_) {
        if (mounted) setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final exactMatch = _results.any(
      (r) => r.toLowerCase() == query.toLowerCase(),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  setState(() {});
                  _onSearchChanged(v);
                },
                decoration: InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                autofocus: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (query.isNotEmpty && !exactMatch)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text('Use "$query"'),
                      onTap: () => Navigator.of(context).pop(query),
                    ),
                  ..._results.map(
                    (option) => ListTile(
                      title: Text(option),
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
