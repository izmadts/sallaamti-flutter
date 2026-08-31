import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/module_themes.dart';
import '../data/wall_repository.dart';

class WallCommentsScreen extends ConsumerStatefulWidget {
  final WallItem item;
  const WallCommentsScreen({super.key, required this.item});

  @override
  ConsumerState<WallCommentsScreen> createState() => _WallCommentsScreenState();
}

class _WallCommentsScreenState extends ConsumerState<WallCommentsScreen> {
  final _textController = TextEditingController();
  List<WallComment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  WallComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comments = await ref.read(wallRepositoryProvider).comments(widget.item.type, widget.item.id);
      setState(() => _comments = comments);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load comments. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(wallRepositoryProvider).postComment(
            widget.item.type,
            widget.item.id,
            body: text,
            parentId: _replyingTo?.id,
          );
      _textController.clear();
      setState(() => _replyingTo = null);
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not post — try again.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('wall'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildBody(context)),
              if (_replyingTo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Expanded(child: Text('Replying to ${_replyingTo!.author?.name ?? 'a member'}', style: const TextStyle(fontSize: 12))),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _replyingTo = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(hintText: 'Write a comment…', isDense: true),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: _sending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        onPressed: _sending ? null : _send,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)));
    }

    if (_comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No comments yet — be the first to reply.', style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommentTile(comment: comment, onReply: () => setState(() => _replyingTo = comment)),
              for (final reply in comment.replies)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 10),
                  child: _CommentTile(comment: reply, onReply: null),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final WallComment comment;
  final VoidCallback? onReply;
  const _CommentTile({required this.comment, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.teal.withValues(alpha: 0.1),
          backgroundImage: (comment.author?.avatar ?? '').isNotEmpty ? NetworkImage(comment.author!.avatar!) : null,
          child: (comment.author?.avatar ?? '').isEmpty ? Text(comment.author?.name.characters.first ?? '?', style: const TextStyle(fontSize: 11)) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(comment.author?.name ?? 'A community member', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 2),
              Text(comment.body, style: const TextStyle(fontSize: 13)),
              if (onReply != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: onReply,
                  child: Text('Reply', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
