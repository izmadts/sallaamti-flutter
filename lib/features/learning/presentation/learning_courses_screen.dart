import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/learning_repository.dart';
import 'learning_widgets.dart';

// The catalog for one track — 'quran' arrives here from the Quran hub's
// Self-Paced Learning card, 'skills' straight from the dashboard's Skills
// tile. Same screen either way; only the branding and copy differ.
class LearningCoursesScreen extends ConsumerStatefulWidget {
  final String trackKey;
  const LearningCoursesScreen({super.key, required this.trackKey});

  @override
  ConsumerState<LearningCoursesScreen> createState() => _LearningCoursesScreenState();
}

class _LearningCoursesScreenState extends ConsumerState<LearningCoursesScreen> {
  late Future<LearningCatalog> _future;
  String? _category;

  LearningTrack get _track => LearningTrack.fromKey(widget.trackKey);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(learningRepositoryProvider).courses(track: _track.key, category: _category);
  }

  void _reload() => setState(_load);

  void _selectCategory(String? category) {
    setState(() {
      _category = category;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule(_track.moduleKey),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_track.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.workspace_premium_outlined),
              tooltip: 'My Certificates',
              onPressed: () => context.push('/learning/certificates'),
            ),
            IconButton(
              icon: const Icon(Icons.school_outlined),
              tooltip: 'My Learning',
              onPressed: () => context.push('/learning/my-courses'),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<LearningCatalog>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return LearningErrorView(
                  message: snapshot.error is ApiException
                      ? (snapshot.error as ApiException).displayMessage
                      : 'Something went wrong.',
                  onRetry: _reload,
                );
              }

              final catalog = snapshot.data!;

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Text(
                      '${_track.emoji}  ${_track.title}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(_track.tagline, style: TextStyle(color: Colors.grey.shade600)),
                    if (catalog.categories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CategoryChip(
                              label: 'All',
                              selected: _category == null,
                              onTap: () => _selectCategory(null),
                            ),
                            for (final category in catalog.categories)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _CategoryChip(
                                  label: category,
                                  selected: _category == category,
                                  onTap: () => _selectCategory(category),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (catalog.courses.isEmpty)
                      LearningEmptyView(
                        emoji: _track.emoji,
                        title: 'No courses yet',
                        subtitle: _category != null
                            ? 'Nothing in this category right now — try another one.'
                            : 'New courses are added regularly. Check back soon.',
                      )
                    else
                      for (final course in catalog.courses)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: LearningCourseCard(
                            course: course,
                            onTap: () => context.push('/learning/course/${course.id}'),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Material(
      color: selected ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
