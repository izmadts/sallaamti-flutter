import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/state/auth_controller.dart';
import '../data/faq_repository.dart';

class FaqScreen extends ConsumerStatefulWidget {
  final String module;
  const FaqScreen({super.key, required this.module});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  late Future<List<FaqItem>> _future;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = FaqRepository(ref.read(apiClientProvider));
    final locale = Localizations.localeOf(context).languageCode;
    _future = repo.forModule(widget.module, locale: locale);
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
                      child: Text(l10n.continueLabel),
                    ),
                  ],
                ),
              ),
            );
          }

          final faqs = snapshot.data ?? [];

          if (faqs.isEmpty) {
            return Center(child: Text(l10n.comingSoon));
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
