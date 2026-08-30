import 'package:flutter/material.dart';

import 'error_banner.dart';

// Shared shell for every multi-step wizard in the app (Nikah profile
// creation first, more later) — a progress dots row, the step's own form
// as the body, a single primary action button with its own loading state,
// and a general-error banner. Each step screen owns its Form/fields and
// just hands this its content + an onNext callback.
class StepWizardScaffold extends StatelessWidget {
  final String title;
  final int stepIndex;
  final int totalSteps;
  final Widget child;
  final String nextLabel;
  final Future<void> Function() onNext;
  final bool busy;
  final String? errorText;
  final VoidCallback? onBack;
  // Lets a specific wizard (Nikah's rose, say) tint its whole flow —
  // omit it and the wizard just inherits whatever theme is already
  // ambient, so this stays reusable for a future module's wizard too.
  final ThemeData? theme;

  const StepWizardScaffold({
    super.key,
    required this.title,
    required this.stepIndex,
    required this.totalSteps,
    required this.child,
    required this.nextLabel,
    required this.onNext,
    this.busy = false,
    this.errorText,
    this.onBack,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final scaffold = _buildScaffold(context);
    return theme != null ? Theme(data: theme!, child: scaffold) : scaffold;
  }

  Widget _buildScaffold(BuildContext context) {
    // A plain color lookup, not Theme.of(context) — this method's context
    // sits above the Theme this widget wraps itself in, so Theme.of here
    // would still resolve to whatever was ambient before it.
    final primaryColor = (theme ?? Theme.of(context)).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
            : null,
        automaticallyImplyLeading: onBack != null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: List.generate(totalSteps, (i) {
                  final active = i <= stepIndex;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: active ? primaryColor : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Text(
              'Step ${stepIndex + 1} of $totalSteps',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorText != null) ...[
                      ErrorBanner(message: errorText!),
                      const SizedBox(height: 16),
                    ],
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: ElevatedButton(
                onPressed: busy ? null : () => onNext(),
                child: busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(nextLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
