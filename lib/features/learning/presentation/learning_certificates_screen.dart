import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/error_banner.dart';
import '../data/learning_repository.dart';

// Every certificate the member holds — course certificates plus any ID cards
// issued to them (volunteer, Nikah Counselor), the same set the web's
// /my-certificates lists.
class LearningCertificatesScreen extends ConsumerStatefulWidget {
  const LearningCertificatesScreen({super.key});

  @override
  ConsumerState<LearningCertificatesScreen> createState() => _LearningCertificatesScreenState();
}

class _LearningCertificatesScreenState extends ConsumerState<LearningCertificatesScreen> {
  late Future<List<LearningCertificate>> _future;
  int? _downloadingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = ref.read(learningRepositoryProvider).certificates();
  }

  void _reload() => setState(() {
        _error = null;
        _future = ref.read(learningRepositoryProvider).certificates();
      });

  Future<void> _download(LearningCertificate certificate) async {
    setState(() {
      _downloadingId = certificate.id;
      _error = null;
    });

    try {
      final file = await ref.read(learningRepositoryProvider).downloadCertificate(certificate);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: certificate.title),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not download that certificate — please try again.');
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('quran'),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Certificates')),
        body: SafeArea(
          child: FutureBuilder<List<LearningCertificate>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return RetryErrorView(
                  message: snapshot.error is ApiException
                      ? (snapshot.error as ApiException).displayMessage
                      : 'Something went wrong.',
                  onRetry: _reload,
                );
              }

              final certificates = snapshot.data ?? [];

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    if (_error != null) ...[
                      ErrorBanner(message: _error!),
                      const SizedBox(height: 14),
                    ],
                    if (certificates.isEmpty)
                      EmptyStateView(
                        emoji: '🏅',
                        title: 'No certificates yet',
                        subtitle: 'Finish a course — every lesson and its quizzes — and your certificate appears here.',
                      )
                    else
                      for (final certificate in certificates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _CertificateTile(
                            certificate: certificate,
                            downloading: _downloadingId == certificate.id,
                            onDownload: () => _download(certificate),
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

class _CertificateTile extends StatelessWidget {
  final LearningCertificate certificate;
  final bool downloading;
  final VoidCallback onDownload;

  const _CertificateTile({
    required this.certificate,
    required this.downloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isIdCard = certificate.type == 'volunteer_id' || certificate.type == 'nikah_counselor_id';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB8962E), Color(0xFFD4AF37)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isIdCard ? '🪪' : '🏅', style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificate.title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      certificate.certificateNumber,
                      style: const TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 0.4),
                    ),
                    if (certificate.issuedAt != null)
                      Text(
                        'Issued ${DateFormat('d MMM yyyy').format(certificate.issuedAt!)}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8A6D1F),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: downloading ? null : onDownload,
              icon: downloading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined, size: 18),
              label: Text(downloading ? 'Preparing…' : 'Download PDF'),
            ),
          ),
        ],
      ),
    );
  }
}
