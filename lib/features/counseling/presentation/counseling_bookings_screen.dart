import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/counseling_repository.dart';
import 'counseling_booking_detail_screen.dart';
import 'counseling_screen.dart' show counselingCategoryLabel, counselingStatusLabel;

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
      // Called from initState() — looked up after the await above rather
      // than hoisted, since Localizations isn't registered yet that early.
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (String, Color) _statusDisplay(AppLocalizations l10n, String status) => (
        counselingStatusLabel(l10n, status),
        switch (status) {
          'confirmed' => Colors.green,
          'completed' => Colors.blue,
          'cancelled' => Colors.red,
          'no_show' => Colors.grey,
          _ => Colors.amber,
        },
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: ModuleThemes.forModule('counseling'),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.mySessionsLabel)),
        body: SafeArea(child: RefreshIndicator(onRefresh: _load, child: _buildBody(context))),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            child: Center(child: Text(l10n.noSessionsBookedMessage, style: TextStyle(color: Colors.grey.shade600))),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final booking = _bookings[index];
        final (statusLabel, statusColor) = _statusDisplay(l10n, booking.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CounselingBookingDetailScreen(bookingId: booking.id)));
              _load();
            },
            title: Text(booking.subject ?? (booking.category != null ? counselingCategoryLabel(l10n, booking.category) : l10n.sessionFallbackLabel), style: const TextStyle(fontWeight: FontWeight.w700)),
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
