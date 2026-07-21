import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/app.dart';

void main() {
  testWidgets('App base layout smoke test with Riverpod and router', (
    WidgetTester tester,
  ) async {
    // Build our app inside a ProviderScope and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: SiraSendeApp()));

    // Let the GoRouter route transition resolve.
    await tester.pumpAndSettle();

    // Verify that the app title and onboarding texts are present.
    expect(find.text('SıraSende'), findsWidgets);
    expect(
      find.text('Randevunuzu kolayca oluşturun veya işletmenizi yönetin.'),
      findsOneWidget,
    );
    expect(find.text('Müşteri olarak devam et'), findsOneWidget);
    expect(find.text('Esnaf girişi'), findsOneWidget);

    // Verify that the old counter components are gone.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsNothing);
  });
}
