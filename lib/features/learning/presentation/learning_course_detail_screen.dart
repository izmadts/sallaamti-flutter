import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/html_text.dart';
import '../data/learning_repository.dart';
import 'learning_widgets.dart';

class LearningCourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const LearningCourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<LearningCourseDetailScreen> createState() => _LearningCourseDetailScreenState();
}

class _LearningCourseDetailScreenState extends ConsumerState<LearningCourseDetailScreen> {
  late Future<LearningCourseDetail> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(learningRepositoryProvider).courseDetail(widget.courseId);
  }

  void _reload() => setState(_load);

  Future<void> _enroll() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final message = await ref.read(learningRepositoryProvider).enroll(widget.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      _reload();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not enroll you just now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Submits the request — it comes back pending, not a downloadable file
  // (an admin has to approve it first), so this only reloads to show that
  // state rather than trying to download anything.
  Future<void> _requestCertificate() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(learningRepositoryProvider).generateCertificate(widget.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificate requested! You\'ll be notified once it\'s reviewed.')),
      );
      _reload();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not submit your request — please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadCertificate(LearningCertificate certificate) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final file = await ref.read(learningRepositoryProvider).downloadCertificate(certificate);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Sallaamti Certificate'),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not prepare your certificate — please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningCourseDetail>(
      future: _future,
      builder: (context, snapshot) {
        final track = LearningTrack.fromKey(snapshot.data?.course.track);

        return Theme(
          data: ModuleThemes.forModule(track.moduleKey),
          child: Scaffold(
            appBar: AppBar(title: Text(snapshot.data?.course.title ?? 'Course')),
            body: SafeArea(
              child: Builder(
                builder: (context) {
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

                  return _body(context, snapshot.data!);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, LearningCourseDetail detail) {
    final course = detail.course;
    final color = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (course.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                course.thumbnailUrl!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (course.thumbnailUrl != null) const SizedBox(height: 16),
          Text(course.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (course.category != null) _Pill(text: course.category!, color: color, filled: true),
              if (course.level != null) _Pill(text: course.level!, color: color),
              _Pill(text: '📚 ${course.lessonsCount} lessons', color: color),
              if (course.minAge != null || course.maxAge != null)
                _Pill(
                  text: '🎂 ${course.minAge ?? 0}${course.maxAge != null ? '–${course.maxAge}' : '+'}',
                  color: color,
                ),
            ],
          ),
          if ((course.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            // Authored via Trix on the web admin form — real HTML, not
            // plain text, so it needs HtmlText rather than a bare Text().
            HtmlText(
              html: course.description!,
              baseStyle: TextStyle(fontSize: 14.5, height: 1.5, color: Colors.grey.shade700),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 18),
          if (!course.isEnrolled)
            ElevatedButton.icon(
              onPressed: _busy ? null : _enroll,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_circle_outline),
              label: Text(_busy ? 'Enrolling…' : 'Enroll — it\'s free'),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your progress', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  LearningProgressBar(
                    progress: course.progress,
                    completed: course.completedLessons,
                    total: course.lessonsCount,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text('Lessons', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (detail.lessons.isEmpty)
            EmptyStateView(
              emoji: '📝',
              title: 'No lessons yet',
              subtitle: 'This course is still being prepared. Check back soon.',
            )
          else
            for (var i = 0; i < detail.lessons.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LessonTile(
                  lesson: detail.lessons[i],
                  index: i + 1,
                  // Lessons only open once the member is enrolled — the API
                  // enforces this too, this just avoids a pointless 403.
                  enabled: course.isEnrolled,
                  onTap: () async {
                    await context.push('/learning/lesson/${detail.lessons[i].id}');
                    // Coming back from a lesson, progress may have moved.
                    if (mounted) _reload();
                  },
                ),
              ),
          if (detail.finalQuiz != null) ...[
            const SizedBox(height: 12),
            _FinalQuizCard(
              quiz: detail.finalQuiz!,
              unlocked: detail.finalQuizUnlocked && course.isEnrolled,
              onTap: () async {
                await context.push('/learning/course/${course.id}/quiz?track=${course.track}');
                if (mounted) _reload();
              },
            ),
          ],
          if (course.isEnrolled) ...[
            const SizedBox(height: 20),
            _CertificateCard(
              detail: detail,
              busy: _busy,
              onRequest: _requestCertificate,
              onDownload: () => _downloadCertificate(detail.certificate!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;

  const _Pill({required this.text, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? Colors.white : color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final LearningLessonSummary lesson;
  final int index;
  final bool enabled;
  final VoidCallback onTap;

  const _LessonTile({required this.lesson, required this.index, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final done = lesson.isCompleted;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: done ? Colors.green.shade50 : color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? Icon(Icons.check, size: 18, color: Colors.green.shade700)
                      : Text('$index', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lesson.hasVideo || lesson.hasFile || lesson.quiz != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (lesson.hasVideo) '🎬 Video',
                            if (lesson.hasFile) '📎 File',
                            if (lesson.quiz != null) lesson.quiz!.passed ? '✅ Quiz passed' : '📝 Quiz',
                          ].join('  ·  '),
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(enabled ? Icons.chevron_right : Icons.lock_outline, color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinalQuizCard extends StatelessWidget {
  final LearningQuizSummary quiz;
  final bool unlocked;
  final VoidCallback onTap;

  const _FinalQuizCard({required this.quiz, required this.unlocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Material(
      color: unlocked ? color.withValues(alpha: 0.08) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: unlocked ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(quiz.passed ? '🏆' : '📋', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Final Quiz — ${quiz.title}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      quiz.passed
                          ? 'Passed — well done!'
                          : unlocked
                              ? 'Pass with ${quiz.passingPercentage}% to earn your certificate.'
                              : 'Finish every lesson (and its quiz) to unlock this.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(unlocked ? Icons.chevron_right : Icons.lock_outline, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final LearningCourseDetail detail;
  final bool busy;
  final VoidCallback onRequest;
  final VoidCallback onDownload;

  const _CertificateCard({
    required this.detail,
    required this.busy,
    required this.onRequest,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final certificate = detail.certificate;
    final eligible = detail.certificateEligible;
    // Locked until the course is actually finished; from there a request
    // goes to admin, and only their approval unlocks the download — there's
    // no self-service instant certificate any more.
    final emoji = !eligible
        ? '🔒'
        : certificate == null
            ? '🏅'
            : certificate.isPending
                ? '⏳'
                : certificate.isRejected
                    ? '❌'
                    : '🏅';
    final gold = eligible && (certificate == null || certificate.isApproved);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gold ? const LinearGradient(colors: [Color(0xFFB8962E), Color(0xFFD4AF37)]) : null,
        color: gold ? null : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            _title(certificate),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: gold ? Colors.white : Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle(certificate, eligible),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: gold ? Colors.white70 : Colors.grey.shade600),
          ),
          if (eligible && (certificate == null || certificate.isRejected)) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF8A6D1F),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: busy ? null : onRequest,
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined),
                label: Text(busy ? 'Submitting…' : (certificate == null ? 'Request Certificate' : 'Request Again')),
              ),
            ),
          ] else if (certificate != null && certificate.isApproved) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF8A6D1F),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: busy ? null : onDownload,
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined),
                label: Text(busy ? 'Preparing…' : 'Download Certificate'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _title(LearningCertificate? certificate) {
    if (certificate == null) return 'Course Certificate';
    if (certificate.isPending) return 'Request submitted';
    if (certificate.isRejected) return 'Not approved';
    return 'Your certificate is ready';
  }

  String _subtitle(LearningCertificate? certificate, bool eligible) {
    if (!eligible) return 'Complete every lesson and pass the quizzes to unlock this.';
    if (certificate == null) return 'You\'ve finished everything — request your certificate.';
    if (certificate.isPending) return 'Awaiting admin review — you\'ll be notified once it\'s decided.';
    if (certificate.isRejected) return certificate.rejectionReason?.isNotEmpty == true ? certificate.rejectionReason! : 'You can submit another request.';
    return certificate.certificateNumber ?? '';
  }
}
