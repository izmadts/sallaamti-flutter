import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wall_repository.dart';
import 'wall_comments_screen.dart';

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]}';
}

// Shared feed-card widget — used by both the main wall feed and the
// Saved screen, since a saved item needs the exact same reactions/
// comments/save affordances as it did on the feed.
class WallItemCard extends ConsumerStatefulWidget {
  final WallItem item;
  final ValueChanged<WallItem>? onChanged;
  const WallItemCard({super.key, required this.item, this.onChanged});

  @override
  ConsumerState<WallItemCard> createState() => _WallItemCardState();
}

class _WallItemCardState extends ConsumerState<WallItemCard> {
  late WallItem _item = widget.item;
  bool _reacting = false;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant WallItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id || oldWidget.item.type != widget.item.type) {
      _item = widget.item;
    }
  }

  Future<void> _react(String type) async {
    if (_reacting) return;
    setState(() => _reacting = true);
    try {
      final updated = await ref.read(wallRepositoryProvider).react(_item.type, _item.id, type);
      setState(() => _item = updated);
      widget.onChanged?.call(updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not react — try again.')));
    } finally {
      if (mounted) setState(() => _reacting = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final isSaved = await ref.read(wallRepositoryProvider).toggleSave(_item.type, _item.id);
      final updated = _item.copyWith(isSaved: isSaved);
      setState(() => _item = updated);
      widget.onChanged?.call(updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save — try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openComments() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WallCommentsScreen(item: _item)));
  }

  @override
  Widget build(BuildContext context) {
    final isDua = _item.type == 'dua';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDua ? const Color(0xFFF4F0FB) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isDua ? Border.all(color: const Color(0xFFDCD0F0)) : null,
        boxShadow: isDua
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_item.isPinned)
            Container(
              width: double.infinity,
              color: const Color(0xFFB8962E),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: const Text('📌 Pinned', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          if (!isDua && _item.photoUrl != null)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                _item.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(color: Colors.grey.shade100),
              ),
            ),
          if (!isDua && _item.videoUrl != null && _item.photoUrl == null)
            Container(
              height: 160,
              width: double.infinity,
              color: Colors.black87,
              child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDua ? const Color(0xFF6D4AAE).withValues(alpha: 0.15) : Colors.teal.withValues(alpha: 0.1),
                      backgroundImage: (_item.author?.avatar ?? '').isNotEmpty ? NetworkImage(_item.author!.avatar!) : null,
                      child: (_item.author?.avatar ?? '').isEmpty
                          ? Text(isDua ? '🤲' : (_item.author?.name.characters.first ?? '?'), style: const TextStyle(fontSize: 13))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _item.author?.name ?? 'A community member',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            _timeAgo(_item.createdAt.toLocal()),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    if (isDua) const Text('🤲', style: TextStyle(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isDua && (_item.title ?? '').isNotEmpty) ...[
                  Text(_item.title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                ],
                Text(
                  _item.body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontStyle: isDua ? FontStyle.italic : FontStyle.normal,
                    color: Colors.black87,
                  ),
                ),
                if (_item.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _item.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(t, style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final entry in wallReactionTypes.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _ReactionChip(
                          emoji: entry.value.$1,
                          count: _item.reactionCounts[entry.key] ?? 0,
                          active: _item.myReaction == entry.key,
                          onTap: _reacting ? null : () => _react(entry.key),
                        ),
                      ),
                    const Spacer(),
                    InkWell(
                      onTap: _openComments,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          children: [
                            Icon(Icons.mode_comment_outlined, size: 18, color: Colors.grey.shade600),
                            if (_item.commentsCount > 0) ...[
                              const SizedBox(width: 4),
                              Text('${_item.commentsCount}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _saving ? null : _toggleSave,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          _item.isSaved ? Icons.bookmark : Icons.bookmark_border,
                          size: 18,
                          color: _item.isSaved ? const Color(0xFFB8962E) : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool active;
  final VoidCallback? onTap;
  const _ReactionChip({required this.emoji, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0D6B6B).withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: active ? Border.all(color: const Color(0xFF0D6B6B)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? const Color(0xFF0D6B6B) : Colors.grey.shade700)),
            ],
          ],
        ),
      ),
    );
  }
}
