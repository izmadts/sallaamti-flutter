import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/html_text.dart';
import '../data/learning_repository.dart';

class LearningLessonScreen extends ConsumerStatefulWidget {
  final int lessonId;
  const LearningLessonScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LearningLessonScreen> createState() => _LearningLessonScreenState();
}

class _LearningLessonScreenState extends ConsumerState<LearningLessonScreen> {
  late Future<LearningLessonDetail> _future;
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _completing = false;
  bool _isCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _load() {
    _future = ref.read(learningRepositoryProvider).lesson(widget.lessonId).then((lesson) {
      // The server decides how much dwell time is left (it stamps started_at
      // the first time the lesson is opened); the ticker below just counts
      // that down locally so the button doesn't need polling to re-enable.
      if (mounted) {
        setState(() {
          _isCompleted = lesson.isCompleted;
          _secondsRemaining = lesson.secondsRemaining;
        });
        _startTicker();
      }
      return lesson;
    });
  }

  void _startTicker() {
    _timer?.cancel();
    if (_secondsRemaining <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) timer.cancel();
    });
  }

  void _reload() => setState(_load);

  Future<void> _openUrl(String url, String failureMessage) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    }
  }

  Future<void> _markComplete() async {
    setState(() {
      _completing = true;
      _error = null;
    });

    try {
      final message = await ref.read(learningRepositoryProvider).completeLesson(widget.lessonId);
      if (!mounted) return;
      setState(() => _isCompleted = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not mark the lesson complete. Please try again.');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningLessonDetail>(
      future: _future,
      builder: (context, snapshot) {
        final track = LearningTrack.fromKey(snapshot.data?.courseTrack);

        return Theme(
          data: ModuleThemes.forModule(track.moduleKey),
          child: Scaffold(
            appBar: AppBar(title: Text(snapshot.data?.courseTitle ?? 'Lesson')),
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

  Widget _body(BuildContext context, LearningLessonDetail lesson) {
    final color = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(lesson.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        if (lesson.videoUrl != null) ...[
          // The web embeds the video in an iframe; on a phone it's a better
          // experience to hand it to the YouTube app (or the browser), which
          // gets full-screen, casting and playback controls for free.
          _ActionTile(
            emoji: '🎬',
            title: 'Watch the lesson video',
            subtitle: 'Opens in your video player',
            color: color,
            onTap: () => _openUrl(lesson.videoUrl!, 'Could not open the video.'),
          ),
          const SizedBox(height: 14),
        ],
        if ((lesson.content ?? '').isNotEmpty)
          HtmlText(
            html: lesson.content!,
            onLinkTap: (url) => _openUrl(url, 'Could not open that link.'),
          ),
        if (lesson.fileUrl != null) ...[
          const SizedBox(height: 16),
          _ActionTile(
            emoji: '📎',
            title: lesson.fileName ?? 'Download lesson file',
            subtitle: 'Opens in your browser',
            color: color,
            onTap: () => _openUrl(lesson.fileUrl!, 'Could not open the file.'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 24),
        if (_isCompleted)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lesson complete — great job!',
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _secondsRemaining > 0 || _completing ? null : _markComplete,
            icon: _completing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _secondsRemaining > 0
                  ? 'Mark Complete in ${_secondsRemaining}s'
                  : _completing
                      ? 'Saving…'
                      : 'Mark Complete',
            ),
          ),
        if (_secondsRemaining > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Take a moment to read through the lesson first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
        if (lesson.quiz != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              await context.push('/learning/lesson/${lesson.id}/quiz?track=${lesson.courseTrack}');
              if (mounted) _reload();
            },
            icon: Text(lesson.quiz!.passed ? '✅' : '📝', style: const TextStyle(fontSize: 16)),
            label: Text(lesson.quiz!.passed ? 'Quiz passed — review' : 'Take the lesson quiz'),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            if (lesson.previousLessonId != null)
              Expanded(
                child: TextButton.icon(
                  onPressed: () => context.replace('/learning/lesson/${lesson.previousLessonId}'),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Previous'),
                ),
              ),
            if (lesson.nextLessonId != null)
              Expanded(
                child: TextButton.icon(
                  iconAlignment: IconAlignment.end,
                  onPressed: () => context.replace('/learning/lesson/${lesson.nextLessonId}'),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Next lesson'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
