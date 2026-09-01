import 'package:flutter/material.dart';

import '../data/learning_repository.dart';

// The pieces the Learning screens share — a course card, a progress bar, and
// the empty/error states. Kept together so the catalog, My Learning and the
// course detail can't drift into three different-looking versions of the
// same card.

class LearningProgressBar extends StatelessWidget {
  final int progress;
  final int completed;
  final int total;
  final bool showLabel;

  const LearningProgressBar({
    super.key,
    required this.progress,
    required this.completed,
    required this.total,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (progress / 100).clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            '$completed of $total lessons · $progress%',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class LearningCourseCard extends StatelessWidget {
  final LearningCourse course;
  final VoidCallback onTap;

  const LearningCourseCard({super.key, required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (course.thumbnailUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  course.thumbnailUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // A missing thumbnail file shouldn't leave a broken box in
                  // the middle of the catalog — the card reads fine without it.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (course.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            course.category!,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (course.level != null) ...[
                        if (course.category != null) const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            course.level!,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      if (course.isEnrolled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '✓ Enrolled',
                            style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    course.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((course.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      course.description!,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (course.isEnrolled)
                    LearningProgressBar(
                      progress: course.progress,
                      completed: course.completedLessons,
                      total: course.lessonsCount,
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📚 ${course.lessonsCount} ${course.lessonsCount == 1 ? 'lesson' : 'lessons'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'View Course →',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                        ),
                      ],
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

class LearningErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const LearningErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class LearningEmptyView extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const LearningEmptyView({super.key, required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
