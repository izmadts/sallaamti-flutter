import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/quran_live_repository.dart';

class QuranLiveMyClassScreen extends ConsumerStatefulWidget {
  const QuranLiveMyClassScreen({super.key});

  @override
  ConsumerState<QuranLiveMyClassScreen> createState() => _QuranLiveMyClassScreenState();
}

class _QuranLiveMyClassScreenState extends ConsumerState<QuranLiveMyClassScreen> {
  late Future<QuranLiveMyClass> _future;
  int? _selectedChildId;
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _load() => _future = ref.read(quranLiveRepositoryProvider).myClass(childId: _selectedChildId);

  Future<void> _reload() async => setState(_load);

  void _switchChild(int id) {
    setState(() {
      _selectedChildId = id;
      _load();
    });
  }

  Future<void> _sendMessage(int admissionId) async {
    final l10n = AppLocalizations.of(context)!;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref.read(quranLiveRepositoryProvider).sendMessage(admissionId, text);
      _messageController.clear();
      await _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.quranLiveSendMessageError)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _joinClass(String url) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.quranLiveOpenClassLinkError)));
    }
  }

  String _admissionStatusLabel(AppLocalizations l10n, String status) => {
        'pending': l10n.quranAdmissionStatusPending,
        'rejected': l10n.quranAdmissionStatusRejected,
        'assigned': l10n.quranAdmissionStatusAssigned,
        'completed': l10n.quranAdmissionStatusCompleted,
        'dropped': l10n.quranAdmissionStatusDropped,
      }[status] ?? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('quran_live'),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.quranLiveMyClassTitle)),
        body: SafeArea(
          child: FutureBuilder<QuranLiveMyClass>(
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

              if (data.groupStudents.isEmpty) {
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
                              Text(
                                data.admissions.isEmpty ? l10n.quranLiveNoAdmissionYetMessage : l10n.quranLiveNoGroupAssignedMessage,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.quranLiveAdmissionReviewMessage,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              if (data.admissions.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(l10n.quranLiveYourApplicationsTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                ...data.admissions.map((a) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${a.studentName} — ${a.courseTitle} — ${_admissionStatusLabel(l10n, a.status)}', style: const TextStyle(fontSize: 13)),
                                          if (a.status == 'rejected' && (a.adminNotes ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(a.adminNotes!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ],
                                      ),
                                    )),
                              ],
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: () => context.push('/quran-live'), child: Text(l10n.quranLiveApplyForCourseButton)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final current = data.groupStudents.firstWhere((gs) => gs.id == data.currentId, orElse: () => data.groupStudents.first);

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
                          final selected = gs.id == current.id;
                          return ChoiceChip(label: Text(gs.studentName), selected: selected, onSelected: (_) => _switchChild(gs.id));
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
                            Text(l10n.quranLiveStudentClassDetailsTitle(current.studentName), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            _detailRow(l10n.courseLabel, current.courseTitle),
                            _detailRow(l10n.groupLabel, current.groupName),
                            _detailRow(l10n.teacherLabel, current.teacher?.name ?? l10n.quranLiveTeacherTba),
                            _detailRow(l10n.scheduleLabel, '${current.classDays.join(', ')} — ${current.classTime ?? ''}'),
                            if (current.timezone != null) _detailRow(l10n.timezoneLabel, current.timezone!),
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
                            Text(l10n.quranLiveMonthlyFeeTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            _buildSubscriptionStatus(l10n, current),
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
                            Text(l10n.quranLiveMessagesWithLabel(current.teacher?.name ?? l10n.quranLiveYourTeacherFallback), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 12),
                            if (data.messages.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: Text(l10n.quranLiveNoMessagesYetMessage, style: TextStyle(color: Colors.grey.shade400))),
                              )
                            else
                              Column(
                                children: data.messages.map((m) => _MessageBubble(message: m)).toList(),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    decoration: InputDecoration(hintText: l10n.quranLiveMessageHint),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: _sending ? null : () => _sendMessage(current.admissionId),
                                  icon: _sending
                                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.send, size: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/quran-live/my-progress?child=${current.id}'),
                        child: Text(l10n.quranLiveViewProgressButton),
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

  Widget _buildSubscriptionStatus(AppLocalizations l10n, QuranLiveGroupStudentInfo current) {
    final subscription = current.subscription;
    if (subscription == null) {
      return Text(l10n.quranLiveNoPaymentSubmittedMessage, style: TextStyle(color: Colors.red.shade600));
    }
    if (subscription.paymentStatus == 'submitted') {
      return Text(l10n.quranLivePaymentUnderReviewBadge, style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600));
    }
    if (subscription.paymentStatus == 'rejected') {
      return Text(l10n.quranLivePaymentRejectedLabel(subscription.paymentRejectionReason ?? ''), style: const TextStyle(color: Colors.red));
    }
    if (subscription.paymentStatus == 'confirmed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.quranLivePaidConfirmedMessage, style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (current.todaysLink != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), border: Border.all(color: const Color(0xFFBBF7D0)), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.quranLiveClassLiveNowTitle, style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                    onPressed: () => _joinClass(current.todaysLink!.joinUrl),
                    icon: const Icon(Icons.videocam),
                    label: Text(l10n.quranLiveJoinClassButton),
                  ),
                  if (current.todaysLink!.passcode != null) ...[
                    const SizedBox(height: 8),
                    Text(l10n.quranLivePasscodeLabel(current.todaysLink!.passcode!), style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ],
              ),
            )
          else
            Text(
              current.classTime != null ? l10n.quranLiveLinkNotPostedWithTimeMessage(current.classTime!) : l10n.quranLiveLinkNotPostedNoTimeMessage,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final QuranLiveMessageInfo message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isMine ? const Color(0xFF0D6B6B) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.isMine ? l10n.youLabel : (message.senderName ?? l10n.teacherLabel),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: message.isMine ? Colors.white70 : Colors.grey.shade500),
            ),
            const SizedBox(height: 2),
            Text(message.message, style: TextStyle(color: message.isMine ? Colors.white : Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }
}
