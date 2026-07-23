import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/app.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';

class FakeAuthController extends AuthController {
  @override
  FutureOr<AdminUser?> build() async {
    return null;
  }
}

class FakeBusinessRepository implements BusinessRepository {
  @override
  Future<List<Business>> getBusinesses() async => [];

  @override
  Future<Business> getBusinessBySlug(String slug) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) async => [];
}

void main() {
  testWidgets('App base layout smoke test with Riverpod and router', (
    WidgetTester tester,
  ) async {
    // Build our app inside a ProviderScope with overridden providers and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => FakeAuthController()),
          businessRepositoryProvider.overrideWithValue(
            FakeBusinessRepository(),
          ),
        ],
        child: const SiraSendeApp(),
      ),
    );

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
