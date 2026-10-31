import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/authed_avatar.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/community_repository.dart';

// Three views: Sallaamti's own staff-authored articles (read-only, the real
// thing the website publishes at /blog), everything members have published,
// and the member's own submissions across every status. "Sallaamti Blog" was
// previously missing entirely — this screen used to only ever show member
// posts, which could easily be empty, making the whole "Blog" section look
// broken even when the real website blog had plenty of articles. "Mine" is
// the only place a pending or rejected post is visible, so it needs its own
// tab rather than being folded into the public list.
class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<Paged<BlogArticle>> _blogFuture;
  late Future<Paged<MemberPost>> _allFuture;
  late Future<Paged<MemberPost>> _mineFuture;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _load() {
    final repository = ref.read(communityRepositoryProvider);
    final search = _searchController.text.trim();
    _blogFuture = repository.blogArticles(search: search);
    _allFuture = repository.posts(search: search);
    _mineFuture = repository.myPosts();
  }

  void _reload() => setState(_load);

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  Future<void> _compose({MemberPost? post}) async {
    final saved = await context.push<bool>('/community/posts/compose', extra: post);
    if (saved == true && mounted) {
      _reload();
      _tabs.animateTo(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sallaamti Blog'),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Sallaamti Blog'), Tab(text: 'Community'), Tab(text: 'My Posts')],
          ),
        ),
        // Writing only applies to the member-authored tabs (Community/Mine)
        // — the official blog tab is read-only, staff-authored on the web.
        floatingActionButton: AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) => _tabs.index == 0
              ? const SizedBox.shrink()
              : FloatingActionButton.extended(
                  onPressed: () => _compose(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Write a Post'),
                ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search articles by keyword…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _BlogList(
                      future: _blogFuture,
                      onRetry: _reload,
                    ),
                    _PostList(
                      future: _allFuture,
                      onRetry: _reload,
                      emptyEmoji: '✍️',
                      emptyTitle: 'No posts found',
                      emptySubtitle: 'Try a different keyword, or be the first to share something with the community.',
                      showStatus: false,
                      onTap: (post) => context.push('/community/posts/${post.id}'),
                    ),
                    _PostList(
                      future: _mineFuture,
                      onRetry: _reload,
                      emptyEmoji: '📝',
                      emptyTitle: 'You haven\'t written anything yet',
                      emptySubtitle: 'Write a post and it\'ll appear publicly once our team reviews it.',
                      showStatus: true,
                      onTap: (post) => context.push('/community/posts/${post.id}'),
                      onEdit: (post) => _compose(post: post),
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
}

class _BlogList extends StatelessWidget {
  final Future<Paged<BlogArticle>> future;
  final VoidCallback onRetry;

  const _BlogList({required this.future, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Paged<BlogArticle>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return RetryErrorView(
            message: snapshot.error is ApiException
                ? (snapshot.error as ApiException).displayMessage
                : 'Something went wrong.',
            onRetry: onRetry,
          );
        }

        final articles = snapshot.data!.items;

        return RefreshIndicator(
          onRefresh: () async => onRetry(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            children: [
              if (articles.isEmpty)
                const EmptyStateView(
                  emoji: '📰',
                  title: 'No articles found',
                  subtitle: 'Try a different keyword, or check back soon for new articles.',
                )
              else
                for (final article in articles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _BlogArticleCard(
                      article: article,
                      onTap: () => context.push('/community/blog/${article.id}'),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _BlogArticleCard extends StatelessWidget {
  final BlogArticle article;
  final VoidCallback onTap;
  const _BlogArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                  if ((article.category ?? '').isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        article.category!,
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (article.author != null) ...[
                        AuthedAvatar(url: article.author!.avatar, radius: 11),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            article.author!.name,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (article.publishedAt != null)
                        Text(
                          DateFormat('d MMM').format(article.publishedAt!),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                    ],
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

class _PostList extends StatelessWidget {
  final Future<Paged<MemberPost>> future;
  final VoidCallback onRetry;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showStatus;
  final void Function(MemberPost) onTap;
  final void Function(MemberPost)? onEdit;

  const _PostList({
    required this.future,
    required this.onRetry,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.showStatus,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Paged<MemberPost>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return RetryErrorView(
            message: snapshot.error is ApiException
                ? (snapshot.error as ApiException).displayMessage
                : 'Something went wrong.',
            onRetry: onRetry,
          );
        }

        final posts = snapshot.data!.items;

        return RefreshIndicator(
          onRefresh: () async => onRetry(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            children: [
              if (posts.isEmpty)
                EmptyStateView(emoji: emptyEmoji, title: emptyTitle, subtitle: emptySubtitle)
              else
                for (final post in posts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: PostCard(
                      post: post,
                      showStatus: showStatus,
                      onTap: () => onTap(post),
                      onEdit: onEdit == null ? null : () => onEdit!(post),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class PostStatusChip extends StatelessWidget {
  final String status;
  const PostStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'published' => ('Live', Colors.green),
      'rejected' => ('Not approved', Colors.red),
      _ => ('Awaiting review', Colors.amber),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color.shade800, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class PostLanguageBadge extends StatelessWidget {
  final String language;
  const PostLanguageBadge({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    final isUrdu = language == 'ur';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isUrdu ? 'اردو' : 'English',
        style: TextStyle(color: Colors.teal.shade800, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final MemberPost post;
  final bool showStatus;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const PostCard({
    super.key,
    required this.post,
    required this.showStatus,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
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
            if (post.coverImageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  post.coverImageUrl!,
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
                  if (showStatus) ...[
                    Row(
                      children: [
                        PostStatusChip(status: post.status),
                        const Spacer(),
                        if (onEdit != null)
                          InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  PostLanguageBadge(language: post.language),
                  const SizedBox(height: 6),
                  Text(
                    post.title,
                    textDirection: post.language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((post.excerpt ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.excerpt!,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (post.isRejected && (post.rejectionReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        post.rejectionReason!,
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (post.author != null) ...[
                        AuthedAvatar(url: post.author!.avatar, radius: 11),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            post.author!.name,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        [
                          if (post.publishedAt != null)
                            DateFormat('d MMM').format(post.publishedAt!)
                          else if (post.createdAt != null)
                            DateFormat('d MMM').format(post.createdAt!),
                          if (post.isPublished) '👁 ${post.viewsCount}',
                        ].join('  ·  '),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                    ],
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
