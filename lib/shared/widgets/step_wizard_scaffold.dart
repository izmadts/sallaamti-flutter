import 'package:flutter/material.dart';

import 'error_banner.dart';

// Shared shell for every multi-step wizard in the app (Nikah profile
// creation first, more later) — a progress dots row, the step's own form
// as the body, a single primary action button with its own loading state,
// and a general-error banner. Each step screen owns its Form/fields and
// just hands this its content + an onNext callback.
class StepWizardScaffold extends StatefulWidget {
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
  // Optional AppBar actions (e.g. Nikah's WhatsApp channel action) — left
  // null by default so other wizards built on this shell (Quran Live
  // admission) are unaffected.
  final List<Widget>? actions;

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
    this.actions,
  });

  @override
  State<StepWizardScaffold> createState() => _StepWizardScaffoldState();
}

class _StepWizardScaffoldState extends State<StepWizardScaffold> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(StepWizardScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A long step (e.g. Nikah step 2, with Languages tucked at the very
    // bottom) can leave the user scrolled well past where this banner
    // renders — without this, a validation/API error after tapping Next
    // just looks like the button silently did nothing, "stuck" on
    // whatever field happened to be on screen.
    if (widget.errorText != null && widget.errorText != oldWidget.errorText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = _buildScaffold(context);
    return widget.theme != null ? Theme(data: widget.theme!, child: scaffold) : scaffold;
  }

  Widget _buildScaffold(BuildContext context) {
    // A plain color lookup, not Theme.of(context) — this method's context
    // sits above the Theme this widget wraps itself in, so Theme.of here
    // would still resolve to whatever was ambient before it.
    final primaryColor = (widget.theme ?? Theme.of(context)).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: widget.onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack)
            : null,
        automaticallyImplyLeading: widget.onBack != null,
        actions: widget.actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: List.generate(widget.totalSteps, (i) {
                  final active = i <= widget.stepIndex;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(right: i == widget.totalSteps - 1 ? 0 : 6),
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
              'Step ${widget.stepIndex + 1} of ${widget.totalSteps}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.errorText != null) ...[
                      ErrorBanner(message: widget.errorText!),
                      const SizedBox(height: 16),
                    ],
                    widget.child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: ElevatedButton(
                onPressed: widget.busy ? null : () => widget.onNext(),
                child: widget.busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.nextLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
