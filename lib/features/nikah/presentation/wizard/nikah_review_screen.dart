import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/meta_app_events.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/module_themes.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../domain/nikah_labels.dart';
import '../../state/nikah_controller.dart';

class NikahReviewScreen extends ConsumerStatefulWidget {
  const NikahReviewScreen({super.key});

  @override
  ConsumerState<NikahReviewScreen> createState() => _NikahReviewScreenState();
}

class _NikahReviewScreenState extends ConsumerState<NikahReviewScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(nikahControllerProvider.notifier).submit();
      // Fired right after a successful submit, using the gender already on
      // the cached profile from before this call — the real "signed up for
      // the thing we advertise" moment for Meta's campaign optimization.
      await logNikahProfileCompleted(gender: ref.read(nikahControllerProvider).profile?.gender);
      // submit() only flips verification_status server-side and doesn't
      // update the cached profile — refresh so anything reading it after
      // this (including a user backing out before paying) sees the real
      // state instead of what was cached before submission. The refreshed
      // profile also reflects the server's lazy fee-waiver (see
      // Api\V1\NikahProfileController::show()) — a 0-fee/disabled-payment
      // profile already comes back with payment_status: 'confirmed', same
      // as the web wizard, which never shows its payment page in that case
      // either (see NikahPaymentController::show()).
      await ref.read(nikahControllerProvider.notifier).refresh();
      if (!mounted) return;

      final profile = ref.read(nikahControllerProvider).profile;
      if (profile?.paymentStatus == 'confirmed') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.nikahNoFeeRequiredMessage)),
        );
        context.go('/nikah');
      } else {
        context.go('/nikah/payment');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(nikahControllerProvider).profile;
    final l10n = AppLocalizations.of(context)!;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.nikahReviewProfileTitle)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_error != null) ...[
                      ErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    LinearProgressIndicator(
                      value: profile.completenessPercentage / 100,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.nikahCompletenessPercent(profile.completenessPercentage),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _section(l10n.nikahBasicInfoTitle, [
                      _row(l10n.ageLabel, '${profile.age}'),
                      _row(l10n.heightLabel, profile.height),
                      _row(
                        l10n.maritalStatusLabel,
                        maritalStatusLabel(l10n, profile.maritalStatus),
                      ),
                      _row(
                        l10n.cityLabel,
                        '${profile.city}${profile.state != null ? ', ${profile.state}' : ''}',
                      ),
                      _row(l10n.addressLabel, profile.address),
                    ]),
                    _section(l10n.nikahGuardianSectionTitle, [
                      _row(l10n.nameLabel, profile.guardianName),
                      _row(l10n.contactLabel, profile.guardianContact),
                      _row(l10n.relationLabel, profile.guardianRelation != null ? guardianRelationLabel(l10n, profile.guardianRelation!) : null),
                    ]),
                    _section(l10n.nikahDeenLifestyleTitle, [
                      _row(l10n.sectLabel, profile.sect != null ? sectLabel(l10n, profile.sect!) : null),
                      _row(l10n.nikahPrayerLabel, profile.prayerFrequency != null ? (prayerOptions(l10n)[profile.prayerFrequency!] ?? profile.prayerFrequency) : null),
                      _row(l10n.educationLabel, profile.education != null ? educationLabel(l10n, profile.education!) : null),
                      _row(l10n.professionLabel, profile.profession),
                    ]),
                    _section(l10n.aboutLabel, [
                      _row(l10n.aboutLabel, profile.about),
                      _row(l10n.lookingForLabel, profile.expectations),
                      _row(
                        l10n.nikahPreferredAgeLabel,
                        (profile.prefMinAge != null ||
                                profile.prefMaxAge != null)
                            ? '${profile.prefMinAge ?? '—'} – ${profile.prefMaxAge ?? '—'}'
                            : null,
                      ),
                      _row(l10n.nikahPreferredCityLabel, profile.prefCity),
                      _row(l10n.nikahPreferredSectLabel, profile.prefSect),
                      _row(l10n.nikahPreferredEducationLabel, profile.prefEducation),
                      _row(
                        l10n.nikahPreferredMaritalStatusLabel,
                        profile.prefMaritalStatus != null ? maritalStatusLabel(l10n, profile.prefMaritalStatus!) : null,
                      ),
                      _row(l10n.nikahPreferredIncomeShortLabel, profile.prefIncome),
                      _row(l10n.nikahOtherPreferencesLabel, profile.prefOther),
                    ]),
                    _section(l10n.nikahVerificationSectionTitle, [
                      _row(
                        l10n.cnicNumberLabel,
                        profile.hasCnicNumber
                            ? l10n.nikahCnicSavedLabel
                            : l10n.nikahNotProvidedLabel,
                      ),
                      _row(
                        l10n.photoLabel,
                        profile.hasPhoto ? l10n.nikahUploadedLabel : l10n.nikahNotAddedLabel,
                      ),
                      _row(l10n.visibilityLabel, visibilityLabel(l10n, profile.visibility)),
                    ]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  children: [
                    if (!profile.isComplete)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          l10n.nikahFinishVerificationFirst,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ElevatedButton(
                      onPressed: (_busy || !profile.isComplete)
                          ? null
                          : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.nikahSubmitForVerification),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 10),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
