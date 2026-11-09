import 'package:flutter/material.dart';

// Shared by every one-on-one chat screen (guardian messages, counselor
// chat, support chat) — a single grey tick for "sent", a double tick (teal
// when read, otherwise the same grey as sent) for "delivered"/"read". There
// is no separate websocket-backed "delivered" signal on this stack (every
// chat here is REST + poll, not a persistent connection — see
// support_chat_screen.dart's own comment on why), so "delivered" and "sent"
// collapse into the same single-tick state; the only state actually tracked
// end-to-end is whether the other party has opened the conversation since.
class MessageTick extends StatelessWidget {
  final bool isRead;
  final Color color;
  const MessageTick({super.key, required this.isRead, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(isRead ? Icons.done_all : Icons.done, size: 13, color: isRead ? Colors.lightBlueAccent : color);
  }
}
