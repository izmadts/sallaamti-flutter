import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/message_tick.dart';
import '../data/nikah_repository.dart';
import '../state/nikah_controller.dart';

// Only reachable once an interest is mutually accepted (see
// nikah_profile_detail_screen.dart's "Open Messages" button) — same
// guardian-mediated conversation the web app's nikah/messages view shows,
// backed by Api\V1\NikahGuardianMessageController. Polled, not pushed — same
// hosting-constraint reasoning as support_chat_screen.dart.
class NikahMessagesScreen extends ConsumerStatefulWidget {
  final int interestId;
  const NikahMessagesScreen({super.key, required this.interestId});

  @override
  ConsumerState<NikahMessagesScreen> createState() => _NikahMessagesScreenState();
}

class _NikahMessagesScreenState extends ConsumerState<NikahMessagesScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<NikahMessage> _messages = [];
  int? _otherProfileId;
  String? _otherProfileName;
  bool _loading = true;
  bool _sending = false;
  bool _blocking = false;
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
      final repo = ref.read(nikahRepositoryProvider);
      final thread = await repo.listMessages(widget.interestId);
      if (!mounted) return;
      final grew = thread.messages.length > _messages.length;
      setState(() {
        _messages = thread.messages;
        _otherProfileId = thread.otherProfileId;
        _otherProfileName = thread.otherProfileName;
        _error = null;
      });
      if (grew) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException catch (e) {
      if (showLoading && mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      // A silent background poll failing is fine — it'll just retry in 7s.
      if (showLoading && mounted) setState(() => _error = AppLocalizations.of(context)!.errorGeneric);
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
      final repo = ref.read(nikahRepositoryProvider);
      final message = await repo.sendMessage(widget.interestId, text);
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

  Future<void> _block() async {
    final profileId = _otherProfileId;
    if (profileId == null || _blocking) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this profile?'),
        content: const Text('You will no longer see each other in Browse or be able to message.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Block')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _blocking = true);
    try {
      await ref.read(nikahRepositoryProvider).blockProfile(profileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile blocked.')));
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric)));
    } finally {
      if (mounted) setState(() => _blocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = ModuleThemes.seedFor('nikah');

    return Theme(
      data: ModuleThemes.forModule('nikah'),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_otherProfileName ?? 'Messages'),
          actions: [
            if (_otherProfileId != null)
              IconButton(
                icon: const Icon(Icons.block),
                tooltip: 'Block',
                onPressed: _blocking ? null : _block,
              ),
          ],
        ),
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
            'No messages yet — say assalamu alaikum 👋',
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
                Text(m.message, style: TextStyle(color: m.isMine ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(m.createdAt.toLocal()),
                      style: TextStyle(fontSize: 10, color: m.isMine ? Colors.white70 : Colors.grey.shade500),
                    ),
                    if (m.isMine) ...[
                      const SizedBox(width: 4),
                      MessageTick(isRead: m.isRead, color: Colors.white70),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
