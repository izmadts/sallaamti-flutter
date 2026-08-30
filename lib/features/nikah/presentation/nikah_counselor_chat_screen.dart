import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/nikah_hire_repository.dart';
import '../data/nikah_repository.dart';

// Same shape as nikah_messages_screen.dart (guardian messaging), pointed at
// the counselor<->client channel instead — a different relationship
// (your own counselor, not a mutual match), so it's a separate screen
// rather than a parameterized variant of that one.
class NikahCounselorChatScreen extends ConsumerStatefulWidget {
  final int leadId;
  const NikahCounselorChatScreen({super.key, required this.leadId});

  @override
  ConsumerState<NikahCounselorChatScreen> createState() => _NikahCounselorChatScreenState();
}

class _NikahCounselorChatScreenState extends ConsumerState<NikahCounselorChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<NikahMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(nikahHireRepositoryProvider);
      final messages = await repo.listLeadMessages(widget.leadId);
      setState(() => _messages = messages);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final repo = ref.read(nikahHireRepositoryProvider);
      final message = await repo.sendLeadMessage(widget.leadId, text);
      setState(() => _messages = [..._messages, message]);
      _textController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = ModuleThemes.seedFor('nikah');

    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Your Counselor')),
        body: Column(
          children: [
            Expanded(child: _buildBody(context, primary)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(hintText: 'Type a message…', isDense: true),
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
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
    );
  }

  Widget _buildBody(BuildContext context, Color primary) {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _messages.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)));
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Say assalamu alaikum to your counselor 👋',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];
        return Align(
          alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: m.isMine ? primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!m.isMine && (m.senderName ?? '').isNotEmpty) ...[
                  Text(m.senderName!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(height: 2),
                ],
                Text(m.message, style: TextStyle(color: m.isMine ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(m.createdAt.toLocal()),
                  style: TextStyle(fontSize: 10, color: m.isMine ? Colors.white70 : Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
