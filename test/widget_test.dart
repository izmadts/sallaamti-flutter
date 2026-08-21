import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sallaamti_app/main.dart';

void main() {
  testWidgets('App boots to the splash screen without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SallaamtiApp()));

    // A single frame only — the splash screen's CircularProgressIndicator
    // animates indefinitely, so pumpAndSettle would never return here.
    await tester.pump();

    expect(find.text('Sallaamti'), findsOneWidget);
  });
}
