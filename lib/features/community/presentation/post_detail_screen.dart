import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/authed_avatar.dart';
import '../../../shared/widgets/html_text.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/state/auth_controller.dart';
import '../data/community_repository.dart';
import 'posts_screen.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  late Future<MemberPost> _future;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref.read(communityRepositoryProvider).post(widget.postId);

  void _reload() => setState(_load);

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that link.')));
      }
    }
  }

  Future<void> _confirmDelete(MemberPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This can\'t be undone — the post and its cover image are removed for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(communityRepositoryProvider).deletePost(post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted.')));
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete the post.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = ref.watch(authControllerProvider).user?.id;

    return Theme(
      data: ModuleThemes.forModule('community'),
      child: FutureBuilder<MemberPost>(
        future: _future,
        builder: (context, snapshot) {
          final post = snapshot.data;
          final isMine = post != null && viewerId != null && post.author?.id == viewerId;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Post'),
              actions: [
                if (post?.shareUrl != null)
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share',
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: '${post!.title}\n\n${post.shareUrl}'),
                    ),
                  ),
                if (isMine)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final saved = await context.push<bool>('/community/posts/compose', extra: post);
                        if (saved == true && mounted) _reload();
                      } else if (value == 'delete') {
                        await _confirmDelete(post);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
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

                  return _body(post!, isMine);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(MemberPost post, bool isMine) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (post.coverImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  post.coverImageUrl!,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Status is only meaningful to the author — a reader only ever
            // sees published posts anyway.
            if (isMine && !post.isPublished) ...[
              PostStatusChip(status: post.status),
              const SizedBox(height: 12),
            ],
            Text(post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (post.author != null) ...[
                  AuthedAvatar(url: post.author!.avatar, radius: 14),
                  const SizedBox(width: 8),
                  Text(
                    post.author!.name,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                  ),
                ],
                const Spacer(),
                if (post.publishedAt != null)
                  Text(
                    DateFormat('d MMM yyyy').format(post.publishedAt!),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
            if (post.isRejected && (post.rejectionReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text(post.rejectionReason!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 18),
            if ((post.body ?? '').isNotEmpty) HtmlText(html: post.body!, onLinkTap: _openUrl),
          ],
        ),
        if (_deleting)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x99FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
