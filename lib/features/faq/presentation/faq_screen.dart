import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/state/auth_controller.dart';
import '../data/faq_repository.dart';

class FaqScreen extends ConsumerStatefulWidget {
  final String module;
  const FaqScreen({super.key, required this.module});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  Future<List<FaqItem>>? _future;
  String? _loadedLocale;
  int? _expandedId;

  // Localizations.localeOf(context) depends on an InheritedWidget, which
  // isn't available yet in initState() — didChangeDependencies() is the
  // correct place, and re-fires (harmlessly re-fetching in the new
  // language) if the user flips the language switch while this screen is
  // still open.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (locale != _loadedLocale) {
      _loadedLocale = locale;
      _load();
    }
  }

  void _load() {
    final repo = FaqRepository(ref.read(apiClientProvider));
    _future = repo.forModule(widget.module, locale: _loadedLocale!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.faqTitle)),
      body: FutureBuilder<List<FaqItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : l10n.errorGeneric;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(_load),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }

          final faqs = snapshot.data ?? [];

          // An empty FAQ list means nothing has been written for this module
          // yet — not that the feature is unbuilt, which is what the old
          // "coming soon" text told the member.
          if (faqs.isEmpty) {
            return EmptyStateView(
              emoji: '💡',
              title: l10n.faqEmptyTitle,
              subtitle: l10n.faqEmptySubtitle,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: faqs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final faq = faqs[index];
              final expanded = _expandedId == faq.id;

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _expandedId = expanded ? null : faq.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                faq.question,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                            Icon(expanded ? Icons.remove_circle_outline : Icons.add_circle_outline),
                          ],
                        ),
                        if (expanded) ...[
                          const SizedBox(height: 10),
                          Text(faq.answer, style: const TextStyle(height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
