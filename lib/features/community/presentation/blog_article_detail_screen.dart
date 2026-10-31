import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/authed_avatar.dart';
import '../../../shared/widgets/html_text.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/community_repository.dart';

// Read-only — official articles are staff-authored (web admin panel), so
// unlike PostDetailScreen there's no edit/delete here, just reading.
class BlogArticleDetailScreen extends ConsumerStatefulWidget {
  final int articleId;
  const BlogArticleDetailScreen({super.key, required this.articleId});

  @override
  ConsumerState<BlogArticleDetailScreen> createState() => _BlogArticleDetailScreenState();
}

class _BlogArticleDetailScreenState extends ConsumerState<BlogArticleDetailScreen> {
  late Future<BlogArticle> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(communityRepositoryProvider).blogArticle(widget.articleId);

  void _reload() => setState(_load);

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that link.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: FutureBuilder<BlogArticle>(
        future: _future,
        builder: (context, snapshot) {
          final article = snapshot.data;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Sallaamti Blog'),
              actions: [
                if (article?.shareUrl != null)
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share',
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: '${article!.title}\n\n${article.shareUrl}'),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: Builder(
                builder: (context) {
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

                  return _body(article!);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BlogArticle article) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        if (article.coverImageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              article.coverImageUrl!,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if ((article.category ?? '').isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(999)),
            child: Text(
              article.category!,
              style: TextStyle(color: Colors.teal.shade800, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          article.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (article.author != null) ...[
              AuthedAvatar(url: article.author!.avatar, radius: 14),
              const SizedBox(width: 8),
              Text(
                article.author!.name,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w700),
              ),
            ],
            const Spacer(),
            if (article.publishedAt != null)
              Text(
                DateFormat('d MMM yyyy').format(article.publishedAt!),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if ((article.content ?? '').isNotEmpty) HtmlText(html: article.content!, onLinkTap: _openUrl),
      ],
    );
  }
}
