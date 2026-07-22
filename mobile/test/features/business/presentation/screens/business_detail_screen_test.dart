import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/features/business/presentation/screens/business_detail_screen.dart';
import 'package:sirasende_mobile/shared/widgets/app_loading_indicator.dart';

class FakeBusinessRepository implements BusinessRepository {
  Business? businessResult;
  Object? error;
  int getDetailCount = 0;
  String? lastSlug;

  @override
  Future<List<Business>> getBusinesses() {
    throw UnimplementedError();
  }

  @override
  Future<Business> getBusinessBySlug(String slug) async {
    getDetailCount++;
    lastSlug = slug;
    if (error != null) throw error!;
    return businessResult!;
  }
}

void main() {
  group('BusinessDetailScreen Tests', () {
    late FakeBusinessRepository fakeRepo;

    final dummyBusiness = const Business(
      id: 'd290f1ee-6c54-4b01-90e6-d701748f0851',
      name: 'Berber Ahmet',
      slug: 'berber-ahmet',
      address: 'Kadikoy, Istanbul',
      phone: '+905555555555',
      slotDurationMinutes: 30,
      isActive: true,
      workingStartTime: '09:00:00',
      workingEndTime: '18:00:00',
      createdAt: '2026-07-12T10:00:00Z',
      updatedAt: '2026-07-12T12:00:00Z',
    );

    setUp(() {
      fakeRepo = FakeBusinessRepository();
    });

    Widget createWidgetUnderTest(String slug) {
      return ProviderScope(
        overrides: [businessRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(home: BusinessDetailScreen(slug: slug)),
      );
    }

    testWidgets('should show loading indicator on initial detail fetch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('İşletme bilgileri yükleniyor...'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('should render business details on success', (
      WidgetTester tester,
    ) async {
      fakeRepo.businessResult = dummyBusiness;

      await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
      await tester.pumpAndSettle();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.text('Berber Ahmet'), findsWidgets); // title and appbar title
      expect(find.text('Kadikoy, Istanbul'), findsOneWidget);
      expect(find.text('+905555555555'), findsOneWidget);
      expect(find.text('30 dakika'), findsOneWidget);
      expect(find.text('09:00 – 18:00'), findsOneWidget); // formatted time

      // Verify technical fields are hidden
      expect(find.text('d290f1ee-6c54-4b01-90e6-d701748f0851'), findsNothing);
      expect(find.text('berber-ahmet'), findsNothing);
      expect(find.text('2026-07-12T10:00:00Z'), findsNothing);
    });

    testWidgets('should hide address and phone when null/empty', (
      WidgetTester tester,
    ) async {
      fakeRepo.businessResult = const Business(
        id: '2',
        name: 'Sade Salon',
        slug: 'sade-salon',
        slotDurationMinutes: 45,
        isActive: true,
        address: '',
        phone: null,
      );

      await tester.pumpWidget(createWidgetUnderTest('sade-salon'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);
    });

    testWidgets('should show error state with retry action when fetch fails', (
      WidgetTester tester,
    ) async {
      fakeRepo.error = const AppException(
        message: 'Detay yukleme hatasi.',
        code: 'ERR',
      );

      await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
      await tester.pumpAndSettle();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.text('İşletme bilgileri yüklenemedi'), findsOneWidget);
      expect(find.text('Detay yukleme hatasi.'), findsOneWidget);

      final initialCount = fakeRepo.getDetailCount;
      expect(initialCount, greaterThan(0));

      await tester.tap(find.text('Tekrar Dene'));
      await tester.pump();

      expect(fakeRepo.getDetailCount, greaterThan(initialCount));
    });

    testWidgets('should not overflow on small screen layout', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3.0, 568 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      fakeRepo.businessResult = const Business(
        id: '3',
        name:
            'Mehmet Ve Ahmet Kardesler Sac Tasarim Ve Guzellik Kompleksi A.S.',
        slug: 'long-name',
        address:
            'General Asim Gunduz Caddesi Altin Sokak Altin Han No: 45 Daire: 12 Kadikoy, Istanbul',
        phone: '+905555555555',
        slotDurationMinutes: 60,
        isActive: true,
        workingStartTime: '09:00:00',
        workingEndTime: '18:00:00',
      );

      await tester.pumpWidget(createWidgetUnderTest('long-name'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
