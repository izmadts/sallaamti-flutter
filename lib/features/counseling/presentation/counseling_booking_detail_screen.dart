import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/counseling_repository.dart';
import 'counseling_screen.dart' show counselingCategoryLabel, counselingContactMethodLabel, counselingStatusLabel;

class CounselingBookingDetailScreen extends ConsumerStatefulWidget {
  final int bookingId;
  const CounselingBookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<CounselingBookingDetailScreen> createState() => _CounselingBookingDetailScreenState();
}

class _CounselingBookingDetailScreenState extends ConsumerState<CounselingBookingDetailScreen> {
  CounselingBookingInfo? _booking;
  bool _loading = true;
  String? _error;

  final _replyController = TextEditingController();
  bool _sendingReply = false;

  bool _cancelling = false;
  int _ratingInput = 5;
  final _feedbackController = TextEditingController();
  bool _rating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking = await ref.read(counselingRepositoryProvider).bookingDetail(widget.bookingId);
      setState(() => _booking = booking);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      // Called from initState() — looked up after the await above rather
      // than hoisted, since Localizations isn't registered yet that early.
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final l10n = AppLocalizations.of(context)!;
    final message = _replyController.text.trim();
    if (message.isEmpty || _sendingReply) return;

    setState(() => _sendingReply = true);
    try {
      await ref.read(counselingRepositoryProvider).reply(widget.bookingId, message);
      _replyController.clear();
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.counselingSendReplyError)));
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelSessionTitle),
        content: Text(l10n.cancelSessionConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.noLabel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.yesCancelLabel)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      final updated = await ref.read(counselingRepositoryProvider).cancel(widget.bookingId);
      setState(() => _booking = updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.counselingCancelError)));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _submitRating() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _rating = true);
    try {
      final updated = await ref.read(counselingRepositoryProvider).rate(
            widget.bookingId,
            rating: _ratingInput,
            feedback: _feedbackController.text.trim().isEmpty ? null : _feedbackController.text.trim(),
          );
      setState(() => _booking = updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.counselingRatingError)));
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('counseling'),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.sessionDetailsTitle)),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _booking == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? l10n.notFoundLabel, textAlign: TextAlign.center)));
    }

    final booking = _booking!;
    final canCancel = !['completed', 'cancelled', 'no_show'].contains(booking.status);
    final canRate = booking.status == 'completed' && booking.memberRating == null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: Text(booking.subject ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            _StatusPill(status: booking.status),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(l10n.categoryLabel, booking.category != null ? counselingCategoryLabel(l10n, booking.category) : '—'),
                _row(l10n.whenLabel, DateFormat('d MMM yyyy, h:mm a').format(booking.scheduledAt.toLocal())),
                _row(l10n.contactLabel, booking.contactMethod != null ? counselingContactMethodLabel(l10n, booking.contactMethod) : '—'),
                _row(l10n.counselorLabel, booking.counselor?.name ?? l10n.notYetAssignedLabel),
                if ((booking.meetingLink ?? '').isNotEmpty) _row(l10n.meetingLinkLabel, booking.meetingLink!),
                if (booking.isUrgent) _row(l10n.urgentLabel, l10n.yesLabel),
                if (booking.isAnonymous) _row(l10n.anonymousLabel, l10n.yesLabel),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if ((booking.description ?? '').isNotEmpty) ...[
          Text(l10n.descriptionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(booking.description!),
          const SizedBox(height: 16),
        ],
        if (booking.status == 'cancelled' && (booking.cancellationReason ?? '').isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: Text(l10n.cancelledReasonLabel(booking.cancellationReason ?? ''), style: TextStyle(color: Colors.red.shade700)),
          ),
          const SizedBox(height: 16),
        ],
        if (canCancel) ...[
          OutlinedButton(
            onPressed: _cancelling ? null : _cancel,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: _cancelling
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.cancelSessionButton),
          ),
          const SizedBox(height: 20),
        ],
        if (canRate) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.howWasYourSessionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starIndex = i + 1;
                      return IconButton(
                        onPressed: () => setState(() => _ratingInput = starIndex),
                        icon: Icon(
                          starIndex <= _ratingInput ? Icons.star : Icons.star_border,
                          color: Colors.amber.shade600,
                        ),
                      );
                    }),
                  ),
                  TextFormField(
                    controller: _feedbackController,
                    decoration: InputDecoration(hintText: l10n.anyFeedbackHint),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _rating ? null : _submitRating,
                    child: _rating
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l10n.submitRatingButton),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ] else if (booking.memberRating != null) ...[
          Row(
            children: [
              Text(l10n.yourRatingLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ...List.generate(5, (i) => Icon(i < booking.memberRating! ? Icons.star : Icons.star_border, size: 18, color: Colors.amber.shade600)),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const Divider(),
        const SizedBox(height: 8),
        Text(l10n.messagesLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (booking.responses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l10n.noMessagesYetMessage, style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          for (final response in booking.responses)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(response.responder?.name ?? l10n.someoneFallback, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(response.message),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d MMM, h:mm a').format(response.createdAt.toLocal()),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                decoration: InputDecoration(hintText: l10n.writeAMessageHint, isDense: true),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: _sendingReply
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              onPressed: _sendingReply ? null : _sendReply,
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = counselingStatusLabel(l10n, status);
    final color = switch (status) {
      'confirmed' => Colors.green,
      'completed' => Colors.blue,
      'cancelled' => Colors.red,
      'no_show' => Colors.grey,
      _ => Colors.amber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
