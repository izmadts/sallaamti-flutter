import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/quran_live_repository.dart';

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
    return Theme(
      data: ModuleThemes.forModule('quran_live'),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Progress')),
        body: SafeArea(
          child: FutureBuilder<QuranLiveProgress>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final message = snapshot.error is ApiException ? (snapshot.error as ApiException).displayMessage : 'Something went wrong.';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _reload, child: const Text('Retry')),
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
                            const Text('Assessment Results', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            if (data.assessments.isEmpty)
                              Text('No assessments recorded yet.', style: TextStyle(color: Colors.grey.shade400))
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
                                                TextSpan(text: _titleCase(a.type.replaceAll('_', ' ')), style: const TextStyle(fontWeight: FontWeight.w600)),
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
                            const Text('Monthly Progress Reports', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            if (data.progressReports.isEmpty)
                              Text('No progress reports yet.', style: TextStyle(color: Colors.grey.shade400))
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

  String _titleCase(String s) => s.isEmpty ? s : s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
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
              Text(_monthLabel(report.month), style: const TextStyle(fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(report.overallRating.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Attendance: ${report.classesAttended}/${report.classesTotal} classes', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if ((report.quranProgress ?? '').isNotEmpty) Text('Quran Progress: ${report.quranProgress}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if ((report.behavior ?? '').isNotEmpty) Text('Behavior: ${report.behavior}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if ((report.homeworkCompletion ?? '').isNotEmpty) Text('Homework: ${report.homeworkCompletion}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          if ((report.teacherComments ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"${report.teacherComments}"', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  String _monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthIndex = int.tryParse(parts[1]);
    if (monthIndex == null || monthIndex < 1 || monthIndex > 12) return ym;
    return '${months[monthIndex - 1]} ${parts[0]}';
  }
}
