import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/info_pill.dart';
import '../data/quran_live_repository.dart';

class QuranLiveCourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const QuranLiveCourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<QuranLiveCourseDetailScreen> createState() => _QuranLiveCourseDetailScreenState();
}

class _QuranLiveCourseDetailScreenState extends ConsumerState<QuranLiveCourseDetailScreen> {
  late Future<(QuranLiveCourseInfo, List<QuranLiveAdmissionInfo>)> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(quranLiveRepositoryProvider).courseDetail(widget.courseId);

  Future<void> _reload() async => setState(_load);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('quran_live'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Live Class Details'),
          actions: [
            // This screen's own admission card tells a confirmed parent to
            // "see My Class to join" but had no way to actually get there —
            // the only way in was via this icon on the catalog list screen,
            // one navigation hop back.
            IconButton(
              icon: const Icon(Icons.school_outlined),
              tooltip: 'My Class',
              onPressed: () => context.push('/quran-live/my-class'),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<(QuranLiveCourseInfo, List<QuranLiveAdmissionInfo>)>(
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

              final (course, admissions) = snapshot.data!;

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(course.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            if ((course.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(course.description!, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                            ],
                            const SizedBox(height: 10),
                            Text('Teacher: ${course.teacher?.name ?? 'TBA'} · ${course.classTime ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('Rs. ${course.monthlyFee}/month', style: const TextStyle(color: Color(0xFFB8962E), fontWeight: FontWeight.w800)),
                            if (course.minAge != null || course.maxAge != null || course.genderPreference != null && course.genderPreference != 'both') ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (course.minAge != null || course.maxAge != null)
                                    InfoPill(text: '🎂 Ages ${course.minAge ?? 0}${course.maxAge != null ? '–${course.maxAge}' : '+'}', color: const Color(0xFF0D6B6B)),
                                  // 'both' means no restriction — showing it as
                                  // a badge would read as a restriction that
                                  // doesn't exist.
                                  if (course.genderPreference == 'male') const InfoPill(text: '♂ Boys only', color: Color(0xFF0D6B6B)),
                                  if (course.genderPreference == 'female') const InfoPill(text: '♀ Girls only', color: Color(0xFF0D6B6B)),
                                ],
                              ),
                            ],
                            if (course.topics.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Text('What you\'ll cover', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              ...course.topics.map((t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(t, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(14)),
                      child: const Row(
                        children: [
                          Text('🛡️', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'For your child\'s safety, all classes are recorded and teachers are vetted. You can message the teacher any time from My Class.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF7A5C00)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (admissions.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Register for this Class', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => context.push('/quran-live/${course.id}/admission'),
                                child: const Text('Apply for Admission'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ...admissions.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AdmissionStatusCard(courseId: course.id, admission: a),
                          )),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/quran-live/${course.id}/admission'),
                          child: const Text('+ Apply for another child'),
                        ),
                      ),
                    ],
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

class _AdmissionStatusCard extends StatelessWidget {
  final int courseId;
  final QuranLiveAdmissionInfo admission;
  const _AdmissionStatusCard({required this.courseId, required this.admission});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(admission.studentName.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _body(context),
          ],
        ),
      ),
    );
  }

  // admission.status used to be ignored entirely here — every branch below
  // assumed "this admission is approved and just needs paying," which meant
  // a still-PENDING or already-REJECTED application showed the exact same
  // "Pay This Month's Fee" prompt as an approved one.
  Widget _body(BuildContext context) {
    if (admission.isPending) {
      return Text(
        '⏳ Your application is under review — our team will assign a class group shortly.',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      );
    }

    if (admission.isRejected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('❌ This application wasn\'t approved.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          if ((admission.adminNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(admission.adminNotes!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          ],
        ],
      );
    }

    if (admission.isCompleted) {
      return const Text('🎓 Course completed — congratulations!', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700));
    }

    if (admission.isDropped) {
      return Text(
        'This admission is no longer active. Contact us if you\'d like to re-enroll.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      );
    }

    // isAssigned from here — the group is set, so it's a normal fee cycle.
    final subscription = admission.subscription;

    if (subscription == null || subscription.paymentStatus == 'unpaid') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💳 This month\'s fee payment required.', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => context.push('/quran-live/$courseId/subscribe/${admission.id}'),
            child: const Text('Pay This Month\'s Fee'),
          ),
        ],
      );
    }

    if (subscription.paymentStatus == 'submitted') {
      return const Text('⏳ Payment under review.', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600));
    }

    if (subscription.paymentStatus == 'rejected') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('❌ Rejected: ${subscription.paymentRejectionReason ?? ''}', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => context.push('/quran-live/$courseId/subscribe/${admission.id}'),
            child: const Text('Resubmit Payment'),
          ),
        ],
      );
    }

    // confirmed
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('✅ Active for ${subscription.month}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (admission.todaysLink != null)
          Material(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/quran-live/my-class'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: const Row(
                  children: [
                    Icon(Icons.videocam, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Today\'s class link is ready',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Color(0xFF16A34A)),
                  ],
                ),
              ),
            ),
          )
        else
          Text('Today\'s link hasn\'t been posted yet by your teacher. Check back closer to class time.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
      ],
    );
  }
}
