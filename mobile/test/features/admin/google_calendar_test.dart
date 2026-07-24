import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_profile_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/google_calendar_callback_screen.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connect_result.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connection_status.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/google_calendar_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/google_calendar_providers.dart';

class FakeBusinessRepository implements BusinessRepository {
  Business? businessResult;
  @override
  Future<List<Business>> getBusinesses() async => throw UnimplementedError();
  @override
  Future<Business> getBusinessBySlug(String slug) async =>
      throw UnimplementedError();
  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) async => throw UnimplementedError();

  @override
  Future<Business> getAdminBusiness() async {
    return businessResult!;
  }

  @override
  Future<Business> updateAdminBusiness({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? workingStartTime,
    String? workingEndTime,
    int? slotDurationMinutes,
    List<BusinessSchedule>? schedules,
  }) async {
    return businessResult!;
  }
}

class FakeGoogleCalendarRepository implements GoogleCalendarRepository {
  GoogleCalendarConnectionStatus? statusResult;
  GoogleCalendarConnectResult? connectResult;
  Object? error;

  int statusCalls = 0;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<GoogleCalendarConnectionStatus> getConnectionStatus() async {
    statusCalls++;
    if (error != null) throw error!;
    return statusResult!;
  }

  @override
  Future<GoogleCalendarConnectResult> getConnectUrl() async {
    connectCalls++;
    if (error != null) throw error!;
    return connectResult!;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (error != null) throw error!;
  }
}

void main() {
  group('Google Calendar Connection Tests', () {
    test(
      'GoogleCalendarConnectionStatus model parses connected response correctly',
      () {
        final json = {
          'connected': true,
          'google_account_email': 'owner@example.com',
          'connected_at': '2026-07-24T01:00:00Z',
          'granted_scopes': 'calendar.events',
        };
        final status = GoogleCalendarConnectionStatus.fromJson(json);
        expect(status.connected, isTrue);
        expect(status.googleAccountEmail, 'owner@example.com');
        expect(status.connectedAt, isNotNull);
        expect(status.grantedScopes, 'calendar.events');
      },
    );

    test(
      'GoogleCalendarConnectionStatus model parses disconnected response correctly',
      () {
        final json = {'connected': false};
        final status = GoogleCalendarConnectionStatus.fromJson(json);
        expect(status.connected, isFalse);
        expect(status.googleAccountEmail, isNull);
        expect(status.connectedAt, isNull);
      },
    );

    test('GoogleCalendarConnectResult model parses response correctly', () {
      final json = {'authorization_url': 'https://accounts.google.com/oauth'};
      final result = GoogleCalendarConnectResult.fromJson(json);
      expect(result.authorizationUrl, 'https://accounts.google.com/oauth');
    });
  });

  group('Google Calendar UI / AdminProfileScreen Integration Tests', () {
    late FakeBusinessRepository fakeBusinessRepo;
    late FakeGoogleCalendarRepository fakeGoogleCalendarRepo;

    final dummyBusiness = const Business(
      id: '1',
      name: 'Ahmet Barber Shop',
      slug: 'ahmet-barber',
      description: 'The best haircut in town',
      phone: '+905554443322',
      address: 'Kadikoy, Istanbul',
      slotDurationMinutes: 30,
      isActive: true,
      workingStartTime: '09:00:00',
      workingEndTime: '18:00:00',
      schedules: [],
    );

    setUp(() {
      fakeBusinessRepo = FakeBusinessRepository();
      fakeGoogleCalendarRepo = FakeGoogleCalendarRepository();

      fakeBusinessRepo.businessResult = dummyBusiness;
    });

    Widget makeTestableWidget(Widget child) {
      return ProviderScope(
        overrides: [
          businessRepositoryProvider.overrideWithValue(fakeBusinessRepo),
          googleCalendarRepositoryProvider.overrideWithValue(
            fakeGoogleCalendarRepo,
          ),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('Shows disconnect state with connect button when disconnected', (
      tester,
    ) async {
      fakeGoogleCalendarRepo.statusResult =
          const GoogleCalendarConnectionStatus(connected: false);

      await tester.pumpWidget(makeTestableWidget(const AdminProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Google Takvim Entegrasyonu'), findsOneWidget);
      expect(
        find.text(
          'Randevularınızı Google Takviminiz ile senkronize etmek için hesabınızı bağlayın.',
        ),
        findsOneWidget,
      );
      expect(find.text('Google Takvim\'i Bağla'), findsOneWidget);
    });

    testWidgets(
      'Shows connected state with account email and link-off button when connected',
      (tester) async {
        fakeGoogleCalendarRepo.statusResult = GoogleCalendarConnectionStatus(
          connected: true,
          googleAccountEmail: 'business@gmail.com',
          connectedAt: DateTime.now(),
        );

        await tester.pumpWidget(makeTestableWidget(const AdminProfileScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Google Takvim Bağlı'), findsOneWidget);
        expect(find.text('Bağlı Hesap: business@gmail.com'), findsOneWidget);
        expect(find.text('Bağlantıyı Kaldır'), findsOneWidget);
      },
    );

    testWidgets('Shows disconnection confirmation dialog and cancels', (
      tester,
    ) async {
      fakeGoogleCalendarRepo.statusResult = GoogleCalendarConnectionStatus(
        connected: true,
        googleAccountEmail: 'business@gmail.com',
        connectedAt: DateTime.now(),
      );

      await tester.pumpWidget(makeTestableWidget(const AdminProfileScreen()));
      await tester.pumpAndSettle();

      // Scroll to the button to make sure it's visible and tap-able
      await tester.ensureVisible(find.text('Bağlantıyı Kaldır'));
      await tester.pumpAndSettle();

      // Tap Disconnect
      await tester.tap(find.text('Bağlantıyı Kaldır'));
      await tester.pumpAndSettle();

      // Dialog is visible
      expect(find.text('Google Takvim Bağlantısını Kaldır'), findsWidgets);
      expect(find.text('İptal'), findsOneWidget);

      // Cancel tap
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();

      // Dialog is gone, connection remains
      expect(fakeGoogleCalendarRepo.disconnectCalls, 0);
    });

    testWidgets('GoogleCalendarCallbackScreen displays success correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const GoogleCalendarCallbackScreen(status: 'success'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bağlantı Başarılı!'), findsOneWidget);
      expect(
        find.text(
          'Google Takvim hesabınız başarıyla bağlandı. Profil sayfasına yönlendiriliyorsunuz...',
        ),
        findsOneWidget,
      );
    });

    testWidgets('GoogleCalendarCallbackScreen displays failure correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const GoogleCalendarCallbackScreen(
            status: 'failure',
            error: 'OAuth yetkilendirmesi başarısız oldu.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bağlantı Başarısız!'), findsOneWidget);
      expect(
        find.text('OAuth yetkilendirmesi başarısız oldu.'),
        findsOneWidget,
      );
    });

    testWidgets('Small screen 320x568 overflow protection test', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      fakeGoogleCalendarRepo.statusResult =
          const GoogleCalendarConnectionStatus(connected: false);

      await tester.pumpWidget(makeTestableWidget(const AdminProfileScreen()));
      await tester.pumpAndSettle();

      // Verify no layout overflow exception thrown
      expect(tester.takeException(), isNull);
    });
  });
}
