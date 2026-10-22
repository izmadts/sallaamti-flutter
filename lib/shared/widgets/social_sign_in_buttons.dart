import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/api/api_exception.dart';
import '../../features/auth/data/social_auth_service.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../l10n/generated/app_localizations.dart';

// Google only — Facebook login was dropped (recurring native-SDK/key-hash
// breakage across this app's whole history, see the auth debugging trail
// in SocialAuthService's own git log; Google alone covers the login need).
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key});

  @override
  ConsumerState<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      _showError(e.message);
    } on GoogleSignInException catch (e) {
      // Surfaces the real native-SDK failure (e.g. clientConfigurationError,
      // providerConfigurationError) instead of a generic message — this is
      // the only signal we get for Google sign-in config problems without
      // pulling device logs.
      _showError('Google sign-in failed: ${e.code.name}${e.description != null ? ' — ${e.description}' : ''}');
    } catch (_) {
      if (mounted) _showError(AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l10n.orContinueWith, style: TextStyle(color: Colors.grey.shade600)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        // Matches Google's own brand button spec: white fill, #DADCE0
        // border, the full four-colour "G" mark, Roboto-weight label —
        // not a generic OutlinedButton with an emoji standing in for it.
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      final token = await SocialAuthService.signInWithGoogle();
                      if (token != null) {
                        await ref.read(authControllerProvider.notifier).socialGoogle(token);
                      }
                    }),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3C4043),
              side: const BorderSide(color: Color(0xFFDADCE0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF4285F4)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CustomPaint(painter: _GoogleLogoPainter())),
                      const SizedBox(width: 10),
                      Text(
                        l10n.continueWithGoogle,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF3C4043)),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// The standard four-colour Google "G" mark, drawn to spec rather than
// bundled as an image asset — avoids shipping/licensing a binary logo file
// for one small icon. Proportions follow Google's published brand guidance.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final strokeWidth = size.width * 0.22;
    final ringRadius = r - strokeWidth / 2;

    void arc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    // Four quadrants of the ring, Google brand colours, angles tuned so the
    // seams land where the real mark's do (blue bar cuts into the red arc).
    arc(-50, 95, const Color(0xFF4285F4)); // blue (top-right)
    arc(45, 90, const Color(0xFF34A853)); // green (bottom-right)
    arc(135, 90, const Color(0xFFFBBC05)); // yellow (bottom-left)
    arc(225, 95, const Color(0xFFEA4335)); // red (top-left)

    // The horizontal bar stroke through the middle, Google-blue, that turns
    // the ring into a "G".
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - strokeWidth / 2, r - strokeWidth * 0.15, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
