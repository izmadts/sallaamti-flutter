import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/donation_repository.dart';

class DonationHistoryScreen extends ConsumerStatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  ConsumerState<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends ConsumerState<DonationHistoryScreen> {
  List<DonationInfo> _donations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final donations = await ref.read(donationRepositoryProvider).index();
      setState(() => _donations = donations);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (String, Color) _statusDisplay(String status) => switch (status) {
        'confirmed' => ('Confirmed', Colors.green),
        'rejected' => ('Rejected', Colors.red),
        _ => ('Under Review', Colors.amber),
      };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('donation'),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Donations')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _donations.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(_error!, textAlign: TextAlign.center)),
          ),
        ],
      );
    }

    if (_donations.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('No donations yet.', style: TextStyle(color: Colors.grey.shade600)),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _donations.length,
      itemBuilder: (context, index) {
        final donation = _donations[index];
        final (statusLabel, statusColor) = _statusDisplay(donation.paymentStatus);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PKR ${donation.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(donation.donationNumber, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                if ((donation.purpose ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(donation.purpose!.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
                if ((donation.message ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(donation.message!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ],
                if (donation.paymentStatus == 'rejected' && (donation.paymentRejectionReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reason: ${donation.paymentRejectionReason}', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                Text(
                  DateFormat('d MMM yyyy, h:mm a').format(donation.createdAt.toLocal()),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
