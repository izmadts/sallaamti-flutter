import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Fixed, not settings-driven — this is the one official channel link, same
// treatment as a hardcoded support email would get elsewhere in the app.
const _officialWhatsappChannelUrl = 'https://whatsapp.com/channel/0029Vakde1SFcowDP3r6C20f';

Future<void> _openWhatsappChannel(BuildContext context) async {
  final uri = Uri.parse(_officialWhatsappChannelUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }
}

// AppBar action promoting the official WhatsApp channel — same icon/color
// convention as AppBottomNav's WhatsApp support tile. Shown across every
// Nikah module screen's topbar per product request, not just the entry
// points, so it's a reusable action rather than copy-pasted per screen.
class WhatsappChannelAction extends StatelessWidget {
  const WhatsappChannelAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
      tooltip: 'Join our WhatsApp Channel',
      onPressed: () => _openWhatsappChannel(context),
    );
  }
}
