import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/error_banner.dart';
import '../data/learning_repository.dart';

// One screen for both quiz kinds — a lesson quiz and a course's final quiz
// are identical to sit, they differ only in which endpoint they load from
// and submit to, so `isFinal` picks the pair rather than duplicating the
// screen.
class LearningQuizScreen extends ConsumerStatefulWidget {
  final int ownerId;
  final bool isFinal;
  final String trackKey;

  const LearningQuizScreen({
    super.key,
    required this.ownerId,
    required this.isFinal,
    this.trackKey = 'quran',
  });

  @override
  ConsumerState<LearningQuizScreen> createState() => _LearningQuizScreenState();
}

class _LearningQuizScreenState extends ConsumerState<LearningQuizScreen> {
  late Future<LearningQuizDetail> _future;
  final Map<int, int> _answers = {};
  bool _submitting = false;
  String? _error;
  LearningQuizAttempt? _result;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = ref.read(learningRepositoryProvider);
    _future = widget.isFinal ? repository.courseQuiz(widget.ownerId) : repository.lessonQuiz(widget.ownerId);
  }

  void _reload() => setState(() {
        _answers.clear();
        _result = null;
        _resultMessage = null;
        _error = null;
        _load();
      });

  Future<void> _submit(LearningQuizDetail quiz) async {
    final unanswered = quiz.questions.where((q) => !_answers.containsKey(q.id)).length;
    if (unanswered > 0) {
      setState(() => _error = 'Please answer all $unanswered remaining '
          '${unanswered == 1 ? 'question' : 'questions'} before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repository = ref.read(learningRepositoryProvider);
      final (attempt, message) = widget.isFinal
          ? await repository.submitCourseQuiz(widget.ownerId, _answers)
          : await repository.submitLessonQuiz(widget.ownerId, _answers);

      if (!mounted) return;
      setState(() {
        _result = attempt;
        _resultMessage = message;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not submit your answers. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = LearningTrack.fromKey(widget.trackKey);

    return Theme(
      data: ModuleThemes.forModule(track.moduleKey),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.isFinal ? 'Final Quiz' : 'Lesson Quiz')),
        body: SafeArea(
          child: FutureBuilder<LearningQuizDetail>(
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

              return _body(context, snapshot.data!);
            },
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, LearningQuizDetail quiz) {
    if (_result != null) {
      return _ResultView(
        attempt: _result!,
        message: _resultMessage ?? '',
        passingPercentage: quiz.passingPercentage,
        onRetry: _reload,
        onDone: () => Navigator.of(context).pop(),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(quiz.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Pass mark: ${quiz.passingPercentage}%  ·  ${quiz.questions.length} '
          '${quiz.questions.length == 1 ? 'question' : 'questions'}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        if (quiz.bestAttempt != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: quiz.bestAttempt!.passed ? Colors.green.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(quiz.bestAttempt!.passed ? '🏆' : '📊', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your best so far: ${quiz.bestAttempt!.scorePercentage}%'
                    '${quiz.bestAttempt!.passed ? ' — passed' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: quiz.bestAttempt!.passed ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (quiz.questions.isEmpty)
          EmptyStateView(
            emoji: '📋',
            title: 'No questions yet',
            subtitle: 'This quiz is still being prepared.',
          )
        else
          for (var i = 0; i < quiz.questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _QuestionCard(
                question: quiz.questions[i],
                index: i + 1,
                selected: _answers[quiz.questions[i].id],
                onSelect: (option) => setState(() {
                  _answers[quiz.questions[i].id] = option;
                  _error = null;
                }),
              ),
            ),
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 14),
        ],
        if (quiz.questions.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _submitting ? null : () => _submit(quiz),
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined),
            label: Text(_submitting ? 'Submitting…' : 'Submit Answers'),
          ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final LearningQuizQuestion question;
  final int index;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$index', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected == i ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          selected == i ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 20,
                          color: selected == i ? color : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            question.options[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected == i ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final LearningQuizAttempt attempt;
  final String message;
  final int passingPercentage;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  const _ResultView({
    required this.attempt,
    required this.message,
    required this.passingPercentage,
    required this.onRetry,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final passed = attempt.passed;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(passed ? '🎉' : '💪', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              '${attempt.scorePercentage}%',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: passed ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              passed ? 'Passed!' : 'Not quite yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message.isNotEmpty
                  ? message
                  : 'You need $passingPercentage% to pass.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onDone, child: Text(passed ? 'Continue' : 'Back to lesson')),
            ),
            if (!passed) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
