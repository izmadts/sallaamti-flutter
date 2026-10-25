import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/qa_repository.dart';
import '../domain/question.dart';
import 'ask_question_sheet.dart';

class QaScreen extends ConsumerStatefulWidget {
  const QaScreen({super.key});

  @override
  ConsumerState<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends ConsumerState<QaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<Question>> _answeredFuture;
  late Future<List<Question>> _mineFuture;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _load() {
    final repo = ref.read(qaRepositoryProvider);
    _answeredFuture = repo.questions().then((p) => p.items);
    _mineFuture = repo.myQuestions().then((p) => p.items);
  }

  void _reload() => setState(_load);

  Future<void> _ask() async {
    final asked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AskQuestionSheet(),
    );
    if (asked == true && mounted) {
      _reload();
      _tabs.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('qa'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ap k Sawalat'),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Answered'), Tab(text: 'My Questions')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _ask,
          icon: const Icon(Icons.help_outline),
          label: const Text('Ask a Question'),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [
              _QuestionList(
                future: _answeredFuture,
                onRetry: _reload,
                emptyEmoji: '❓',
                emptyTitle: 'No questions answered yet',
                emptySubtitle: 'Be the first to ask something — we\'ll notify you once it\'s answered.',
                expandedId: _expandedId,
                onToggle: (id) => setState(() => _expandedId = _expandedId == id ? null : id),
              ),
              _QuestionList(
                future: _mineFuture,
                onRetry: _reload,
                emptyEmoji: '🙋',
                emptyTitle: 'You haven\'t asked anything yet',
                emptySubtitle: 'Tap "Ask a Question" and we\'ll notify you once it\'s answered.',
                expandedId: _expandedId,
                onToggle: (id) => setState(() => _expandedId = _expandedId == id ? null : id),
                showStatus: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionList extends StatelessWidget {
  final Future<List<Question>> future;
  final VoidCallback onRetry;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptySubtitle;
  final int? expandedId;
  final void Function(int) onToggle;
  final bool showStatus;

  const _QuestionList({
    required this.future,
    required this.onRetry,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.expandedId,
    required this.onToggle,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return RetryErrorView(
            message: snapshot.error is ApiException
                ? (snapshot.error as ApiException).displayMessage
                : 'Something went wrong.',
            onRetry: onRetry,
          );
        }

        final questions = snapshot.data ?? [];

        if (questions.isEmpty) {
          return EmptyStateView(emoji: emptyEmoji, title: emptyTitle, subtitle: emptySubtitle);
        }

        return RefreshIndicator(
          onRefresh: () async => onRetry(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final q = questions[index];
              final expanded = expandedId == q.id;

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: q.isAnswered ? () => onToggle(q.id) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                q.question,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                            if (showStatus && !q.isAnswered)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Awaiting answer',
                                  style: TextStyle(color: Colors.amber.shade800, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              )
                            else if (q.isAnswered)
                              Icon(expanded ? Icons.remove_circle_outline : Icons.add_circle_outline),
                          ],
                        ),
                        if (expanded && q.isAnswered) ...[
                          const SizedBox(height: 10),
                          Text(q.answer ?? '', style: const TextStyle(height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
