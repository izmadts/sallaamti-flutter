import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Fixed, not settings-driven — this is the one official channel link, same
// treatment as a hardcoded support email would get elsewhere in the app.
const officialWhatsappChannelUrl = 'https://whatsapp.com/channel/0029Vakde1SFcowDP3r6C20f';

// Used by the bottom nav's More sheet "Follow Us" row — moved here from a
// per-screen AppBar action (see git history) since a "join our channel"
// prompt belongs with the rest of the social links, not repeated on every
// Nikah screen's topbar.
Future<void> openWhatsappChannel(BuildContext context) async {
  final uri = Uri.parse(officialWhatsappChannelUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }
}

// A green circular badge with a white phone glyph — the same "contact us
// on WhatsApp" convention most apps use in place of the actual trademarked
// logo mark (no brand-icon package needed — font_awesome_flutter's
// IconData subclasses don't compile against this SDK, since IconData is a
// final class here).
class WhatsappBadge extends StatelessWidget {
  final double size;
  const WhatsappBadge({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
      child: Icon(Icons.phone, color: Colors.white, size: size * 0.6),
    );
  }
}

