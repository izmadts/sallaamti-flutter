import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../data/counseling_repository.dart';
import 'counseling_booking_detail_screen.dart';

class CounselingBookingsScreen extends ConsumerStatefulWidget {
  const CounselingBookingsScreen({super.key});

  @override
  ConsumerState<CounselingBookingsScreen> createState() => _CounselingBookingsScreenState();
}

class _CounselingBookingsScreenState extends ConsumerState<CounselingBookingsScreen> {
  List<CounselingBookingInfo> _bookings = [];
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
      final bookings = await ref.read(counselingRepositoryProvider).myBookings();
      setState(() => _bookings = bookings);
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
        'completed' => ('Completed', Colors.blue),
        'cancelled' => ('Cancelled', Colors.red),
        'no_show' => ('No Show', Colors.grey),
        _ => ('Requested', Colors.amber),
      };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('counseling'),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Sessions')),
        body: SafeArea(child: RefreshIndicator(onRefresh: _load, child: _buildBody(context))),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _bookings.isEmpty) {
      return ListView(
        children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(_error!, textAlign: TextAlign.center)))],
      );
    }

    if (_bookings.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(48),
            child: Center(child: Text('No sessions booked yet.', style: TextStyle(color: Colors.grey.shade600))),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final booking = _bookings[index];
        final (statusLabel, statusColor) = _statusDisplay(booking.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CounselingBookingDetailScreen(bookingId: booking.id)));
              _load();
            },
            title: Text(booking.subject ?? counselingCategories[booking.category] ?? 'Session', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(DateFormat('d MMM yyyy, h:mm a').format(booking.scheduledAt.toLocal())),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ),
        );
      },
    );
  }
}
