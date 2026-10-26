import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/api/api_exception.dart';
import '../data/support_repository.dart';

// Polled, not pushed — no persistent websocket process available on this
// host (same hosting constraint as the Wall video-length cap). A short
// poll interval while this screen is open keeps it feeling close to live
// without needing any extra server infrastructure.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<SupportMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load(showLoading: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 7), (_) => _load(showLoading: false));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool showLoading}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      final messages = await repo.messages();
      if (!mounted) return;
      final grew = messages.length > _messages.length;
      setState(() {
        _messages = messages;
        _error = null;
      });
      if (grew) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException catch (e) {
      if (showLoading && mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      // A silent background poll failing is fine — it'll just retry in 7s.
      if (showLoading && mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (showLoading && mounted) setState(() => _loading = false);
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
      final message = await ref.read(supportRepositoryProvider).send(text);
      setState(() => _messages = [..._messages, message]);
      _textController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send. Please try again.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Message Sallaamti Support')),
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
            'Assalamu Alaikum! Ask us anything — our team usually replies within a day.',
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
                if (!m.isMine) ...[
                  const Text('Sallaamti Support', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                  const SizedBox(height: 2),
                ],
                Text(m.body, style: TextStyle(color: m.isMine ? Colors.white : Colors.black87)),
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
