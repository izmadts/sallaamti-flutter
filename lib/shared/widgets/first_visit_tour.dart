import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// One step of a FirstVisitTour — a 👆 hand points at the emoji while the
// title/description explain what that part of the screen is for. Content
// lives wherever the tour is shown (e.g. NikahHomeScreen), not here — this
// file is purely the generic "show it once, remember that, let it be
// re-opened" mechanism, reusable for any module's own tour later.
class TourStep {
  final String emoji;
  final String title;
  final String description;
  const TourStep({required this.emoji, required this.title, required this.description});
}

class FirstVisitTour {
  FirstVisitTour._();

  // Per-device, not per-account — a fresh install (or a different member
  // sharing the device) sees it again, which is fine; this is purely a
  // "have you seen this UI before" nudge, not account state, so it
  // deliberately doesn't go through the backend/Riverpod like everything
  // else in this app does.
  static Future<bool> _hasSeen(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(storageKey) ?? false;
  }

  static Future<void> _markSeen(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, true);
  }

  // Called from a screen's initState/first frame — no-ops instead of
  // showing anything if this device has already seen this tour.
  static Future<void> showIfNeeded(
    BuildContext context, {
    required String storageKey,
    required List<TourStep> steps,
  }) async {
    if (await _hasSeen(storageKey)) return;
    if (!context.mounted) return;
    await show(context, steps: steps);
    await _markSeen(storageKey);
  }

  // Always shows, regardless of whether it's been seen — for a "❓ How
  // does this work?" button that lets a member replay it on purpose.
  static Future<void> show(BuildContext context, {required List<TourStep> steps}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TourDialog(steps: steps),
    );
  }
}

class _TourDialog extends StatefulWidget {
  final List<TourStep> steps;
  const _TourDialog({required this.steps});

  @override
  State<_TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<_TourDialog> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  bool get _isLast => _index == widget.steps.length - 1;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: Align(alignment: Alignment.centerRight, child: Text('Skip', style: TextStyle(color: Colors.grey.shade500))),
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _bounce,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -6 * _bounce.value),
                child: child,
              ),
              child: const Text('👆', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 4),
            Text(step.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(step.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              step.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.steps.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_isLast) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _index++);
                  }
                },
                child: Text(_isLast ? "Got it!" : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
