import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/counseling_repository.dart';

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
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty || _sendingReply) return;

    setState(() => _sendingReply = true);
    try {
      await ref.read(counselingRepositoryProvider).reply(widget.bookingId, message);
      _replyController.clear();
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send — try again.')));
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session?'),
        content: const Text('Are you sure you want to cancel this counseling session?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes, Cancel')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      final updated = await ref.read(counselingRepositoryProvider).cancel(widget.bookingId);
      setState(() => _booking = updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel — try again.')));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _submitRating() async {
    setState(() => _rating = true);
    try {
      final updated = await ref.read(counselingRepositoryProvider).rate(
            widget.bookingId,
            rating: _ratingInput,
            feedback: _feedbackController.text.trim().isEmpty ? null : _feedbackController.text.trim(),
          );
      setState(() => _booking = updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit rating — try again.')));
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('counseling'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Session Details')),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _booking == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Not found', textAlign: TextAlign.center)));
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
                _row('Category', counselingCategories[booking.category] ?? booking.category ?? '—'),
                _row('When', DateFormat('d MMM yyyy, h:mm a').format(booking.scheduledAt.toLocal())),
                _row('Contact', counselingContactMethods[booking.contactMethod] ?? booking.contactMethod ?? '—'),
                _row('Counselor', booking.counselor?.name ?? 'Not yet assigned'),
                if ((booking.meetingLink ?? '').isNotEmpty) _row('Meeting Link', booking.meetingLink!),
                if (booking.isUrgent) _row('Urgent', 'Yes'),
                if (booking.isAnonymous) _row('Anonymous', 'Yes'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if ((booking.description ?? '').isNotEmpty) ...[
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(booking.description!),
          const SizedBox(height: 16),
        ],
        if (booking.status == 'cancelled' && (booking.cancellationReason ?? '').isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: Text('Cancelled: ${booking.cancellationReason}', style: TextStyle(color: Colors.red.shade700)),
          ),
          const SizedBox(height: 16),
        ],
        if (canCancel) ...[
          OutlinedButton(
            onPressed: _cancelling ? null : _cancel,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: _cancelling
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Cancel Session'),
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
                  const Text('How was your session?', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    decoration: const InputDecoration(hintText: 'Any feedback? (optional)'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _rating ? null : _submitRating,
                    child: _rating
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Rating'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ] else if (booking.memberRating != null) ...[
          Row(
            children: [
              const Text('Your rating: ', style: TextStyle(fontWeight: FontWeight.w600)),
              ...List.generate(5, (i) => Icon(i < booking.memberRating! ? Icons.star : Icons.star_border, size: 18, color: Colors.amber.shade600)),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const Divider(),
        const SizedBox(height: 8),
        const Text('Messages', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (booking.responses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No messages yet.', style: TextStyle(color: Colors.grey.shade600)),
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
                      Text(response.responder?.name ?? 'Someone', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
                decoration: const InputDecoration(hintText: 'Write a message…', isDense: true),
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
    final (label, color) = switch (status) {
      'confirmed' => ('Confirmed', Colors.green),
      'completed' => ('Completed', Colors.blue),
      'cancelled' => ('Cancelled', Colors.red),
      'no_show' => ('No Show', Colors.grey),
      _ => ('Requested', Colors.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
