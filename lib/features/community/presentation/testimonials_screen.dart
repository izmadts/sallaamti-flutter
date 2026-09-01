import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../shared/widgets/html_text.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/community_repository.dart';
import 'posts_screen.dart' show PostStatusChip;

class TestimonialsScreen extends ConsumerStatefulWidget {
  const TestimonialsScreen({super.key});

  @override
  ConsumerState<TestimonialsScreen> createState() => _TestimonialsScreenState();
}

class _TestimonialsScreenState extends ConsumerState<TestimonialsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<Paged<MemberTestimonial>> _allFuture;
  late Future<Paged<MemberTestimonial>> _mineFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _load() {
    final repository = ref.read(communityRepositoryProvider);
    _allFuture = repository.testimonials();
    _mineFuture = repository.myTestimonials();
  }

  void _reload() => setState(_load);

  Future<void> _compose({MemberTestimonial? existing}) async {
    final saved = await context.push<bool>('/community/testimonials/compose', extra: existing);
    if (saved == true && mounted) {
      _reload();
      _tabs.animateTo(1);
    }
  }

  Future<void> _confirmDelete(MemberTestimonial testimonial) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this testimonial?'),
        content: const Text('This can\'t be undone.'),
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

    try {
      await ref.read(communityRepositoryProvider).deleteTestimonial(testimonial.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Testimonial deleted.')));
      _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete it. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModuleThemes.forModule('community'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Testimonials'),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Community'), Tab(text: 'Mine')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _compose(),
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Share Yours'),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [
              _TestimonialList(
                future: _allFuture,
                onRetry: _reload,
                emptyTitle: 'No testimonials yet',
                emptySubtitle: 'Be the first to share how Sallaamti has helped you.',
                showStatus: false,
              ),
              _TestimonialList(
                future: _mineFuture,
                onRetry: _reload,
                emptyTitle: 'You haven\'t shared one yet',
                emptySubtitle: 'Tell us about your experience — it appears publicly once our team reviews it.',
                showStatus: true,
                onEdit: (t) => _compose(existing: t),
                onDelete: _confirmDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestimonialList extends StatelessWidget {
  final Future<Paged<MemberTestimonial>> future;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showStatus;
  final void Function(MemberTestimonial)? onEdit;
  final void Function(MemberTestimonial)? onDelete;

  const _TestimonialList({
    required this.future,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.showStatus,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Paged<MemberTestimonial>>(
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

        final testimonials = snapshot.data!.items;

        return RefreshIndicator(
          onRefresh: () async => onRetry(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            children: [
              if (testimonials.isEmpty)
                EmptyStateView(emoji: '💬', title: emptyTitle, subtitle: emptySubtitle)
              else
                for (final testimonial in testimonials)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _TestimonialCard(
                      testimonial: testimonial,
                      showStatus: showStatus,
                      onEdit: onEdit == null ? null : () => onEdit!(testimonial),
                      onDelete: onDelete == null ? null : () => onDelete!(testimonial),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

// CircleAvatar's backgroundImage has no error builder — a photo that 404s
// just leaves an empty coloured circle. Falling back to the initial keeps
// the card readable either way.
class _TestimonialAvatar extends StatefulWidget {
  final String name;
  final String? photoUrl;

  const _TestimonialAvatar({required this.name, this.photoUrl});

  @override
  State<_TestimonialAvatar> createState() => _TestimonialAvatarState();
}

class _TestimonialAvatarState extends State<_TestimonialAvatar> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final showPhoto = widget.photoUrl != null && !_failed;

    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.1),
      backgroundImage: showPhoto ? NetworkImage(widget.photoUrl!) : null,
      onBackgroundImageError: showPhoto
          ? (_, _) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: showPhoto
          ? null
          : Text(
              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final MemberTestimonial testimonial;
  final bool showStatus;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TestimonialCard({
    required this.testimonial,
    required this.showStatus,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TestimonialAvatar(name: testimonial.name, photoUrl: testimonial.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(testimonial.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    if ((testimonial.location ?? '').isNotEmpty)
                      Text(
                        testimonial.location!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < testimonial.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: const Color(0xFFB8962E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HtmlText(
            html: testimonial.content,
            baseStyle: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey.shade800),
          ),
          if (showStatus) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                PostStatusChip(status: testimonial.status),
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
            if (testimonial.isRejected && (testimonial.rejectionReason ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  testimonial.rejectionReason!,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
