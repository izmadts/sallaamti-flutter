import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/quran_live_repository.dart';

String _assessmentTypeLabel(AppLocalizations l10n, String type) => {
      'weekly_quiz': l10n.assessmentTypeWeeklyQuiz,
      'monthly_test': l10n.assessmentTypeMonthlyTest,
      'quarterly_exam': l10n.assessmentTypeQuarterlyExam,
      'annual_exam': l10n.assessmentTypeAnnualExam,
    }[type] ?? type;

String _ratingLabel(AppLocalizations l10n, String rating) => {
      'excellent': l10n.ratingExcellent,
      'good': l10n.ratingGood,
      'average': l10n.ratingAverage,
      'needs_improvement': l10n.ratingNeedsImprovement,
    }[rating] ?? rating;

class QuranLiveMyProgressScreen extends ConsumerStatefulWidget {
  final int? childId;
  const QuranLiveMyProgressScreen({super.key, this.childId});

  @override
  ConsumerState<QuranLiveMyProgressScreen> createState() => _QuranLiveMyProgressScreenState();
}

class _QuranLiveMyProgressScreenState extends ConsumerState<QuranLiveMyProgressScreen> {
  late Future<QuranLiveProgress> _future;
  int? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.childId;
    _load();
  }

  void _load() => _future = ref.read(quranLiveRepositoryProvider).myProgress(childId: _selectedChildId);

  Future<void> _reload() async => setState(_load);

  void _switchChild(int id) {
    setState(() {
      _selectedChildId = id;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('quran_live'),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.quranLiveMyProgressTitle)),
        body: SafeArea(
          child: FutureBuilder<QuranLiveProgress>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final message = snapshot.error is ApiException ? (snapshot.error as ApiException).displayMessage : l10n.quranLiveSomethingWentWrong;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _reload, child: Text(l10n.retry)),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.data!;
              final currentId = data.currentId ?? (data.groupStudents.isNotEmpty ? data.groupStudents.first.id : null);

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (data.groupStudents.length > 1) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: data.groupStudents.map((gs) {
                          return ChoiceChip(label: Text(gs.studentName), selected: gs.id == currentId, onSelected: (_) => _switchChild(gs.id));
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.quranLiveAssessmentResultsTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            if (data.assessments.isEmpty)
                              Text(l10n.quranLiveNoAssessmentsMessage, style: TextStyle(color: Colors.grey.shade400))
                            else
                              ...data.assessments.map((a) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text.rich(TextSpan(children: [
                                                TextSpan(text: _assessmentTypeLabel(l10n, a.type), style: const TextStyle(fontWeight: FontWeight.w600)),
                                                TextSpan(text: '  ${a.assessmentDate}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                              ])),
                                            ),
                                            Row(
                                              children: [
                                                Text('${a.score}/100', style: TextStyle(color: Colors.grey.shade600)),
                                                const SizedBox(width: 10),
                                                Text(
                                                  a.grade,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                    color: a.grade == 'F' ? Colors.red : (a.grade.compareTo('B') <= 0 ? Colors.green : Colors.amber.shade800),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if ((a.remarks ?? '').isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(a.remarks!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                          ),
                                        const Divider(height: 16),
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.quranLiveMonthlyProgressReportsTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            if (data.progressReports.isEmpty)
                              Text(l10n.quranLiveNoProgressReportsMessage, style: TextStyle(color: Colors.grey.shade400))
                            else
                              ...data.progressReports.map((r) => _ProgressReportCard(report: r)),
                          ],
                        ),
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

const _ratingColors = {
  'excellent': Color(0xFF166534),
  'good': Color(0xFF1D4ED8),
  'average': Color(0xFFB45309),
};

const _ratingBg = {
  'excellent': Color(0xFFDCFCE7),
  'good': Color(0xFFDBEAFE),
  'average': Color(0xFFFEF3C7),
};

class _ProgressReportCard extends StatelessWidget {
  final QuranLiveProgressReportInfo report;
  const _ProgressReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _ratingColors[report.overallRating] ?? Colors.red.shade700;
    final bg = _ratingBg[report.overallRating] ?? Colors.red.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_monthLabel(l10n, report.month), style: const TextStyle(fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(_ratingLabel(l10n, report.overallRating), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.quranLiveAttendanceLabel(report.classesAttended, report.classesTotal), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if ((report.quranProgress ?? '').isNotEmpty) Text(l10n.quranLiveProgressLabel(report.quranProgress!), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if ((report.behavior ?? '').isNotEmpty) Text(l10n.quranLiveBehaviorLabel(report.behavior!), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if ((report.homeworkCompletion ?? '').isNotEmpty) Text(l10n.quranLiveHomeworkLabel(report.homeworkCompletion!), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if ((report.teacherComments ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"${report.teacherComments}"', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  String _monthLabel(AppLocalizations l10n, String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final months = [
      l10n.monthAbbrevJan, l10n.monthAbbrevFeb, l10n.monthAbbrevMar, l10n.monthAbbrevApr,
      l10n.monthAbbrevMay, l10n.monthAbbrevJun, l10n.monthAbbrevJul, l10n.monthAbbrevAug,
      l10n.monthAbbrevSep, l10n.monthAbbrevOct, l10n.monthAbbrevNov, l10n.monthAbbrevDec,
    ];
    final monthIndex = int.tryParse(parts[1]);
    if (monthIndex == null || monthIndex < 1 || monthIndex > 12) return ym;
    return '${months[monthIndex - 1]} ${parts[0]}';
  }
}
