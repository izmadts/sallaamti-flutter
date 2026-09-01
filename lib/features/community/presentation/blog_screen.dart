import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/html_text.dart';
import '../data/community_repository.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  late Future<Paged<BlogArticle>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(communityRepositoryProvider).blog();
  }

  void _reload() => setState(() => _future = ref.read(communityRepositoryProvider).blog());

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Blog')),
        body: SafeArea(
          child: FutureBuilder<Paged<BlogArticle>>(
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

              final articles = snapshot.data!.items;

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    if (articles.isEmpty)
                      EmptyStateView(
                        emoji: '📰',
                        title: 'Nothing published yet',
                        subtitle: 'New articles appear here as our team writes them.',
                      )
                    else
                      for (final article in articles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ArticleCard(
                            article: article,
                            onTap: () => context.push('/community/blog/${article.id}'),
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

class _ArticleCard extends StatelessWidget {
  final BlogArticle article;
  final VoidCallback onTap;

  const _ArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.coverImageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  article.coverImageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        article.category!,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (article.category != null) const SizedBox(height: 10),
                  Text(
                    article.title,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((article.excerpt ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      article.excerpt!,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    [
                      if (article.author != null) article.author!.name,
                      if (article.publishedAt != null) DateFormat('d MMM yyyy').format(article.publishedAt!),
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlogDetailScreen extends ConsumerStatefulWidget {
  final int articleId;
  const BlogDetailScreen({super.key, required this.articleId});

  @override
  ConsumerState<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends ConsumerState<BlogDetailScreen> {
  late Future<BlogArticle> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(communityRepositoryProvider).blogArticle(widget.articleId);
  }

  void _reload() => setState(() => _future = ref.read(communityRepositoryProvider).blogArticle(widget.articleId));

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Article')),
        body: SafeArea(
          child: FutureBuilder<BlogArticle>(
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

              final article = snapshot.data!;

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
                  Text(article.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (article.author != null) article.author!.name,
                      if (article.publishedAt != null) DateFormat('d MMMM yyyy').format(article.publishedAt!),
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  if ((article.content ?? '').isNotEmpty) HtmlText(html: article.content!),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
