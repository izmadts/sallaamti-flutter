import 'package:flutter/material.dart';

import '../../../shared/widgets/html_text.dart';
import '../../../shared/widgets/info_pill.dart';
import '../data/learning_repository.dart';

// The Learning-specific pieces its screens share — a course card and a
// progress bar — so the catalog, My Learning and the course detail can't
// drift into three different-looking versions of the same card. The generic
// empty/error states live in shared/widgets/state_views.dart, since the
// community screens need them too.

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
                  // Wrap, not Row — a long category name ("CMS Development")
                  // next to a long level ("Beginner to Advanced") overflowed
                  // the card's width with a plain Row, since it can't wrap
                  // pills onto a second line the way this can.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (course.category != null) InfoPill(text: course.category!, color: color, filled: true),
                      if (course.level != null) InfoPill(text: course.level!, color: color),
                      if (course.isEnrolled) InfoPill(text: '✓ Enrolled', color: Colors.green.shade700),
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
                    // Card preview needs a short flat snippet, not
                    // HtmlText's full block rendering (headings/lists have
                    // no room here) — description is Trix-authored HTML, so
                    // it's stripped to plain text first rather than shown
                    // with its markup, or truncated mid-tag.
                    Text(
                      stripHtmlToText(course.description),
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

