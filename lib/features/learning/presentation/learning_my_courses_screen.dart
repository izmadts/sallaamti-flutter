import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/learning_repository.dart';
import 'learning_widgets.dart';

// Everything the member is enrolled in, across both tracks — the app's
// equivalent of the web's /my-learning.
class LearningMyCoursesScreen extends ConsumerStatefulWidget {
  const LearningMyCoursesScreen({super.key});

  @override
  ConsumerState<LearningMyCoursesScreen> createState() => _LearningMyCoursesScreenState();
}

class _LearningMyCoursesScreenState extends ConsumerState<LearningMyCoursesScreen> {
  late Future<List<LearningCourse>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(learningRepositoryProvider).myLearning();
  }

  void _reload() => setState(() => _future = ref.read(learningRepositoryProvider).myLearning());

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('quran'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Learning'),
          actions: [
            IconButton(
              icon: const Icon(Icons.workspace_premium_outlined),
              tooltip: 'My Certificates',
              onPressed: () => context.push('/learning/certificates'),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<List<LearningCourse>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return RetryErrorView(
                  message: snapshot.error is ApiException
                      ? (snapshot.error as ApiException).displayMessage
                      : 'Something went wrong.',
                  onRetry: _reload,
                );
              }

              final courses = snapshot.data ?? [];

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    if (courses.isEmpty)
                      EmptyStateView(
                        emoji: '🎓',
                        title: 'You haven\'t enrolled yet',
                        subtitle: 'Browse the course catalog and enroll in anything that interests you — it\'s free.',
                      )
                    else
                      for (final course in courses)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: LearningCourseCard(
                            course: course,
                            onTap: () async {
                              await context.push('/learning/course/${course.id}');
                              // Progress may have moved while they were in there.
                              if (mounted) _reload();
                            },
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
